#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# nvim-forge offline acceptance suite.
#
# Installs dist/nvim-forge_<v>_amd64.deb into the *pristine* Ubuntu 22.04
# proot sandbox (rootfs-test) and validates:
#
#   T01  package checksum + metadata
#   T02  clean dpkg -i install, system Neovim untouched
#   T03  launcher + bundled Neovim version
#   T04  full headless startup (theme, options, plugins, LSP config, exes)
#   T05  Tree-sitter parsers parse real syntax trees
#   T06  LSP attach: Python (basedpyright on bundled node)
#   T07  LSP attach: C      (bundled clangd)
#   T08  LSP attach: C++    (bundled clangd)
#   T09  LSP attach: Rust   (bundled rust-analyzer)
#   T10  shared-lib audit of installed files (ldd, no "not found")
#   T11  runs as a non-root user with per-user XDG state
#   T12  bundle is read-only at runtime
#   T13  network independence (netguard LD_PRELOAD + strace audit)
#   T14  no hardcoded home paths in config/launcher
#   T15  clean removal via dpkg -r (system Neovim + user state kept)
#
# Writes dist/TEST-REPORT.md.  Exit code = number of failed checks.
# ---------------------------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

VERSION=$(jqv '.version // empty')
[[ -n "$VERSION" ]] || VERSION=1.0.0
DEB="$DIST_DIR/nvim-forge_${VERSION}_amd64.deb"
REPORT="$DIST_DIR/TEST-REPORT.md"
T="$ROOTFS_TEST"
WORK=/root/nvf-work

[[ -f "$DEB" ]] || die "missing $DEB (run scripts/build-deb.sh first)"
[[ -d "$T" ]]   || die "missing test rootfs (run scripts/sandbox.sh first)"

# Tests live outside the build bind; copy them in so the sandbox sees them
# at /nvf-build/tests.
rm -rf "$BUILD_DIR/tests"
cp -a "$NVF_ROOT/tests" "$BUILD_DIR/tests"

PASS_N=0; FAIL_N=0
ROWS=()
row() { # status id name [detail]
  local st="$1" id="$2" name="$3" detail="${4:-}"
  ROWS+=("$st|$id|$name|$detail")
  if [[ "$st" == PASS ]]; then
    PASS_N=$((PASS_N + 1)); log "PASS  $id  $name"
  else
    FAIL_N=$((FAIL_N + 1)); warn "FAIL  $id  $name${detail:+ -- $detail}"
  fi
}

OUT=""; RC=0
sroot() { OUT=$(run22 "$T" "$@" 2>&1) && RC=0 || RC=$?; }        # fake root
suser() { OUT=$(run22_user "$T" "$@" 2>&1) && RC=0 || RC=$?; }   # uid 1000
sbuild() { OUT=$(run22 "$ROOTFS_BUILD" "$@" 2>&1) && RC=0 || RC=$?; }

have() { grep -qF -- "$1" <<<"$OUT"; }  # pattern in captured output

log "nvim-forge offline acceptance suite (deb: $DEB)"

# ------------------------------------------------------------- T01 package
t01() {
  local meta src=0
  meta=$(dpkg-deb -f "$DEB" Package Version Architecture Depends 2>&1) || { row FAIL T01 "package metadata readable" "$meta"; return; }
  ( cd "$DIST_DIR" && sha256sum -c SHA256SUMS ) >/dev/null 2>&1 || src=$?
  local sum; sum=$(awk '{print $1}' "$DIST_DIR/SHA256SUMS")
  if [[ $src -eq 0 ]] \
     && grep -q '^Package: nvim-forge$' <<<"$meta" \
     && grep -q "^Version: *$VERSION" <<<"$meta" \
     && grep -q '^Architecture: amd64$' <<<"$meta" \
     && grep -q 'libc6 (>= 2.35)' <<<"$meta"; then
    row PASS T01 "SHA256SUMS verified; metadata ok (sha256=${sum:0:16}…)"
  else
    row FAIL T01 "SHA256SUMS + package metadata" "src=$src $meta"
  fi
}
t01

# ------------------------------------------------------ T02 clean install
# Plant a fake "system Neovim" first to prove we never touch it.
sroot /bin/bash -c 'printf "#!/bin/sh\necho system-nvim-9.9\n" > /usr/bin/nvim && chmod 755 /usr/bin/nvim && md5sum /usr/bin/nvim'
SYS_MD5=$(awk '{print $1}' <<<"$OUT")
sroot /bin/bash -c 'dpkg -i /nvf-dist/'"$(basename "$DEB")"' </dev/null'
install_rc=$RC; install_out=$OUT
sroot /bin/bash -c '
  [ -x /usr/bin/nvim-forge ] && echo launcher-ok
  [ -x /opt/nvim-forge/bin/nvim ] && echo bundle-nvim-ok
  md5sum /usr/bin/nvim
  dpkg -l nvim-forge 2>/dev/null | tail -1'
