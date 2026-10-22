#!/usr/bin/env bash
# Download all pinned artifacts into cache/downloads and verify them.
# - Artifacts with upstream checksum files (nodejs SHASUMS256.txt, npm
#   dist.integrity, Rust channel toml hashes) are verified against them.
# - All other artifacts are "self-pinned": the first fetch records the
#   computed SHA-256 in manifest/pins-locked.json; every later fetch must
#   match it (or the pinned value in pins.json).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

mkdir -p "$DL_DIR"
FETCHED_JSON="$CACHE_DIR/fetched.json"
printf '{}\n' > "$FETCHED_JSON.tmp"

lock_sha() { # name sha
  python3 - "$LOCKS_FILE" "$1" "$2" <<'EOF'
import json, sys, os, collections
path, name, sha = sys.argv[1:4]
data = collections.OrderedDict()
if os.path.exists(path) and os.path.getsize(path) > 2:
    data = json.load(open(path), object_pairs_hook=collections.OrderedDict)
entry = data.get(name, collections.OrderedDict())
entry["sha256"] = sha
data[name] = entry
json.dump(data, open(path, "w"), indent=2)
EOF
}

record() { # name file sha method url
  python3 - "$FETCHED_JSON.tmp" "$1" "$2" "$3" "$4" "$5" <<'EOF'
import json, sys, collections, os
path, name, file, sha, method, url = sys.argv[1:7]
data = collections.OrderedDict()
if os.path.exists(path) and os.path.getsize(path) > 2:
    data = json.load(open(path), object_pairs_hook=collections.OrderedDict)
data[name] = collections.OrderedDict(file=file, sha256=sha, verified=method, url=url)
json.dump(data, open(path, "w"), indent=2)
EOF
}

# Fetch a plain pinned URL artifact.
fetch_generic() { # name
  local name="$1"
  local url version fname
  url=$(jqv ".artifacts[\"$name\"].url")
  version=$(jqv ".artifacts[\"$name\"].version")
  fname=$(basename "$url")
  local dest="$DL_DIR/$fname"
  local pinned; pinned=$(effective_sha "$name")

  if [[ ! -f "$dest" ]]; then
    log "downloading $name ($version)"
    curl -fsSL --retry 3 -o "$dest.part" "$url" >/dev/null
    mv "$dest.part" "$dest"
  fi

  local sha; sha=$(sha256_of "$dest")
  if [[ -n "$pinned" ]]; then
    [[ "$sha" == "$pinned" ]] || die "$name: checksum mismatch (expected $pinned got $sha)"
    log "verified $name (pinned sha256)"
  else
    log "self-pinning $name -> $sha"
    lock_sha "$name" "$sha"
  fi
  record "$name" "$fname" "$sha" "sha256" "$url"
}

# ---------------------------------------------------------------- node.js
fetch_node() {
  local ver; ver=$(jqv '.artifacts.node.version')
  local fname="node-v${ver}-linux-x64.tar.xz"
  local dest="$DL_DIR/$fname"
  local sums="$DL_DIR/node-SHASUMS256.txt"
  [[ -f "$dest" ]] || { log "downloading node $ver"; curl -fsSL --retry 3 -o "$dest.part" \
      "https://nodejs.org/dist/v${ver}/${fname}" >/dev/null && mv "$dest.part" "$dest"; }
  log "verifying node against nodejs.org SHASUMS256.txt"
  curl -fsSL "https://nodejs.org/dist/v${ver}/SHASUMS256.txt" -o "$sums"
  (cd "$DL_DIR" && grep " ${fname}\$" "$sums" | sha256sum -c - >/dev/null) \
    || die "node: checksum mismatch vs upstream SHASUMS256.txt"
  local sha; sha=$(sha256_of "$dest")
  lock_sha node "$sha"
  record node "$fname" "$sha" "upstream SHASUMS256.txt + sha256" \
    "https://nodejs.org/dist/v${ver}/${fname}"
}

# ----------------------------------------------------------- basedpyright
fetch_basedpyright() {
  local ver; ver=$(jqv '.artifacts.basedpyright.version')
  local fname="basedpyright-${ver}.tgz"
  local dest="$DL_DIR/$fname"
  [[ -f "$dest" ]] || { log "downloading basedpyright $ver"; curl -fsSL --retry 3 -o "$dest.part" \
      "https://registry.npmjs.org/basedpyright/-/${fname}" >/dev/null && mv "$dest.part" "$dest"; }
  log "verifying basedpyright against npm registry dist.integrity"
  local integrity
  integrity=$(curl -fsSL "https://registry.npmjs.org/basedpyright" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['versions']['$ver']['dist']['integrity'])")
  python3 - "$dest" "$integrity" <<'EOF'
import hashlib, base64, sys
fam, expect = sys.argv[2].split('-', 1)
assert fam == 'sha512', fam
got = base64.b64encode(hashlib.sha512(open(sys.argv[1], 'rb').read()).digest()).decode()
assert got == expect, f'integrity mismatch: {got} != {expect}'
EOF
  local sha; sha=$(sha256_of "$dest")
  lock_sha basedpyright "$sha"
  record basedpyright "$fname" "$sha" "npm dist.integrity (sha512) + sha256" \
    "https://registry.npmjs.org/basedpyright/-/${fname}"
}

