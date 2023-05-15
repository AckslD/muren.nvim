local cwd = vim.fn.getcwd()
vim.o.runtimepath = vim.o.runtimepath .. string.format(',%s/rtps/plenary.nvim', cwd)
vim.cmd('runtime! plugin/plenary.vim')