if [[ $install_rc -eq 0 ]] && have launcher-ok && have bundle-nvim-ok \
   && have "$SYS_MD5"; then
  row PASS T02 "clean dpkg -i install; system /usr/bin/nvim untouched"
else
  row FAIL T02 "clean dpkg -i install" "rc=$install_rc ${install_out//$'\n'/ }"
fi

# ------------------------------------------------------ T03 version banner
sroot /usr/bin/nvim-forge --version
if [[ $RC -eq 0 ]] && have 'NVIM v0.12.6'; then
  row PASS T03 "nvim-forge --version -> $(grep -o 'NVIM v[0-9.]*' <<<"$OUT" | head -1)"
else
  row FAIL T03 "nvim-forge --version" "rc=$RC ${OUT//$'\n'/ }"
fi

# --------------------------------------------------- T04 headless startup
sroot /usr/bin/nvim-forge --headless --cmd 'set nomore' \
  -c 'luafile /nvf-build/tests/startup.lua'
if [[ $RC -eq 0 ]] && have NVF-STARTUP-OK; then
  row PASS T04 "headless startup: theme, options, plugins, LSP config, exes"
else
  row FAIL T04 "headless startup" "rc=$RC ${OUT//$'\n'/ }"
fi

# ---------------------------------------------------- T05 tree-sitter
sroot /bin/bash -c 'set -e; mkdir -p '"$WORK"'; cp /nvf-build/tests/samples/* '"$WORK"'/'
sroot /usr/bin/nvim-forge --headless --cmd 'set nomore' \
  "$WORK/test.py" -c 'luafile /nvf-build/tests/treesitter.lua'
if have NVF-TREESITTER-OK; then
  row PASS T05 "Tree-sitter parses python/c/cpp/rust; highlighter attaches"
else
  row FAIL T05 "Tree-sitter" "rc=$RC ${OUT//$'\n'/ }"
fi

# ------------------------------------------------------ T06..T09 LSP attach
lsp_test() { # id server file timeout
  local id="$1" server="$2" file="$3" tmo="$4"
  sroot /usr/bin/env NVF_TEST_SERVER="$server" NVF_TEST_TIMEOUT="$tmo" \
    /usr/bin/nvim-forge --headless --cmd 'set nomore' \
    "$WORK/$file" -c 'luafile /nvf-build/tests/lsp_attach.lua'
  if have "NVF-LSP-OK client=$server"; then
    row PASS "$id" "LSP attach: $server ($file)"
  else
    row FAIL "$id" "LSP attach: $server ($file)" "rc=$RC ${OUT//$'\n'/ }"
  fi
}
lsp_test T06 basedpyright test.py 60000
lsp_test T07 clangd        test.c   60000
lsp_test T08 clangd        test.cpp 60000
lsp_test T09 rust_analyzer test.rs  90000

# ------------------------------------------------- T10 shared-lib audit
sroot /bin/bash -c '
  fail=0; n=0
  while IFS= read -r f; do
    case "$(head -c4 "$f" 2>/dev/null)" in $'"'"'\x7fELF'"'"') ;; *) continue;; esac
    n=$((n+1))
    if ldd "$f" 2>&1 | grep -q "not found"; then
      echo "MISSING $f"
      ldd "$f" 2>&1 | grep "not found" | sed "s/^/  /"
      fail=1
    fi
  done < <(find /opt/nvim-forge -type f)
  echo "ELF-scanned=$n"
  [ "$fail" -eq 0 ] && echo LDD-OK
  exit $fail'
if [[ $RC -eq 0 ]] && have LDD-OK; then
  row PASS T10 "ldd over installed bundle: $(grep -o 'ELF-scanned=[0-9]*' <<<"$OUT" | head -1), all resolve"
else
  row FAIL T10 "shared-lib audit" "rc=$RC ${OUT//$'\n'/ }"
fi

# ------------------------------------------------ T11 non-root execution
suser /usr/bin/id -u
uid_out="$OUT"; uid_rc=$RC
suser /usr/bin/env HOME=/home/tester /usr/bin/nvim-forge --headless \
  --cmd 'set nomore' -c 'luafile /nvf-build/tests/startup.lua'
