--
-- jump_mode.lua
--

local vim = vim
local api = vim.api
local nvim = require'bufferline.nvim'
local utils = require'bufferline.utils'
local len = utils.len
local slice = utils.slice
local state = require'bufferline.state'
local Buffer = require'bufferline.buffer'
local fnamemodify = vim.fn.fnamemodify
local bufname = vim.fn.bufname

----------------------------------------
-- Section: Buffer-picking mode state --
----------------------------------------

-- Constants
local LETTERS = vim.g.bufferline.letters
local INDEX_BY_LETTER = {}

local m = {
  letter_status = {}, -- array
  buffer_by_letter = {}, -- object
  letter_by_buffer = {}, -- object
}

-- Initialize INDEX_BY_LETTER
for index = 1, len(LETTERS) do
  local letter = slice(LETTERS, index, index)
  INDEX_BY_LETTER[letter] = index
  m.letter_status[index] = false
end

-- local empty_bufnr = nvim.create_buf(0, 1)

local function assign_next_letter(bufnr)
  bufnr = tonumber(bufnr)

  if m.letter_by_buffer[bufnr] ~= nil then
    return
  end

  -- First, try to assign a letter based on name
  if vim.g.bufferline.semantic_letters == true then
    local name = vim.fn.fnamemodify(vim.fn.bufname(bufnr), ':t:r')

    for i = 1, len(name) do
      local letter = string.lower(slice(name, i, i))

      if INDEX_BY_LETTER[letter] ~= nil then
        local index = INDEX_BY_LETTER[letter]
        local status = m.letter_status[index]
        if status == false then
          m.letter_status[index] = true
          -- letter = LETTERS[index]
          m.buffer_by_letter[letter] = bufnr
          m.letter_by_buffer[bufnr] = letter
          return letter
        end
      end
    end
  end

  -- Otherwise, assign a letter by usable order
  for i, status in ipairs(m.letter_status) do
    if status == 0 then
      local letter = LETTERS[i]
      m.letter_status[i] = true
      m.buffer_by_letter[letter] = bufnr
      m.letter_by_buffer[bufnr] = letter
      return letter
    end
  end

  return nil
end

local function unassign_letter(letter)
  if letter == '' or letter == nil then
    return
  end

  local index = INDEX_BY_LETTER[letter]

  m.letter_status[index] = false

  if m.buffer_by_letter[letter] ~= nil then
    local bufnr = m.buffer_by_letter[letter]
    m.buffer_by_letter[letter] = nil
    m.letter_by_buffer[bufnr] = nil
  end
end

local function get_letter(bufnr)
   if m.letter_by_buffer[bufnr] ~= nil then
      return m.letter_by_buffer[bufnr]
   end
   return assign_next_letter(bufnr)
end

local function unassign_letter_for(bufnr)
  unassign_letter(get_letter(bufnr))
end

-- local function update_buffer_letters()
--   local assigned_letters = {}
-- 
--   for index, bufnr in range(len(state.get_buffers())) do
--     local letter_from_buffer = get_letter(bufnr)
--     if letter_from_buffer == nil or assigned_letters[letter_from_buffer] ~= nil then
--         letter_from_buffer = assign_next_letter(bufnr)
--     else
--         m.letter_status[index] = true
--     end
--     if letter_from_buffer ~= nil then
--         let bufnr_from_state = get(s:m.buffer_by_letter, letter_from_buffer, nil)
-- 
--         if bufnr_from_state ~= bufnr
--           let s:m.buffer_by_letter[letter_from_buffer] = bufnr
--           if has_key(s:m.buffer_by_letter, bufnr_from_state)
--               call remove(s:m.buffer_by_letter, bufnr_from_state)
--           end
--         end
-- 
--         let assigned_letters[letter_from_buffer] = 1
--     end
--   end
-- 
--   let index = 0
--   for index in range(len(s:LETTERS))
--     let letter = s:LETTERS[index]
--     let status = s:m.letter_status[index]
--     if status && !has_key(assigned_letters, letter)
--         call s:unassign_letter(letter)
--     end
--   end
-- end

-- print(vim.inspect(get_letter(nvim.get_current_buf())))
-- print(vim.inspect(get_letter(nvim.get_current_buf())))
-- print(vim.inspect(m.letter_status))
-- print(vim.inspect(unassign_letter('j')))
-- print(vim.inspect(m.letter_status))

-- 
-- local function shadow_open()
--    if !g:bufferline.shadow
--       return
--    end
--    let opts =  {
--    \ 'relative': 'editor',
--    \ 'style': 'minimal',
--    \ 'width': &columns,
--    \ 'height': &lines - 2,
--    \ 'row': 2,
--    \ 'col': 0,
--    \ }
--    let s:shadow_winid = nvim_open_win(s:empty_bufnr, false, opts)
--    call setwinvar(s:shadow_winid, '&winhighlight', 'Normal:BufferShadow,NormalNC:BufferShadow,EndOfBuffer:BufferShadow')
--    call setwinvar(s:shadow_winid, '&winblend', 80)
-- end
-- 
-- local function shadow_close()
--    if !g:bufferline.shadow
--       return
--    end
--    if s:shadow_winid ~= nil && nvim_win_is_valid(s:shadow_winid)
--       call nvim_win_close(s:shadow_winid, true)
--    end
--    let s:shadow_winid = nil
-- end


local function activate()
  state.is_picking_buffer = true
  vim.fn['bufferline#update']()
  nvim.command('redraw')
  state.is_picking_buffer = false

  local char = vim.fn.getchar()
  local letter = vim.fn.nr2char(char)

  local did_switch = false

  if letter ~= '' then
    if m.buffer_by_letter[letter] ~= nil then
      local bufnr = m.buffer_by_letter[letter]
      nvim.command('buffer' .. bufnr)
      did_switch = true
    else
      nvim.command('echohl WarningMsg')
      nvim.command([[echom "Could't find buffer"]])
      nvim.command('echohl None')
    end
  end

  vim.fn['bufferline#update']()
  nvim.command('redraw')
end

m.activate = activate
m.get_letter = get_letter
m.unassign_letter = unassign_letter
m.unassign_letter_for = unassign_letter_for
m.assign_next_letter = assign_next_letter
return m
