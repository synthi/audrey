-- grid.lua
-- v5.0.0 - Grid 128 (16x8) control with bidirectional sync
-- 2024-12-20
--
-- Changelog v5.0.0:
-- - Unified version numbering
-- - Layout: Row 1 presets, Row 2 pages, Row 3-6 main params, Row 7-8 quick access
-- - Quick access: 11 original hardware controls + 5 important extras
-- - Bidirectional sync with norns pages
-- - Overlay trigger on param adjustment

local Grid = {}
local grid_dev = grid.connect()

Grid.connected = false
Grid.param_select = 1

local function has_param(id)
  return (id ~= nil) and (params.lookup[id] ~= nil)
end

Grid.quick_access_params = {
  "frequency", "feedback_gain", "feedback_body_delay",
  "hpf_cutoff", "lpf_cutoff", "reverb_mix", "reverb_decay",
  "delay_send", "delay_time", "delay_feedback", "master_level",
  "overdrive", "brightness", "damping", "tape_saturation", "tape_age"
}

function Grid.init()
  if grid_dev and grid_dev.device then
    Grid.connected = true
    grid_dev.key = Grid.key_handler
    print("Grid connected: " .. grid_dev.rows .. "x" .. grid_dev.cols)
  else
    Grid.connected = false
    print("No grid detected")
  end
end

function Grid.sync_page(page_num)
  Grid.current_synced_page = page_num
  if Grid.connected then
    Grid.redraw()
  end
end

function Grid.key_handler(x, y, z)
  if z == 1 then
    if y == 1 and x <= 16 then
      Grid.handle_preset(x)
    
    elseif y == 2 and x <= 9 then
      _G.g.current_page = x
      _G.g.param_focus = 1
      _G.g.screen_dirty = true
      Grid.sync_page(x)
    
    elseif y == 3 then
      Grid.param_select = x
      _G.g.screen_dirty = true
    
    elseif y >= 4 and y <= 6 then
      Grid.adjust_main_param(x, y)
    
    elseif y == 7 then
      local param_id = Grid.quick_access_params[x]
      if has_param(param_id) then
        Grid.adjust_quick_param(param_id, 0.05)
      end
    
    elseif y == 8 then
      local param_id = Grid.quick_access_params[x]
      if has_param(param_id) then
        Grid.cycle_quick_param(param_id)
      end
    end
  end
  
  Grid.redraw()
end

function Grid.handle_preset(slot)
  if slot < 1 or slot > 16 then return end
  local Presets = require("audrey/lib/presets")
  Presets.load(slot)
  _G.g.screen_dirty = true
end

function Grid.adjust_main_param(x, y)
  local Pages = require("audrey/lib/pages")
  local page = Pages.page_list[_G.g.current_page]
  
  if x > #page.params then return end
  local param_id = page.params[x]
  if not has_param(param_id) then return end
  
  local delta = 0
  if y == 4 then delta = 0.05
  elseif y == 5 then delta = 0.01
  elseif y == 6 then delta = -0.05 end
  
  params:delta(param_id, delta)
  
  local UI = require("audrey/lib/ui")
  UI.show_param_overlay(param_id)
  
  _G.g.screen_dirty = true
end

function Grid.adjust_quick_param(param_id, delta)
  if not has_param(param_id) then return end
  params:delta(param_id, delta)
  
  local UI = require("audrey/lib/ui")
  UI.show_param_overlay(param_id)
  
  _G.g.screen_dirty = true
end

function Grid.cycle_quick_param(param_id)
  if not has_param(param_id) then return end
  
  local current = params:get(param_id)
  local param = params:lookup_param(param_id)
  local range = param.controlspec.maxval - param.controlspec.minval
  local new_val = current + (range * 0.1)
  
  if new_val > param.controlspec.maxval then
    new_val = param.controlspec.minval
  end
  
  params:set(param_id, new_val)
  
  local UI = require("audrey/lib/ui")
  UI.show_param_overlay(param_id)
  
  _G.g.screen_dirty = true
end

function Grid.get_current_main_params()
  local Pages = require("audrey/lib/pages")
  local page = Pages.page_list[_G.g.current_page]
  local params_list = {}
  
  for i = 1, math.min(16, #page.params) do
    params_list[i] = page.params[i]
  end
  
  return params_list
end

function Grid.redraw()
  if not Grid.connected then return end
  
  grid_dev:all(0)
  local Presets = require("audrey/lib/presets")
  
  for i = 1, 16 do
    local info = Presets.get_slot_info(i)
    local brightness = info.exists and 8 or 2
    if Presets.current_slot == i then brightness = 15 end
    grid_dev:led(i, 1, util.clamp(math.floor(brightness), 0, 15))
  end
  
  for x = 1, 9 do
    local brightness = (x == _G.g.current_page) and 15 or 4
    grid_dev:led(x, 2, brightness)
  end
  
  local main_params = Grid.get_current_main_params()
  for x = 1, #main_params do
    local id = main_params[x]
    if has_param(id) then
      local val = params:get(id)
      local p = params:lookup_param(id)
      local norm = (val - p.controlspec.minval) / (p.controlspec.maxval - p.controlspec.minval)
      
      local b4, b5, b6 = 4, 8, 15
      if norm > 0.66 then b4, b5, b6 = 15, 15, 15
      elseif norm > 0.33 then b4, b5, b6 = 8, 15, 15 end
      
      grid_dev:led(x, 3, (x == Grid.param_select) and 15 or 4)
      grid_dev:led(x, 4, b4)
      grid_dev:led(x, 5, b5)
      grid_dev:led(x, 6, b6)
    end
  end
  
  for x = 1, 16 do
    local id = Grid.quick_access_params[x]
    if has_param(id) then
      local val = params:get(id)
      local p = params:lookup_param(id)
      local norm = (val - p.controlspec.minval) / (p.controlspec.maxval - p.controlspec.minval)
      local brightness = util.clamp(math.floor(norm * 15 + 0.5), 0, 15)
      grid_dev:led(x, 7, 4)
      grid_dev:led(x, 8, brightness)
    end
  end
  
  grid_dev:refresh()
end

function Grid.cleanup()
  if Grid.connected then
    grid_dev:all(0)
    grid_dev:refresh()
  end
end

return Grid