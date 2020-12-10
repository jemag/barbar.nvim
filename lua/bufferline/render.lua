-- !::exe [luafile %]
--
-- render.lua
--

local vim = vim
local api = vim.api
local nvim = require'bufferline.nvim'
local utils = require'bufferline.utils'
local get_icon = require'bufferline.get-icon'
local len = utils.len
local slice = utils.slice
local reverse = utils.reverse
local state = require'bufferline.state'
local Buffer = require'bufferline.buffer'
local Layout = require'bufferline.layout'
local JumpMode = require'bufferline.jump_mode'

local HL_BY_ACTIVITY = {
  [0] = 'Inactive',
  [1] = 'Visible',
  [2] = 'Current',
}

local function hl(name)
   return '%#' .. name .. '#'
end

local function slice_groups_right(groups, width)
  local result = ''
  local accumulated_width = 0
  for i, group in ipairs(groups) do
    local hl   = group[1]
    local text = group[2]
    local text_width = nvim.strwidth(text)

    accumulated_width = accumulated_width + text_width

    if accumulated_width >= width then
      local diff = text_width - (accumulated_width - width)
      result = result .. hl .. vim.fn.strcharpart(text, 0, diff)
      break
    end
    result = result .. hl .. text
  end
  return result
end

local function slice_groups_left(groups, width)
  local result = ''
  local accumulated_width = 0
  for i, group in ipairs(reverse(groups)) do
    local hl   = group[1]
    local text = group[2]
    local text_width = nvim.strwidth(text)

    accumulated_width = accumulated_width + text_width

    if accumulated_width >= width then
      local length = text_width - (accumulated_width - width)
      local start = text_width - length
      result = hl .. vim.fn.strcharpart(text, start, length) .. result
      break
    end
    result = hl .. text .. result
  end
  return result
end

