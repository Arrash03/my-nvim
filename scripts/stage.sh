#!/usr/bin/env bash
# Assemble the installable bundle tree under build/root/ (fpm-less manual
# staging; the tree is later archived by dpkg-deb).
#
# Final layout (installed by the .deb):
#   /opt/nvim-forge/bin/nvim             bundled Neovim
#   /opt/nvim-forge/share/nvim/runtime   Neovim runtime files
#   /opt/nvim-forge/lib/nvim             Neovim's bundled parsers/libs
#   /opt/nvim-forge/lib/node/bin/node    Node.js runtime (for basedpyright)
#   /opt/nvim-forge/lib/rust/{bin,lib}   Rust toolchain (cargo, rustc,
#                                        rust-std, rust-src, rust-analyzer)
#   /opt/nvim-forge/servers/
#       basedpyright/node_modules/...    BasedPyright (pure JS)
#       clangd/{bin,lib}                 clangd + private libs
#   /opt/nvim-forge/plugins/<name>/      vendored Neovim plugins
#   /opt/nvim-forge/parsers/parser/*.so  prebuilt Tree-sitter parsers
#   /opt/nvim-forge/config/              the Lua configuration
#   /opt/nvim-forge/manifest/            pins + generated manifest
#   /opt/nvim-forge/licenses/            license texts of all components
#   /usr/bin/nvim-forge                  launcher
#   /usr/share/doc/nvim-forge/           README, copyright, changelog
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FJ="$CACHE_DIR/fetched.json"
fj() { jq -r ".[\"$1\"].file" "$FJ"; }

R="$STAGE_DIR/root"
OPT="$R/opt/nvim-forge"

log "clean staging dir"
rm -rf "$STAGE_DIR"
mkdir -p "$OPT"/{bin,lib,servers,plugins,config,manifest,licenses} \
         "$OPT/parsers/parser" "$R/usr/bin" "$R/usr/share/doc/nvim-forge"

# ---------------------------------------------------------------- Neovim --
log "staging Neovim"
NVIMDIR="$CACHE_DIR/nvim-extract"
rm -rf "$NVIMDIR"; mkdir -p "$NVIMDIR"
tar xzf "$DL_DIR/$(fj nvim)" -C "$NVIMDIR"
cp -a "$NVIMDIR"/nvim-linux-x86_64/bin/nvim "$OPT/bin/nvim"
cp -a "$NVIMDIR"/nvim-linux-x86_64/lib/nvim "$OPT/lib/nvim"
mkdir -p "$OPT/share"
cp -a "$NVIMDIR"/nvim-linux-x86_64/share/nvim "$OPT/share/nvim"

# ------------------------------------------------------------------ Node --
# Only the runtime binary is needed; npm/npx/corepack and the bundled
# npm modules are deliberately NOT shipped (the target never runs npm).
log "staging Node.js runtime"
NODEDIR="$CACHE_DIR/node-extract"
rm -rf "$NODEDIR"; mkdir -p "$NODEDIR"
tar xJf "$DL_DIR/$(fj node)" -C "$NODEDIR"
NODEROOT=$(echo "$NODEDIR"/node-v*-linux-x64)
mkdir -p "$OPT/lib/node/bin"
cp -a "$NODEROOT/bin/node" "$OPT/lib/node/bin/node"
cp -a "$NODEROOT/LICENSE" "$OPT/licenses/node-LICENSE" 2>/dev/null || true