# ------------------------------------------------------------------- rust
fetch_rust() {
  local ver; ver=$(jqv '.artifacts.rust_channel_toml.version')
  local toml_url; toml_url=$(jqv '.artifacts.rust_channel_toml.url')
  local toml="$DL_DIR/$(basename "$toml_url")"
  [[ -f "$toml" ]] || { log "downloading rust channel toml ($ver)"; curl -fsSL --retry 3 -o "$toml.part" "$toml_url" >/dev/null && mv "$toml.part" "$toml"; }
  lock_sha rust_channel_toml "$(sha256_of "$toml")"

  # Components fetched from the channel toml: arch-specific get a target.
  # proc-macro-srv handling is decided at staging time after inspecting the
  # rust-analyzer-preview payload.
  local spec p target url hash fname dest
  for spec in rustc:x86_64-unknown-linux-gnu cargo:x86_64-unknown-linux-gnu \
              rust-std:x86_64-unknown-linux-gnu 'rust-src:*' \
              rust-analyzer-preview:x86_64-unknown-linux-gnu; do
    p="${spec%%:*}"; target="${spec#*:}"
    python3 - "$toml" "$p" "$target" > "$DL_DIR/.rust-$p.url" <<'EOF'
import tomllib, sys
data = tomllib.load(open(sys.argv[1], 'rb'))
pkg, target = sys.argv[2], sys.argv[3]
node = data['pkg'][pkg]
if target:
    node = node['target'][target]
# Prefer the .tar.xz payload (much smaller); fall back to .tar.gz.
url, hash_ = node.get('xz_url'), node.get('xz_hash')
if not url:
    url, hash_ = node['url'], node['hash']
print(url)
print(hash_)
EOF
  done

  for p in rustc cargo rust-std rust-src rust-analyzer-preview; do
    url=$(sed -n 1p "$DL_DIR/.rust-$p.url"); hash=$(sed -n 2p "$DL_DIR/.rust-$p.url")
    [[ -n "$url" ]] || { warn "rust component $p not found in channel toml"; continue; }
    fname=$(basename "$url"); dest="$DL_DIR/$fname"
    if [[ ! -f "$dest" ]]; then
      log "downloading rust component $p"
      curl -fsSL --retry 3 -o "$dest.part" "$url" >/dev/null && mv "$dest.part" "$dest"
    fi
    [[ "$(sha256_of "$dest")" == "$hash" ]] || die "rust $p: sha256 mismatch vs channel toml"
    log "verified rust component $p (channel toml sha256)"
    record "rust_$p" "$fname" "$hash" "channel toml sha256" "$url"
  done
}

# ---------------------------------------------------------- license texts
# Small license files fetched by URL and self-pinned like other artifacts.
fetch_licenses() {
  local dest_dir="$CACHE_DIR/licenses"
  mkdir -p "$dest_dir"
  local nvim_ver; nvim_ver=$(jqv '.artifacts.nvim.version')
  local items=(
    "nvim-LICENSE.txt|https://raw.githubusercontent.com/neovim/neovim/v${nvim_ver}/LICENSE.txt"
    "ts-python-LICENSE|https://raw.githubusercontent.com/tree-sitter/tree-sitter-python/$(jqv '.artifacts.ts_grammar_python.version')/LICENSE"
    "ts-c-LICENSE|https://raw.githubusercontent.com/tree-sitter/tree-sitter-c/$(jqv '.artifacts.ts_grammar_c.version')/LICENSE"
    "ts-cpp-LICENSE|https://raw.githubusercontent.com/tree-sitter/tree-sitter-cpp/$(jqv '.artifacts.ts_grammar_cpp.version')/LICENSE"
    "ts-rust-LICENSE|https://raw.githubusercontent.com/tree-sitter/tree-sitter-rust/$(jqv '.artifacts.ts_grammar_rust.version')/LICENSE"
  )
  local item name url dest sha pinned
  for item in "${items[@]}"; do
    name="${item%%|*}"; url="${item#*|}"; dest="$dest_dir/$name"
    if [[ ! -s "$dest" ]]; then
      log "downloading license $name"
      curl -fsSL --retry 3 -o "$dest.part" "$url" >/dev/null && mv "$dest.part" "$dest" \
        || die "license download failed: $url"
    fi
    sha=$(sha256_of "$dest")
    pinned=$(effective_sha "license_$name")
    if [[ -n "$pinned" ]]; then
      [[ "$sha" == "$pinned" ]] || die "license $name: checksum mismatch"
    else
      lock_sha "license_$name" "$sha"
    fi
    record "license_$name" "$name" "$sha" "sha256" "$url"
  done
}

# ------------------------------------------------------- generic artifacts
for name in ubuntu_base nvim clangd ts_grammar_python ts_grammar_c ts_grammar_cpp ts_grammar_rust \
            plugin_nvim-treesitter plugin_nvim-lspconfig plugin_nvim-cmp plugin_cmp-nvim-lsp \
            plugin_cmp-buffer plugin_LuaSnip plugin_friendly-snippets plugin_lualine.nvim \
            plugin_nvim-autopairs plugin_telescope.nvim plugin_plenary.nvim \
            plugin_nvim-tree.lua plugin_nvim-web-devicons; do
  fetch_generic "$name"
done
fetch_node
fetch_basedpyright
fetch_rust
fetch_licenses

mv "$FETCHED_JSON.tmp" "$FETCHED_JSON"
log "all artifacts fetched and verified -> $FETCHED_JSON"