su_rc=$RC; su_out=$OUT
suser /bin/bash -c 'ls -d /home/tester/.local/state/nvim-forge /home/tester/.cache/nvim-forge /home/tester/.local/share/nvim-forge 2>/dev/null | wc -l'
state_dirs=$OUT
if [[ $uid_rc -eq 0 && "$uid_out" != 0 && $su_rc -eq 0 ]] \
   && grep -qF NVF-STARTUP-OK <<<"$su_out" \
   && [[ "${state_dirs//[^0-9]/}" -gt 0 ]]; then
  row PASS T11 "non-root (uid $uid_out) startup OK; $state_dirs XDG state dir(s) created"
else
  row FAIL T11 "non-root execution" "uid=$uid_out rc=$su_rc dirs=$state_dirs ${su_out//$'\n'/ }"
fi

# ----------------------------------------------- T12 read-only bundle
# NOTE: proot's --root-id mode bypasses DAC checks for the tracee (writes
# into mode-555 directories succeed), so enforcement is verified with the
# plain, non-root runner where real kernel permissions apply.
suser /bin/bash -c 'chmod -R a-w /opt/nvim-forge; touch /opt/nvim-forge/.rw-probe 2>/dev/null; echo probe-rc=$?'
probe_rc=$(grep -o 'probe-rc=[0-9]*' <<<"$OUT" | cut -d= -f2 || true)
suser /usr/bin/env HOME=/home/tester /usr/bin/nvim-forge --headless \
  --cmd 'set nomore' -c 'luafile /nvf-build/tests/startup.lua'
ro_rc=$RC; ro_out=$OUT
suser /bin/bash -c 'chmod -R u+w /opt/nvim-forge'   # restore for removal test
if [[ "$probe_rc" != 0 && $ro_rc -eq 0 ]] && grep -qF NVF-STARTUP-OK <<<"$ro_out"; then
  row PASS T12 "bundle read-only (write probe refused) and editor still starts"
else
  row FAIL T12 "read-only bundle" "probe=$probe_rc rc=$ro_rc ${ro_out//$'\n'/ }"
fi

# ---------------------------------------------- T13 network independence
sbuild /bin/cc -shared -fPIC -O2 -o /nvf-build/netguard.so /nvf-build/tests/netguard.c
if [[ $RC -ne 0 ]]; then
  row FAIL T13 "netguard build" "$OUT"
