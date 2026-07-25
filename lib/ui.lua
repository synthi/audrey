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
  
  local LFOs = require("audrey/lib/lfos")
  local param = params:lookup_param(UI.overlay_param)
  if not param then return end
  
  local has_lfo = LFOs.has_assignments(UI.overlay_param)
  local base_val = LFOs.get_base_value(UI.overlay_param)
  local mod = LFOs.get_modulation(UI.overlay_param)
  
  -- Popup background (larger: 120x50, y=10-60)
  screen.level(0)
  screen.rect(4, 10, 120, 50)
  screen.fill()
  screen.level(15)
  screen.rect(4, 10, 120, 50)
  screen.stroke()
  
  -- Param name (top)
  screen.level(15)
  screen.move(64, 20)
  local name = param.name
  if #name > 18 then name = string.sub(name, 1, 15) .. "..." end
  screen.text_center(name)
  
  -- Base value (fixed, changes only with encoder)
  screen.move(64, 30)
  screen.text_center(string.format("%.3f", base_val))
  
  -- Bar 1: param value (0-100%, left to right)
  local norm = (base_val - param.controlspec.minval) /
               (param.controlspec.maxval - param.controlspec.minval)
  norm = util.clamp(norm, 0, 1)
  screen.level(8)
  screen.rect(10, 34, 108 * norm, 2)
  screen.fill()
  
  if has_lfo then
    -- Bar 2: LFO modulation (signed, centered at 0)
    local pct = util.clamp(mod.pct, -1, 1)
    local bar_center_x = 64
    local bar_y = 42
    local bar_half_width = 54
    
    -- Center line
    screen.level(3)
    screen.move(bar_center_x, bar_y)
    screen.line_rel(bar_half_width, 0)
    screen.move(bar_center_x, bar_y)
    screen.line_rel(-bar_half_width, 0)
    screen.stroke()
    
    -- Modulation bar
    screen.level(15)
    screen.move(bar_center_x, bar_y)
    screen.line_rel(pct * bar_half_width, 0)
    screen.stroke()
    screen.circle(bar_center_x + pct * bar_half_width, bar_y, 2)
    screen.fill()
    
    -- LFO labels + percentage
    screen.level(4)
    screen.move(10, 52)
    local lfo_str = ""
    for _, id in ipairs(mod.lfos) do
      if lfo_str ~= "" then lfo_str = lfo_str .. "+" end
      lfo_str = lfo_str .. "LFO" .. id
    end
    screen.text(lfo_str)
    screen.move(118, 52)
    screen.text_right(string.format("%+.1f%%", pct * 100))
  end
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