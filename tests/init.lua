local cwd = vim.fn.getcwd()
vim.o.runtimepath = vim.o.runtimepath .. string.format(',%s/rtps/plenary.nvim', cwd)
vim.o.runtimepath = vim.o.runtimepath .. string.format(',%s', cwd)

_G.assert_equal_tables = function(tbl1, tbl2)
    assert(vim.deep_equal(tbl1, tbl2), string.format("%s ~= %s", vim.inspect(tbl1), vim.inspect(tbl2)))
end

require('muren').setup()
vim.cmd.cd('tests/data')
