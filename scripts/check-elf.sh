#!/usr/bin/env bash
# Audit every ELF file in the staged tree:
#   1. ldd inside the Ubuntu sandbox -> no unresolved shared libraries;
#   2. record the maximum versioned glibc (GLIBC_*) and libstdc++
#      (GLIBCXX_*) requirements of each binary (baseline: glibc 2.35 and
#      GLIBCXX 3.4.30 as shipped by Ubuntu 22.04).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="${1:-$STAGE_DIR/root}"   # staged root, e.g. $STAGE_DIR/root
[[ -d "$ROOT/opt" ]] || die "usage: check-elf.sh <staged-root>"
[[ "$ROOT" == "$STAGE_DIR/root" ]] || warn "auditing a non-standard tree"

GUEST="${ROOT#$NVF_ROOT/build}"   # e.g. /root/root (path inside /nvf-build)
log "auditing ELF dependencies inside the sandbox (binutils available in build rootfs)"
run22 "$ROOTFS_BUILD" /bin/bash -s "$GUEST" <<'SANDBOX' | tee "$CACHE_DIR/elf-audit.txt"
set -u
guest="$1"
fail=0
glibc_max=""
gxx_max=""
while IFS= read -r elf; do
  if head -c4 "$elf" 2>/dev/null | grep -q $'\x7fELF'; then
    out=$(ldd "$elf" 2>&1)
    if echo "$out" | grep -q 'not found'; then
      echo "MISSING-LIB: $elf"
      echo "$out" | grep 'not found' | sed 's/^/    /'
      fail=1
    fi
    g=$(objdump -T "$elf" 2>/dev/null | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1)
    x=$(objdump -T "$elf" 2>/dev/null | grep -oE 'GLIBCXX_[0-9.]+' | sort -uV | tail -1)
    [ -n "$g" ] && glibc_max=$(printf '%s\n%s\n' "$glibc_max" "$g" | grep . | sort -uV | tail -1)
    [ -n "$x" ] && gxx_max=$(printf '%s\n%s\n' "$gxx_max" "$x" | grep . | sort -uV | tail -1)
    printf 'ELF %s | max GLIBC: %s | max GLIBCXX: %s\n' "${elf#/nvf-build$guest}" "${g:-none}" "${x:-none}"
  fi
done < <(find "/nvf-build$guest/opt" -type f)
echo "OVERALL max GLIBC:   ${glibc_max:-none}"
echo "OVERALL max GLIBCXX: ${gxx_max:-none}"
# Compare numeric versions only (strip GLIBC_/GLIBCXX_ prefixes).
glibc_num=${glibc_max#GLIBC_}
gxx_num=${gxx_max#GLIBCXX_}
if [ -n "$glibc_num" ] && [ "$(printf '%s\n' "$glibc_num" 2.35 | sort -uV | tail -1)" != "2.35" ]; then
  echo "FAIL: $glibc_max exceeds the Ubuntu 22.04 baseline (2.35)"; fail=1
fi
if [ -n "$gxx_num" ] && [ "$(printf '%s\n' "$gxx_num" 3.4.30 | sort -uV | tail -1)" != "3.4.30" ]; then
  echo "FAIL: $gxx_max exceeds the Ubuntu 22.04 libstdc++ baseline (3.4.30)"; fail=1
fi
if [ "$fail" -eq 0 ]; then echo "PASS: all ELF dependency and baseline checks OK"; fi
exit $fail
SANDBOX
rc=$?
log "elf audit saved to $CACHE_DIR/elf-audit.txt (exit $rc)"
exit $rc
