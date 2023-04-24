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
    vim.cmd.MurenClose()
    require('muren.ui').reset()
    unload('muren')
    set_current_lines({})
  end)
  it("basic_usage", function()
    local orig_buf = vim.api.nvim_get_current_buf()
    set_current_lines({'foo'})
    vim.cmd.MurenToggle()
    set_current_lines({'foo'})
    feedkeys('<Tab>')
    set_current_lines({'bar'})
    local buf = vim.api.nvim_get_current_buf()
    feedkeys('<CR>')
    assert.are.equal(buf, vim.api.nvim_get_current_buf())
    feedkeys('q')
    assert.are.equal(orig_buf, vim.api.nvim_get_current_buf())
    assert_current_lines({'bar'})
  end)
  it("persistent_toggle", function()
    set_current_lines({'foo'})
    vim.cmd.MurenToggle()
    set_current_lines({'foo'})
    feedkeys('<Tab>')
    set_current_lines({'bar'})
    feedkeys('q')
    vim.cmd.MurenToggle()
    assert_current_lines({'foo'})
    feedkeys('<Tab>')
    assert_current_lines({'bar'})
    feedkeys('q')
    vim.cmd.MurenFresh()
    assert_current_lines({})
    feedkeys('<Tab>')
    assert_current_lines({})
  end)
  it("swap", function()
    set_current_lines({'foo', 'bar'})
    vim.cmd.MurenToggle()
    assert.are.equal(require('muren.options').values.two_step, false)
    feedkeys('<C-s>')
    feedkeys('j')
    feedkeys('<CR>')
    feedkeys('<C-s>')
    assert.are.equal(require('muren.options').values.two_step, true)
    set_current_lines({'foo', 'bar'})
    feedkeys('<Tab>')
    set_current_lines({'bar', 'foo'})
    feedkeys('<CR>')
    feedkeys('q')
    assert_current_lines({'bar', 'foo'})
  end)
  it("unique", function()
    vim.cmd.edit("tmp.txt")
    set_current_lines({'fo', 'foo', 'foo', 'fooo'})
    vim.cmd.write()
    vim.cmd('/fo\\+')
    vim.cmd.MurenUnique()
    assert_current_lines({'fo', 'foo', 'fooo'})
  end)
  -- toggle options
  it("2-step", function()
    set_current_lines({'foo', 'bar'})
    vim.cmd.MurenToggle()
    set_current_lines({'foo', 'bar'})
    feedkeys('<Tab>')
    set_current_lines({'bar', 'foo'})
    feedkeys('<CR>')
    feedkeys('q')
    assert_current_lines({'foo', 'foo'})
  end)
  it("all_on_line true", function()
    set_current_lines({'foo foo'})
    vim.cmd.MurenToggle()
    set_current_lines({'foo'})
    feedkeys('<Tab>')
    set_current_lines({'bar'})
    feedkeys('<CR>')
    feedkeys('q')
    assert_current_lines({'bar bar'})
  end)
  it("all_on_line false", function()
    set_current_lines({'foo foo'})
    vim.cmd.MurenToggle()
    set_current_lines({'foo'})
    feedkeys('<Tab>')
    set_current_lines({'bar'})
    feedkeys('<C-s>')
    feedkeys('jj')
    feedkeys('<CR>')
    feedkeys('<C-s>')
    feedkeys('<CR>')
    feedkeys('q')
    assert_current_lines({'bar foo'})
  end)
end)
