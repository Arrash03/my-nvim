# nvim-forge manifest

All upstream artifacts are pinned in `pins.json` (declared pins) and
`pins-locked.json` (exact SHA-256 digests recorded at fetch time and
re-verified on every subsequent fetch). Artifacts with published upstream
checksums (Ubuntu base rootfs, Node.js, Rust channel manifests) are verified
against those checksums at fetch time in addition to the self-pinned digest.

## Core artifacts

| Artifact          | Version  | Upstream check                                   |
|-------------------|----------|--------------------------------------------------|
| ubuntu-base rootfs| 22.04.5  | cdimage.ubuntu.com SHA256SUMS (https)            |
| Neovim            | 0.12.6   | self-pinned SHA-256                              |
| Node.js           | 24.22.0  | nodejs.org SHASUMS256.txt + self-pinned          |
| BasedPyright      | 1.40.2   | npm registry dist.integrity (sha512) + self-pin  |
| clangd            | 23.1.0   | self-pinned SHA-256                              |
| Rust channel      | 1.99.1   | component hashes inside channel-rust-1.99.1.toml |
| &nbsp;rustc       | 1.99.1   | from channel toml                                |
| &nbsp;cargo       | 1.99.1   | from channel toml                                |
| &nbsp;rust-std    | 1.99.1   | from channel toml                                |
| &nbsp;rust-src    | 1.99.1   | from channel toml                                |
| &nbsp;rust-analyzer (preview) | 1.99.1 | from channel toml                       |

## Tree-sitter grammars

Pinned to the revisions declared by nvim-treesitter `main@29212d82`
(`parsers.lua`), compiled with gcc inside the Ubuntu 22.04 sandbox:

| Grammar            | Revision                                        |
|--------------------|-------------------------------------------------|
| tree-sitter-python | v0.25.0                                         |
| tree-sitter-c      | b780e47fc780ddc8da13afa35a3f4ed5c157823d        |
| tree-sitter-cpp    | c009222808634c1014f82438d4883753516a2c24        |
| tree-sitter-rust   | 77a3747266f4d621d0757825e6b11edcbf991ca5        |

## Plugins (commit-pinned)

| Plugin           | Commit                                                       |
|------------------|--------------------------------------------------------------|
| nvim-treesitter  | 29212d826054bb2948fa9d3a99eca9bf6a050eb2                     |
| nvim-lspconfig   | 45a3a444b710511c39abca3b60bb6e23a21e3de5                     |
| nvim-cmp         | 2ffe79f1f021def8dd1fcd81deb16f1bb0d989f3                     |
| cmp-nvim-lsp     | cbc7b02bb99fae35cb42f514762b89b5126651ef                     |
| cmp-buffer       | b74fab3656eea9de20a9b8116afa3cfc4ec09657                     |
| LuaSnip          | 0abc8f390b278c3b4aabc4c004ac8a088b65cf24                     |
| friendly-snippets| b4d01b0fdf3c9a549961c2f9ffe8dc09be166219                     |
| lualine.nvim     | 221ce6b2d999187044529f49da6554a92f740a96                     |
| nvim-autopairs   | 3172f40c16563db871a58f20d205c710ad782311                     |
| telescope.nvim   | 40aedd8a68c78a656a10a8d62d80c54af59420fb                     |
| plenary.nvim     | 74b06c6c75e4eeb3108ec01852001636d85a932b                     |
| nvim-tree.lua    | 9a2e0006d42f292eb3ade7dfdff201a7429a780c (v1.19.0)           |
| nvim-web-devicons| ec309a0eaff6ea967e58c275996155ab5c16938d                     |

## Legal

Every bundled component's license text is installed under
`/opt/nvim-forge/licenses/`; the package-level copyright file is at
`/usr/share/doc/nvim-forge/copyright`. glibc and libstdc++ are **not**
bundled — they come from the target system via the declared `Depends`.
