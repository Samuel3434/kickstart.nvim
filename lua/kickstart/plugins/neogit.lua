vim.pack.add { 'https://github.com/NeogitOrg/neogit', 'https://github.com/nvim-lua/plenary.nvim' }
require('neogit').setup {}
vim.keymap.set('n', '<leader>gs', function() require('neogit').open() end, { desc = '[G]it [S]tatus' })