else
  rm -f "$BUILD_DIR/netguard.log"
  netfail=""
  # 1) full startup under a hard network block
  sroot /usr/bin/env LD_PRELOAD=/nvf-build/netguard.so \
    NVF_NETGUARD_LOG=/root/netguard.log HOME=/root \
    /usr/bin/nvim-forge --headless --cmd 'set nomore' \
    -c 'luafile /nvf-build/tests/startup.lua'
  if ! grep -qF NVF-STARTUP-OK <<<"$OUT"; then
    netfail+="startup(rc=$RC) "
  fi
  # 2) every language server must attach with the network blocked
  for spec in 'basedpyright:test.py' 'clangd:test.c' 'rust_analyzer:test.rs'; do
    srv=${spec%%:*}; f=${spec#*:}
    sroot /usr/bin/env LD_PRELOAD=/nvf-build/netguard.so \
      NVF_NETGUARD_LOG=/root/netguard.log HOME=/root \
      NVF_TEST_SERVER="$srv" NVF_TEST_TIMEOUT=90000 \
      /usr/bin/nvim-forge --headless --cmd 'set nomore' \
      "$WORK/$f" -c 'luafile /nvf-build/tests/lsp_attach.lua'
    if ! grep -qF "NVF-LSP-OK client=$srv" <<<"$OUT"; then
      netfail+="$srv(rc=$RC) "
    fi
  done
  # blocked-socket attempts recorded by netguard?
  sroot /bin/bash -c 'cat /root/netguard.log 2>/dev/null | wc -l'
  netlog_lines=$(grep -oE '^[0-9]+$' <<<"$OUT" || echo '?')
  # 3) independent syscall audit with strace (no preload)
  sroot /bin/bash -c 'strace -f -e trace=network -o /root/strace.log \
      /usr/bin/nvim-forge --headless --cmd "set nomore" \
      -c "luafile /nvf-build/tests/startup.lua" >/dev/null 2>&1 || true;
      wc -l < /root/strace.log'
  strace_lines=$(grep -oE '^[0-9]+' <<<"$OUT" | tail -1 || true)
  sroot /bin/bash -c 'grep -cE "AF_INET|AF_INET6" /root/strace.log || true'
  inet_hits=$(grep -oE '^[0-9]+' <<<"$OUT" | tail -1 || true)
  if [[ -z "$netfail" && "$netlog_lines" == 0 && "${inet_hits:-1}" == 0 ]]; then
    row PASS T13 "offline: startup + 3 LSP servers with sockets blocked; strace saw $inet_hits AF_INET* syscalls in $strace_lines net syscalls"
  else
    row FAIL T13 "network independence" "failures=[${netfail}] netguard_log_lines=$netlog_lines af_inet_hits=$inet_hits"
  fi
fi

# ------------------------------------------- T14 no hardcoded home paths
sroot /bin/bash -c 'grep -rIn "/home/" /opt/nvim-forge/config /usr/bin/nvim-forge 2>/dev/null || true'
if [[ -z "${OUT//[$'\n' ]/}" ]]; then
  row PASS T14 "no hardcoded /home paths in config or launcher"
else
  row FAIL T14 "hardcoded home paths" "$OUT"
fi

# ------------------------------------------------------ T15 clean removal
sroot /bin/bash -c 'dpkg -r nvim-forge </dev/null'
rm_rc=$RC; rm_out=$OUT
sroot /bin/bash -c '
  [ ! -e /opt/nvim-forge ] && echo opt-gone
  [ ! -e /usr/bin/nvim-forge ] && echo launcher-gone
  md5sum /usr/bin/nvim
  dpkg -s nvim-forge >/dev/null 2>&1 || echo dpkg-gone
  [ -d /home/tester/.local/state/nvim-forge ] && echo user-state-kept'
if [[ $rm_rc -eq 0 ]] && have opt-gone && have launcher-gone \
   && have "$SYS_MD5" && have user-state-kept; then
  row PASS T15 "dpkg -r removes bundle + launcher; system nvim and user state kept"
else
  row FAIL T15 "clean removal" "rc=$rm_rc ${OUT//$'\n'/ }"
fi

# --------------------------------------------------------------- report
mkdir -p "$DIST_DIR"
DEB_SIZE=$(du -h "$DEB" | cut -f1)
sum=$(awk '{print $1}' "$DIST_DIR/SHA256SUMS")
INSTALLED=$(dpkg-deb -f "$DEB" Installed-Size)   # KiB
ROOTFS_VER=$(cat "$T/etc/os-release" | sed -n 's/^VERSION_ID=//p' | tr -d '"')
{
  echo "# nvim-forge offline test report"
  echo
  echo "- Package: \`$(basename "$DEB")\` (${DEB_SIZE}, installed ${INSTALLED} KiB)"
  echo "- Built: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
  echo "- Target: Ubuntu ${ROOTFS_VER} (amd64), glibc baseline 2.35 (Ubuntu 22.04)"
  echo "- Environment: proot 5.4.0 sandbox on a pristine ubuntu-base-22.04.5"
  echo "  rootfs (used instead of Docker/Podman: neither is available on the"
  echo "  build host and unprivileged user namespaces are blocked by AppArmor)."
  echo "- Result: **$PASS_N passed, $FAIL_N failed**"
  echo
  echo "| ID | Check | Result |"
  echo "|----|-------|--------|"
  for r in "${ROWS[@]}"; do
    st=${r%%|*}; rest=${r#*|}; id=${rest%%|*}; rest=${rest#*|}; name=${rest%%|*}
    printf '| %s | %s | %s |\n' "$id" "${name//|/,}" "$st"
  done
  echo
  echo "- Package SHA-256: \`$sum\`"
  echo
  echo "## Versions under test"
  echo
  echo "| Component | Version |"
  echo "|-----------|---------|"
  echo "| Neovim | 0.12.6 |"
  echo "| BasedPyright | 1.40.2 |"
  echo "| Node.js | 24.22.0 |"
  echo "| clangd | 23.1.0 |"
  echo "| Rust toolchain (rustc/cargo/rust-analyzer) | 1.99.1 |"
  echo "| Tree-sitter parsers | python v0.25.0, c b780e47f, cpp c0092228, rust 77a37472 |"
  echo "| Plugins | commit-pinned, see /opt/nvim-forge/manifest/pins.json |"
  echo
  echo "## Limitations"
  echo
  echo "- amd64 only; requires glibc >= 2.35 (Ubuntu 22.04+)."
  echo "- Tree-sitter parsers ship for python, c, cpp and rust only."
  echo "- Validation ran inside a proot-based Ubuntu 22.04 rootfs rather than"
  echo "  Docker/Podman (unavailable on the build host; AppArmor blocks"
  echo "  unprivileged user namespaces), so kernel-level container isolation"
  echo "  was not exercised - package installation, file layout, offline"
  echo "  behaviour and removal were."
  echo "- Network independence was enforced with an LD_PRELOAD socket blocker"
  echo "  and an independent strace audit, not with a network namespace."
} > "$REPORT"

log "test report -> $REPORT"
log "summary: $PASS_N passed, $FAIL_N failed"
exit "$FAIL_N"
