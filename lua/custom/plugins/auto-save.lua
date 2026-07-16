vim.pack.add { 'https://github.com/okuuva/auto-save.nvim' }
require('auto-save').setup {
  enabled = true,
  trigger_events = {
    immediate_save = { 'BufLeave', 'FocusLost', 'QuitPre' },
    defer_save = { 'InsertLeave', 'TextChanged' },
    cancel_deferred_save = { 'InsertEnter' },
  },
  condition = function(buf)
    if vim.fn.getbufvar(buf, '&buftype') ~= '' then return false end
    local excluded = {
      gitcommit = true, NvimTree = true, TelescopePrompt = true,
      neo_tree = true, oil = true, toggleterm = true,
    }
    if excluded[vim.bo[buf].filetype] then return false end
    return true
  end,
  write_all_buffers = false,
  noautocmd = false,
  debounce_delay = 1000,
}