# ------------------------------------------------------------ Rust toolchain
# Merge rustc + cargo + rust-std + rust-src component payloads into a single
# toolchain prefix (this is exactly what components' install.sh would do,
# but auditable and side-effect free).  rust-analyzer is placed in bin/ so
# its RUNPATH ($ORIGIN/../lib) resolves librustc_driver.
log "staging Rust toolchain (rustc, cargo, rust-std, rust-src, rust-analyzer)"
RUST="$OPT/lib/rust"
mkdir -p "$RUST"
extract_component() { # pattern(topdir/innerdir) archive
  tar xJf "$DL_DIR/$2" -C "$RUST" --strip-components=2 --wildcards "$1"
}
extract_component 'rustc-*/rustc'                    "$(fj rust_rustc)"
extract_component 'cargo-*/cargo'                    "$(fj rust_cargo)"
extract_component 'rust-std-*/rust-std-*'            "$(fj rust_rust-std)"
extract_component 'rust-src-*/rust-src'              "$(fj rust_rust-src)"
# rust-analyzer-preview payload -> bin/ + share/doc
RA_TAR="$DL_DIR/$(fj rust_rust-analyzer-preview)"
mkdir -p "$RUST/.ra"
tar xJf "$RA_TAR" -C "$RUST/.ra"
cp -a "$RUST/.ra"/*-x86_64-unknown-linux-gnu/rust-analyzer-preview/bin/rust-analyzer "$RUST/bin/rust-analyzer"
cp -a "$RUST/.ra"/*-x86_64-unknown-linux-gnu/rust-analyzer-preview/share "$RUST/share" 2>/dev/null || true
rm -rf "$RUST/.ra"
# rust-objcopy / rust-lld carry RUNPATH [$ORIGIN/../lib], which in the
# original rustup layout resolves to the toolchain lib/ (where libLLVM
# lives).  In our merged prefix they sit one level deeper, so expose
# libLLVM at the path their RUNPATH expects.
RUSTLIB_DIR="$RUST/lib/rustlib/x86_64-unknown-linux-gnu/lib"
if [[ -f "$RUST/lib/libLLVM.so.23.1-rust-1.99.1-stable" && -d "$RUSTLIB_DIR" ]]; then
  ln -sfn ../../../libLLVM.so.23.1-rust-1.99.1-stable \
    "$RUSTLIB_DIR/libLLVM.so.23.1-rust-1.99.1-stable"
fi
"$RUST/bin/rustc" --version > "$OPT/manifest/rustc-version.txt" 2>/dev/null || \
  warn "could not run staged rustc on the build host (checked later in sandbox)"

# --------------------------------------------------------- language servers
log "staging BasedPyright"
BP="$OPT/servers/basedpyright/node_modules/basedpyright"
mkdir -p "$BP"
tar xzf "$DL_DIR/$(fj basedpyright)" -C "$BP" --strip-components=1
cp -a "$BP/LICENSE.txt" "$OPT/licenses/basedpyright-LICENSE.txt" 2>/dev/null || true

log "staging clangd"
CLANGD_SRC="$CACHE_DIR/clangd-extract"
rm -rf "$CLANGD_SRC"; mkdir -p "$CLANGD_SRC"
unzip -q "$DL_DIR/$(fj clangd)" -d "$CLANGD_SRC"
cp -a "$CLANGD_SRC"/clangd_*/bin "$OPT/servers/clangd-bin"
mkdir -p "$OPT/servers/clangd"
mv "$OPT/servers/clangd-bin" "$OPT/servers/clangd/bin"
cp -a "$CLANGD_SRC"/clangd_*/lib "$OPT/servers/clangd/lib"
cp -a "$CLANGD_SRC"/clangd_*/LICENSE.TXT "$OPT/licenses/clangd-LICENSE.TXT"

# ----------------------------------------------------------------- plugins
log "staging plugins"
for name in nvim-treesitter nvim-lspconfig nvim-cmp cmp-nvim-lsp cmp-buffer \
            LuaSnip friendly-snippets lualine.nvim nvim-autopairs \
            telescope.nvim plenary.nvim nvim-tree.lua nvim-web-devicons; do
  key="plugin_$name"
  src="$CACHE_DIR/plugins/$name"
  rm -rf "$src"; mkdir -p "$src"
  tar xzf "$DL_DIR/$(fj "$key")" -C "$src" --strip-components=1
  # Trim development-only files (keeps license files, lua/, plugin/, doc/).
  rm -rf "$src"/.github "$src"/.gitlab-ci.yml "$src"/tests "$src"/test \
         "$src"/scripts "$src"/Makefile "$src"/.luacheckrc "$src"/.editorconfig \
         "$src"/.stylua.toml "$src"/.gitignore "$src"/.pre-commit-config.yaml \
         "$src"/scripts 2>/dev/null || true
  cp -a "$src" "$OPT/plugins/$name"
done
# License texts of plugins.
find "$OPT/plugins" -maxdepth 2 -iname 'LICENSE*' | while read -r f; do
  comp=$(echo "$f" | awk -F/ '{print $(NF-1)}')
  cp -a "$f" "$OPT/licenses/plugin-$comp-LICENSE" 2>/dev/null || true
