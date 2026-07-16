-- Helper: find an opencode terminal buffer in the current tabpage
local function find_opencode_in_current_tab()
  local current_tab = vim.api.nvim_get_current_tabpage()
  local wins = vim.api.nvim_tabpage_list_wins(current_tab)
  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == 'terminal' and vim.api.nvim_buf_get_name(buf):match 'opencode' then return buf, win end
  end
  return nil, nil
end

-- Helper: find any opencode terminal buffer, and the tabpage it's displayed in (if any)
local function find_opencode_global()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buftype == 'terminal' and vim.api.nvim_buf_get_name(buf):match 'opencode' then
      -- check if it's shown in any window
      local win = vim.fn.bufwinid(buf)
      local tab = win ~= -1 and vim.fn.win_id2tabwin(win)[1] or nil
      return buf, tab
    end
  end
  return nil, nil
end

-- The reference string (unchanged)
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

local function build_reference()
  local relative_path = vim.fn.expand '%:.'
  local line_range = get_line_range()
  return '@' .. relative_path .. ':' .. line_range
end

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

-- Send the reference to a terminal buffer (if a job_id exists)
local function send_reference(buf, reference)
  local job_id = vim.b[buf].terminal_job_id
  if job_id then vim.fn.chansend(job_id, reference) end
end

-- Split mode (Alt+o s)
local function send_to_opencode_split()
  local current_buf = vim.api.nvim_get_current_buf()
  -- If the current buffer itself is an opencode terminal, hide it (toggle off)
  if vim.bo[current_buf].buftype == 'terminal' and vim.api.nvim_buf_get_name(current_buf):match 'opencode' then
    vim.cmd 'hide'
    return
  end

  local reference = build_reference()

  -- 1. Look for an opencode terminal already in the current tab
  local existing_buf, existing_win = find_opencode_in_current_tab()
  if existing_buf then
    -- Focus its window and send
    vim.api.nvim_set_current_win(existing_win)
    send_reference(existing_buf, reference)
    return
  end

  -- 2. Look for any opencode terminal globally (reuse the buffer in a new split)
  local any_buf = find_opencode_global()
  if any_buf then
    vim.cmd('botright sbuffer ' .. any_buf)
    send_reference(any_buf, reference)
    return
  end

  -- 3. No terminal exists → create a new split with the opencode command
  vim.cmd 'botright split | terminal opencode'
  local new_buf = vim.api.nvim_get_current_buf()
  wait_for_terminal_ready(new_buf, function() send_reference(new_buf, reference) end)
end

-- Full screen mode (Alt+o o)
local function send_to_opencode_fullscreen()
  local current_buf = vim.api.nvim_get_current_buf()
  -- If current buffer is an opencode terminal and we're already fullscreen, just hide it
  if vim.bo[current_buf].buftype == 'terminal' and vim.api.nvim_buf_get_name(current_buf):match 'opencode' then
    -- Check if the current tab contains only this window (true fullscreen)
    local wins = vim.api.nvim_tabpage_list_wins(0)
    if #wins == 1 then
      vim.cmd 'hide'
      return
    else
      -- If not fullscreen, just hide the buffer (or close the window)
      vim.cmd 'hide'
      return
    end
  end

  local reference = build_reference()

  -- 1. Is there already an opencode terminal?
  local buf, tab = find_opencode_global()
  if buf then
    if tab then
      -- Switch to the tabpage that contains it (full screen experience)
      vim.cmd('tabnext ' .. tab)
      -- If the terminal isn't the only window in that tab, you might want to maximize it.
      -- Here we simply focus it; you could add `:only` if you want it to be the sole window.
      local win = vim.fn.bufwinid(buf)
      if win ~= -1 then vim.api.nvim_set_current_win(win) end
      send_reference(buf, reference)
    else
      -- Hidden buffer → open it in a new tab (full screen)
      vim.cmd('tab sbuffer ' .. buf)
      send_reference(buf, reference)
    end
    return
  end

  -- 2. No terminal exists → create one in a new tab
  vim.cmd 'tabnew | terminal opencode'
  local new_buf = vim.api.nvim_get_current_buf()
  wait_for_terminal_ready(new_buf, function() send_reference(new_buf, reference) end)
end

-- Key mappings
vim.keymap.set({ 'n', 'v' }, '<A-o>s', send_to_opencode_split, { desc = 'OpenCode: split' })
vim.keymap.set({ 'n', 'v' }, '<A-o>o', send_to_opencode_fullscreen, { desc = 'OpenCode: full screen' })

-- Optional: map from terminal mode as well, so you can send a new reference while inside the terminal
vim.keymap.set('t', '<A-o>s', send_to_opencode_split, { desc = 'OpenCode: split (from terminal)' })
vim.keymap.set('t', '<A-o>o', send_to_opencode_fullscreen, { desc = 'OpenCode: full screen (from terminal)' })
