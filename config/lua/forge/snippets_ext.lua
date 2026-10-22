--[[
  Modest set of nvim-forge original snippets, one section per supported
  language.  friendly-snippets already covers common idioms; these add
  the few stubs we reach for constantly in daily systems work.
]]

local M = {}

function M.load(ls)
  local s, t, i, f, fmt = ls.s, ls.text_node, ls.insert_node, ls.function_node, ls.fmt

  local function node_count(snip)
    return #snip.nodes
  end

  -- ---------------------------------------------------------------- Python
  ls.add_snippets('python', {
    s('main', fmt([[
if __name__ == '__main__':
    {}
]], { i(1, 'pass') })),
    s('defm', fmt('def {}({}) -> {}:\n    {}', {
      i(1, 'name'), i(2, 'args'), i(3, 'None'), i(4, 'pass'),
    })),
    s('cls', fmt('class {}:\n    def __init__(self, {}):\n        {}\n    {}', {
      i(1, 'Name'), i(2, 'args'), i(3, 'super().__init__()'), i(0),
    })),
    s('tdef', fmt('def test_{}() -> None:\n    {}\n    assert {}', {
      i(1, 'behaviour'), i(2, 'result = compute()'), i(3, 'result == expected'),
    })),
    s('try', fmt('try:\n    {}\nexcept {} as exc:\n    {}', {
      i(1, 'pass'), i(2, 'Exception'), i(0, 'raise'),
    })),
  }, { key = 'nvf-python' }),

  -- -------------------------------------------------------------------- C
  ls.add_snippets('c', {
    s('incg', fmt([[
#ifndef {guard}
#define {guard}

{}

#endif /* {guard} */
]], {
      guard = f(function()
        return 'NVF_' .. (vim.fn.expand('%:t'):upper():gsub('[^%w]', '_'))
      end, {}),
      i(1),
    })),
    s('func', fmt('{} {}({}) {{\n    {}\n}}', {
      i(1, 'int'), i(2, 'name'), i(3, 'void'), i(0, 'return 0;'),
    })),
    s('printf', fmt('printf("{}\\n", {});', { i(1, '%d'), i(0, 'value') })),
    s('fori', fmt('for ({} = 0; {} < {}; {}++) {{\n    {}\n}}', {
      i(1, 'int i = 0'), f(function(a) return a[1][1]:match('([%w_]+)') or 'i' end, { 1 }),
      i(2, 'n'), f(function(a) return a[1][1]:match('([%w_]+)') or 'i' end, { 1 }), i(0),
    })),
  }, { key = 'nvf-c' }),

  -- ------------------------------------------------------------------ C++
  ls.add_snippets('cpp', {
    s('main', fmt([[
int main(int argc, char **argv) {{
    {}
    return 0;
}}
]], { i(0) })),
    s('cls', fmt('class {} {{\npublic:\n    {}({});\n    ~{}();\n\nprivate:\n    {}\n}};', {
      i(1, 'Name'), f(function(a) return a[1][1] end, { 1 }), i(2), f(function(a) return a[1][1] end, { 1 }), i(0),
    })),
    s('rfor', fmt('for (auto &{} : {}) {{\n    {}\n}}', { i(1, 'item'), i(2, 'items'), i(0) })),
    s('uptr', fmt('auto {} = std::make_unique<{}>({});', { i(1, 'ptr'), i(2, 'Type'), i(0) })),
    s('catch', fmt('try {{\n    {}\n}} catch (const {} &exc) {{\n    {}\n}}', {
      i(1, 'pass'), i(2, 'std::exception'), i(0, 'return 1;'),
    })),
  }, { key = 'nvf-cpp' }),

  -- ----------------------------------------------------------------- Rust
  ls.add_snippets('rust', {
    s('fnt', fmt([[
#[test]
fn {}() {{
    {}
}}
]], { i(1, 'test_name'), i(0) })),
    s('fnmain', fmt([[
fn main() {{
    {}
}}
]], { i(0) })),
    s('sdef', fmt('fn {}({}) -> {} {{\n    {}\n}}', {
      i(1, 'name'), i(2, 'x: i32'), i(3, 'i32'), i(0),
    })),
    s('st', fmt('struct {} {{\n    {}\n}}', { i(1, 'Name'), i(0, 'field: u32,') })),
    s('implst', fmt('impl {} {{\n    pub fn new({}) -> Self {{\n        {}\n    }}\n}}', {
      i(1, 'Type'), i(2, 'field: u32'), i(0, 'Self { field }'),
    })),
    s('match', fmt('match {} {{\n    {} => {{}\n    }}\n}}', { i(1, 'value'), i(2, 'Some(x)'), i(0) })),
  }, { key = 'nvf-rust' })
end

return M
