-- ui.lua
-- v7.0.0 - UI drawing with overlay system + grid knob support
-- 2026-07-24

local UI = {}

UI.overlay_param = nil
UI.overlay_timer = nil

function UI.draw_header()
  screen.level(15)
  screen.move(0, 6)
  screen.text("AUDREY")
  

  screen.level(4)
  screen.move(0, 10)
  screen.line(128, 10)
  screen.stroke()
end

function UI.show_param_overlay(param_id)
  UI.overlay_param = param_id
  
  if UI.overlay_timer then
    clock.cancel(UI.overlay_timer)
  end
  
  UI.overlay_timer = clock.run(function()
    clock.sleep(2)
    UI.overlay_param = nil
    _G.g.screen_dirty = true
  end)
  
  _G.g.screen_dirty = true
end

-- Called when a grid knob is pressed (momentary overlay, no timeout)
function UI.activate_knob(param_id)
  UI.overlay_param = param_id
  if UI.overlay_timer then
    clock.cancel(UI.overlay_timer)
    UI.overlay_timer = nil
  end
  _G.g.screen_dirty = true
end

-- Called when a grid knob is released (clears overlay after short delay)
function UI.deactivate_knob()
  if UI.overlay_timer then
    clock.cancel(UI.overlay_timer)
  end
  UI.overlay_timer = clock.run(function()
    clock.sleep(0.5)
    UI.overlay_param = nil
    _G.g.screen_dirty = true
  end)
end

function UI.draw_overlay()
  if not UI.overlay_param then return end
  
  local param = params:lookup_param(UI.overlay_param)
  if not param then return end
  
  screen.level(3)
  screen.rect(14, 22, 100, 26)
  screen.fill()
  
  screen.level(15)
  screen.rect(14, 22, 100, 26)
  screen.stroke()
  
  screen.level(15)
  screen.move(64, 32)
  screen.text_center(param.name)
  
  screen.move(64, 42)
  screen.text_center(param:string())
  
  local norm = (params:get(UI.overlay_param) - param.controlspec.minval) /
               (param.controlspec.maxval - param.controlspec.minval)
  screen.level(8)
  screen.rect(18, 44, 92 * norm, 2)
  screen.fill()
end

return UI