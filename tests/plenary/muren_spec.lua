local function escape_keys(keys)
    return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

local function feedkeys(keys)
    vim.api.nvim_feedkeys(escape_keys(keys), 'xmt', true)
end

local function unload(name)
    for pkg, _ in pairs(package.loaded) do
        if vim.fn.match(pkg, name) ~= -1 then
            package.loaded[pkg] = nil
        end
    end
end

local function set_current_lines(lines)
  vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
end

local function assert_current_lines(expected_lines)
  local current = vim.fn.join(vim.api.nvim_buf_get_lines(0, 0, -1, true), '\n')
  local expected = vim.fn.join(expected_lines, '\n')
  assert.are.equal(current, expected)
end

describe("muren", function()
    after_each(function()
        unload('muren')
        vim.api.nvim_buf_set_lines(0, 0, -1, true, {})
    end)
    it("simple", function()
      local orig_buf = vim.api.nvim_get_current_buf()
      set_current_lines({'foo', 'bar'})
      vim.cmd.MurenToggle()
      set_current_lines({'foo', 'bar'})
      feedkeys('<Tab>')
      set_current_lines({'bar', 'foo'})
      local buf = vim.api.nvim_get_current_buf()
      feedkeys('<CR>')
      assert.are.equal(buf, vim.api.nvim_get_current_buf())
      feedkeys('q')
      assert.are.equal(orig_buf, vim.api.nvim_get_current_buf())
      assert_current_lines({'bar', 'foo'})
    end)
end)