local function render(update_names)
  local buffer_numbers = state.get_updated_buffers(update_names)
  local current = vim.fn.bufnr('%')

  -- Store current buffer to open new ones next to this one
  if nvim.buf_get_option(current, 'buflisted') then
    local ok, is_empty = pcall(api.nvim_buf_get_var, current, 'empty_buffer')
    if ok and is_empty then
      state.last_current_buffer = nil
    else
      state.last_current_buffer = current
    end
  end

  local opts = vim.g.bufferline
  local icons = vim.g.icons

  local click_enabled = vim.fn.has('tablineat') and opts.clickable
  local has_icons = opts.icons ~= false
  local has_numbers = opts.numbers ~= false
  -- local has_numbers = opts.icons == 'numbers'
  local has_close = opts.closable

  local layout = Layout.calculate(state)

  local items = {}

  local accumulated_width = 0
  for i, buffer_number in ipairs(buffer_numbers) do

    local buffer_data = state.get_buffer_data(buffer_number)
    local buffer_name = buffer_data.name or '[no name]'

    buffer_data.dimensions = Layout.calculate_dimensions(
      buffer_name, layout.base_width, layout.padding_width)

    local activity = Buffer.get_activity(buffer_number)
    local is_visible = activity == 1
    local is_current = activity == 2
    -- local is_inactive = activity == 0
    local is_modified = nvim.buf_get_option(buffer_number, 'modified')
    local is_closing = buffer_data.closing

    local status = HL_BY_ACTIVITY[activity]
    local mod = is_modified and 'Mod' or ''

    local separatorPrefix = hl('Buffer' .. status .. 'Sign')
    local separator = status == 'Inactive' and
      icons.bufferline_separator_inactive or
      icons.bufferline_separator_active

    local namePrefix = hl('Buffer' .. status .. mod)
    local name =
      (not has_icons and state.is_picking_buffer) and
        slice(buffer_name, 1) or
        buffer_name

    local iconPrefix = ''
    local icon = ''
    local number = ''
    if state.is_picking_buffer then
      local letter = JumpMode.get_letter(buffer_number)
      iconPrefix = hl('Buffer' .. status .. 'Target')
      icon =
        (letter ~= nil and letter or ' ') ..
        (has_icons and ' ' or '')
    else
      if has_numbers then
        local number_text = tostring(i)
        iconPrefix = ''
        number = number_text .. (#number_text > 1 and '' or ' ')
        -- number = number_text
        print("number: " .. number .. ".")
      end
      if has_icons then
        local iconChar, iconHl = get_icon(buffer_name, vim.fn.getbufvar(buffer_number, '&filetype'), status)
        iconPrefix = hl(status ~= 'Inactive' and iconHl or 'BufferInactive')
        icon = iconChar .. ' '
        print("icon: " .. icon .. ".")
      end
    end
    print("icon prefix: " .. iconPrefix .. ".");

    local closePrefix = ''
    local close = ''
    if has_close then
      local icon =
        (not is_modified and
          icons.bufferline_close_tab or
          icons.bufferline_close_tab_modified)

      closePrefix = namePrefix
      close = icon .. ' '

      if click_enabled then
        closePrefix =
            '%' .. buffer_number .. '@BufferlineCloseClickHandler@' .. closePrefix
      end
    end

    print("close prefix: " .. closePrefix .. ".")

    local clickable = ''
    if click_enabled then
      clickable = '%' .. buffer_number .. '@BufferlineMainClickHandler@'
    end

    local padding = string.rep(' ', layout.padding_width)

    local width =
      buffer_data.width ~= nil and
        buffer_data.width or
        (layout.base_widths[i] + 2 * layout.padding_width)

    local item = {
      width = width,
      groups = {
        { clickable,       ''},
        { separatorPrefix, separator},
        { '',              padding},
        { '',              number},
        { iconPrefix,      icon},
        { namePrefix,      name},
        { '',              padding},
        { '',              ' '},
        { closePrefix,     close},
      }
    }

    if is_current then
      state.index = i
      local start = accumulated_width
      local end_  = accumulated_width + item.width

      if state.scroll > start then
        state.set_scroll(start)
      elseif state.scroll + layout.buffers_width < end_ then
        state.set_scroll(state.scroll + (end_ - (state.scroll + layout.buffers_width)))
      end
    end

    table.insert(items, item)
    accumulated_width = accumulated_width + item.width
  end

  -- Create actual tabline string
  local result = ''

  local max_scroll = math.max(layout.used_width - layout.buffers_width, 0)
  local scroll = math.min(state.scroll_current, max_scroll)
  local accumulated_width = 0
  local needed_width = scroll

  for i, item in ipairs(items) do
    if needed_width > 0 then
      needed_width = needed_width - item.width
      if needed_width < 0 then
        local diff = -needed_width
        result = result .. slice_groups_left(item.groups, diff)
        accumulated_width = accumulated_width + diff
      end
    else
      if accumulated_width + item.width > layout.buffers_width then
        local diff = layout.buffers_width - accumulated_width
        result = result .. slice_groups_right(item.groups, diff)
        accumulated_width = accumulated_width + diff
        break
      end
      result = result .. slice_groups_right(item.groups, item.width)
      accumulated_width = accumulated_width + item.width
    end
  end

  -- To prevent the expansion of the last click group
  result = result .. '%0@BufferlineMainClickHandler@'

  if layout.actual_width + 1 <= layout.buffers_width and len(items) > 0 then
    result = result .. hl('BufferTabpageFill') .. icons.bufferline_separator_inactive
  end

  local current_tabpage = vim.fn.tabpagenr()
  local total_tabpages  = vim.fn.tabpagenr('$')
  if layout.tabpages_width > 0 then
    result = result .. '%=%#BufferTabpages# ' .. tostring(current_tabpage) .. '/' .. tostring(total_tabpages) .. ' '
  end

  -- vim.g.layout = {
  --   scroll = state.scroll,
  --   max_scroll = max_scroll,
  --   layout = layout,
  --   needed_width = needed_width,
  --   accumulated_width = accumulated_width,
  -- }

  result = result .. hl('TabLineFill')
  print("render result: " .. result .. ".")
  return result
end

local function render_safe(update_names)
  local ok, result = pcall(render, update_names)
  return {ok, tostring(result)}
end

-- print(render(state.buffers))

local exports = {
  render = render,
  render_safe = render_safe,
}

return exports
