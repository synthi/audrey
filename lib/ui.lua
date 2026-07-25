-- ui.lua
-- v7.4.0 - ncoco-style LFO overlay (signed depth, no modes), decimal percentage
-- 2026-07-25

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

-- LFO overlay: ncoco-style signed depth (-1..+1), continuous bar centered at 0
-- Bar is STATIC (shows depth setting, not modulated by LFO)
function UI.draw_lfo_overlay()
  local LFOs = require("audrey/lib/lfos")
  local o = LFOs.overlay
  if not o then return end
  
  local param = params:lookup_param(o.param_id)
  if not param then return end
  
  -- Signed depth value (already -1..+1)
  local signed_val = util.clamp(o.depth, -1, 1)
  
  -- Background (matching ncoco: 10,10,108,50)
  screen.level(0)
  screen.rect(10, 10, 108, 50)
  screen.fill()
  screen.level(15)
  screen.rect(10, 10, 108, 50)
  screen.stroke()
  
  -- Title
  screen.move(64, 25)
  screen.text_center("PATCHING...")
  screen.move(64, 35)
  screen.text_center("LFO " .. o.lfo_id .. " > " .. param.name)
  
  -- Bar with 0 at center (matching ncoco)
  screen.level(2)
  screen.move(64, 40)
  screen.line_rel(40, 0)
  screen.move(64, 40)
  screen.line_rel(-40, 0)
  screen.stroke()
  screen.level(15)
  screen.move(64, 40)
  screen.line_rel(signed_val * 40, 0)
  screen.stroke()
  screen.circle(64 + signed_val * 40, 40, 2)
  screen.fill()
  
  -- Value percentage (top-right) — decimal resolution
  screen.level(15)
  screen.move(115, 20)
  screen.text_right(string.format("%.1f%%", signed_val * 100))
  
  -- Controls hint
  screen.level(4)
  screen.move(14, 55)
  screen.text("E2/E3:dpt  K2/K3:±")
end

return UI