done

# ---------------------------------------------------------------- parsers --
log "staging Tree-sitter parsers"
cp -a "$BUILD_DIR/parsers/parser/"*.so "$OPT/parsers/parser/"

# ----------------------------------------------------------------- config --
log "staging configuration"
cp -a "$NVF_ROOT/config/." "$OPT/config/"

# --------------------------------------------------------------- helptags --
# Generate :help tags offline at build time so :help works without
# :helptags on the target.
log "generating help tags"
# NB: nvim accepts at most 10 --cmd arguments, so all runtimepaths go into
# a single :set invocation (repeating the option) and a second one runs
# helptags.
"$OPT/bin/nvim" --headless -u NONE \
  --cmd "set runtimepath^=$OPT/plugins/nvim-lspconfig runtimepath^=$OPT/plugins/nvim-treesitter runtimepath^=$OPT/plugins/nvim-cmp runtimepath^=$OPT/plugins/LuaSnip runtimepath^=$OPT/plugins/lualine.nvim runtimepath^=$OPT/plugins/telescope.nvim runtimepath^=$OPT/plugins/plenary.nvim runtimepath^=$OPT/plugins/nvim-autopairs runtimepath^=$OPT/plugins/nvim-tree.lua runtimepath^=$OPT/plugins/nvim-web-devicons" \
  --cmd "helptags ALL" --cmd "qa!" > "$CACHE_DIR/helptags.log" 2>&1 \
  || warn "helptags generation reported issues (see cache/helptags.log)"
[[ -s "$CACHE_DIR/helptags.log" ]] && tail -5 "$CACHE_DIR/helptags.log" || true

# ---------------------------------------------------------------- launcher
log "staging launcher"
install -m 0755 "$NVF_ROOT/packaging/nvim-forge-launcher" "$R/usr/bin/nvim-forge"

# ------------------------------------------------------------ doc / legal --
log "staging docs and licenses"
install -m 0644 "$NVF_ROOT/README.md" "$R/usr/share/doc/nvim-forge/README.md"
cp -a "$NVF_ROOT/packaging/copyright" "$R/usr/share/doc/nvim-forge/copyright"
gzip -9n < "$NVF_ROOT/packaging/changelog" > "$R/usr/share/doc/nvim-forge/changelog.Debian.gz"

# Component licenses into the package-wide licenses dir.
cp -a "$OPT/licenses/nvim-LICENSE"* "$OPT/licenses/" 2>/dev/null || true
[[ -d "$CACHE_DIR/licenses" ]] && cp -a "$CACHE_DIR/licenses/." "$OPT/licenses/" 2>/dev/null || true
# Rust toolchain licenses (top-level of the rustc component tarball).
tar xJf "$DL_DIR/$(fj rust_rustc)" -C "$OPT/licenses" --strip-components=1 \
    --wildcards 'rustc-*/LICENSE-APACHE' 'rustc-*/LICENSE-MIT' 2>/dev/null || warn "rust license texts not extracted"
for f in "$OPT/licenses"/LICENSE-APACHE "$OPT/licenses"/LICENSE-MIT; do
  [[ -f "$f" ]] && mv "$f" "$OPT/licenses/rust-$(basename "$f")"
done

# ---------------------------------------------------------------- manifest
log "staging manifest"
cp -a "$MANIFEST_DIR/pins.json" "$OPT/manifest/pins.json"
cp -a "$MANIFEST_DIR/pins-locked.json" "$OPT/manifest/pins-locked.json"
cp -a "$CACHE_DIR/fetched.json" "$OPT/manifest/fetched.json"
[[ -f "$MANIFEST_DIR/MANIFEST.md" ]] && cp -a "$MANIFEST_DIR/MANIFEST.md" "$OPT/manifest/MANIFEST.md" || true

# nvim license files from the release tarball
find "$NVIMDIR" -maxdepth 3 -iname 'LICENSE*' | while read -r f; do
  cp -a "$f" "$OPT/licenses/nvim-$(basename "$f")" 2>/dev/null || true
done

log "staging complete:"
du -sh "$OPT"/* | sort -k2
