-- audrey
-- v7.1.0 - Encoder acceleration + high-res linear params
-- 2026-07-24
--
-- Changelog v7.1.0:
-- - All params switched from "exp" to "lin" with fine steps (encoder-native)
-- - Encoder acceleration: cubic for frequency (cents), quadratic for others
-- - Slow turns = surgical precision, fast turns = quick sweeps
-- - feedback_gain default changed from -60 to 0.8 dB
-- - Fixed pages.lua crash (orphan 'end' + variable name mismatch)
--
-- Changelog v7.0.0:
-- - Grid completely redesigned: snapshots (row 1), knobs (rows 2-7), SHIFT button (row 8)
-- - Snapshots system replaces Presets (load/save/delete with gestures)
-- - SHIFT button on grid synced with K1
-- - Knobs: hold + K2/K3 to adjust parameter, overlay on press
-- - Engine faithfully matches C++ original (11 params, reverb in loop, audio input L+R)
-- - All parameter ranges verified against C++ FeedbackSynthControls

engine.name = "Audrey"

local UI = require("audrey/lib/ui")
local Params = require("audrey/lib/params")
local Pages = require("audrey/lib/pages")
local Snapshots = require("audrey/lib/snapshots")
local Grid = require("audrey/lib/grid")

g = {
  screen_dirty = true,
  screen_refresh_rate = 15,
  current_page = 1,
  param_focus = 1,
  preset_focus = 1,
  encoders_enabled = true,
  key1_down = false,
  grid_shift_down = false
}

function init()
  Params.init_params()
  Pages.init()
  Snapshots.init()
  Grid.init()
  
  screen_timer = metro.init()
  screen_timer.time = 1 / g.screen_refresh_rate
  screen_timer.event = function()
    if g.screen_dirty then
      redraw()
      g.screen_dirty = false
    end
    if Grid.connected then Grid.check_holds() end
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
  
  print("audrey v7.0.0 initialized")
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
      g.screen_dirty = true
      
    elseif n == 3 then
      local page = Pages.page_list[g.current_page]
      
      if page.name == "SNAPSHOTS" then
        if g.key1_down then
          local name = "Snapshot " .. g.preset_focus
          Snapshots.save(g.preset_focus, name)
          print("Saved to slot " .. g.preset_focus)
        else
          Snapshots.load(g.preset_focus)
        end
      else
        Pages.next_page()
      end
      
      g.screen_dirty = true
    end
  end
end

-- ============================================
-- ENCODER ACCELERATION FUNCTIONS (global, used by pages/grid too)
-- ============================================

-- Logarithmic params (freq, lpf, hpf): cents-based, same feel across entire range
-- delta=1→1.5¢, delta=6→~1035¢ (~10 semitones)
function step_cents(param_id, delta)
  local p = params:lookup_param(param_id)
  if not p then return end
  local current = p:get()
  local sign = (delta > 0) and 1 or -1
  local cents = (math.abs(delta) ^ 3.5) * 1.5
  local ratio = 2 ^ (sign * cents / 1200)
  params:set(param_id, util.clamp(current * ratio, p.controlspec.minval, p.controlspec.maxval))
end

-- Linear params (gain, body, mix, decay, echo, level): step * acceleration
-- delta=1→1 step, delta=6→88 steps (^2.5)
function step_accel(param_id, delta)
  local p = params:lookup_param(param_id)
  if not p then return end
  local sign = (delta > 0) and 1 or -1
  local steps = math.abs(delta) ^ 2.5
  params:set(param_id, util.clamp(p:get() + sign * steps * p.controlspec.step, p.controlspec.minval, p.controlspec.maxval))
end

-- ============================================
-- CONTROLS
-- ============================================

function enc(n, delta)
  if not g.encoders_enabled then return end
  
  -- If a grid knob is active, encoders control that param
  if Grid.connected and Grid.active_knob then
    Grid.encoder_delta(delta)
    g.screen_dirty = true
    return
  end
  
  if n == 1 then
    step_accel("feedback_gain", delta)
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