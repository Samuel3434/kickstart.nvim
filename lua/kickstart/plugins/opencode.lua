local function find_opencode_terminal()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buftype == 'terminal' then
      local name = vim.api.nvim_buf_get_name(buf)
      if name:match 'opencode' then return buf end
    end
  end
  return nil
end

local function get_line_range()
  local mode = vim.fn.mode()
  if mode == 'v' or mode == 'V' then
    local start_line = vim.fn.line 'v'
    local end_line = vim.fn.line '.'
    if start_line > end_line then
      start_line, end_line = end_line, start_line
    end
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', true)
    if start_line == end_line then
      return tostring(start_line)
    else
      return start_line .. '-' .. end_line
    end
  else
    return tostring(vim.fn.line '.')
  end
end

local function is_opencode_terminal(buf) return vim.bo[buf].buftype == 'terminal' and vim.api.nvim_buf_get_name(buf):match 'opencode' ~= nil end

local function wait_for_terminal_ready(buf, callback, opts)
  opts = opts or {}
  local timeout = opts.timeout or 5000
  local interval = opts.interval or 100
  local elapsed = 0

  local timer = vim.uv.new_timer()
  timer:start(
    0,
    interval,
    vim.schedule_wrap(function()
      elapsed = elapsed + interval
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local has_content = false
      for _, line in ipairs(lines) do
        if line:match '%S' then
          has_content = true
          break
        end
      end

      if has_content or elapsed >= timeout then
        timer:stop()
        timer:close()
        callback()
      end
    end)
  )
end

local function toggle_or_send_opencode()
  local current_buf = vim.api.nvim_get_current_buf()

  if is_opencode_terminal(current_buf) then
    vim.cmd 'hide'
    return
  end

  local relative_path = vim.fn.expand '%:.'
  local line_range = get_line_range()
  local reference = '@' .. relative_path .. ':' .. line_range

  local term_buf = find_opencode_terminal()

  if not term_buf then
    vim.cmd 'botright split | terminal opencode'
    local new_buf = vim.api.nvim_get_current_buf()
    wait_for_terminal_ready(new_buf, function()
      local job_id = vim.b[new_buf].terminal_job_id
      if job_id then vim.fn.chansend(job_id, reference) end
    end)
    return
  end

  local job_id = vim.b[term_buf].terminal_job_id
  if job_id then vim.fn.chansend(job_id, reference) end

  local win_id = vim.fn.bufwinid(term_buf)
  if win_id == -1 then vim.cmd('botright sbuffer ' .. term_buf) end
end

vim.keymap.set({ 'n', 'v', 't' }, '<A-o>', toggle_or_send_opencode, { desc = 'Toggle OpenCode' })
