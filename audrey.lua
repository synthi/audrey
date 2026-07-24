-- audrey
-- v5.0.0 - Faithful port of Audrey-II (Daisy Seed) for norns
-- 2024-12-20
--
-- Changelog v5.0.0:
-- - Unified version numbering across all files
-- - Bidirectional norns ↔ grid sync
-- - Overlay system for grid feedback
-- - All signal flow matching C++ original
-- - ReverbSc clone, damping filter working

engine.name = "Audrey"

local UI = require("audrey/lib/ui")
local Params = require("audrey/lib/params")
local Pages = require("audrey/lib/pages")
local Presets = require("audrey/lib/presets")
local Grid = require("audrey/lib/grid")

g = {
  screen_dirty = true,
  screen_refresh_rate = 15,
  current_page = 1,
  param_focus = 1,
  preset_focus = 1,
  encoders_enabled = true,
  key1_down = false
}

function init()
  Params.init_params()
  Pages.init()
  Presets.init()
  Grid.init()
  
  screen_timer = metro.init()
  screen_timer.time = 1 / g.screen_refresh_rate
  screen_timer.event = function()
    if g.screen_dirty then
      redraw()
      g.screen_dirty = false
    end
  end
  screen_timer:start()
  
  if Grid.connected then
    grid_timer = metro.init()
    grid_timer.time = 1 / 30
    grid_timer.event = function()
      Grid.redraw()
    end
    grid_timer:start()
  end
  
  print("audrey v5.0.0 initialized")
  print("faithful port of Audrey-II")
end

function cleanup()
  screen_timer:stop()
  if grid_timer then
    grid_timer:stop()
  end
  Grid.cleanup()
end

function key(n, z)
  if n == 1 then
    g.key1_down = (z == 1)
  end
  
  if z == 1 then
    if n == 2 then
      Pages.prev_page()
      if Grid.connected then
        Grid.sync_page(g.current_page)
      end
      g.screen_dirty = true
      
    elseif n == 3 then
      local page = Pages.page_list[g.current_page]
      
      if page.name == "PRESETS" then
        if g.key1_down then
          local name = "Preset " .. g.preset_focus
          Presets.save(g.preset_focus, name)
          print("Saved to slot " .. g.preset_focus)
        else
          Presets.load(g.preset_focus)
        end
      else
        Pages.next_page()
        if Grid.connected then
          Grid.sync_page(g.current_page)
        end
      end
      
      g.screen_dirty = true
    end
  end
end

function enc(n, delta)
  if not g.encoders_enabled then return end
  
  if n == 1 then
    params:delta("feedback_gain", delta)
  elseif n == 2 then
    Pages.change_param_focus(delta)
  elseif n == 3 then
    Pages.adjust_focused_param(delta)
  end
  
  g.screen_dirty = true
end

function redraw()
  screen.clear()
  UI.draw_header()
  Pages.draw_current()
  
  if Grid.connected then
    UI.draw_overlay()
  end
  
  screen.update()
end