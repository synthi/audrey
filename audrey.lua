-- audrey
-- v7.2.0 - 4 LFOs + page indicators + encoder polish
-- 2026-07-24
--
-- Changelog v7.2.0:
-- - 4 LFOs (tri/Perlin) assignable to any param via grid patching
-- - Self-correcting offset: moving a param manually doesn't break LFO modulation
-- - Page indicators (10 dots) at bottom of screen
-- - Frequency range lowered to C0 (MIDI 12)
-- - Master level default 0.5, feedback gain default -24 dB
-- - Smooth LFO output (60 Hz metro, no stepping)
-- - LFO pages (7-10) with scrollable assignment list
--
-- Changelog v7.1.0:
-- - All params switched from "exp" to "lin" with fine steps (encoder-native)
-- - Encoder acceleration with params:set() instead of params:delta()
-- - step_cents() for freq/lpf/hpf, step_accel() for linear params
-- - Fixed pages.lua crash (orphan 'end' + variable name mismatch)
--
-- Changelog v7.0.0:
-- - Grid completely redesigned: snapshots (row 1), knobs (rows 2-7), SHIFT button (row 8)
-- - Engine faithfully matches C++ original (11 params, reverb in loop, audio input L+R)

engine.name = "Audrey"

local UI = require("audrey/lib/ui")
local Params = require("audrey/lib/params")
local Pages = require("audrey/lib/pages")
local Snapshots = require("audrey/lib/snapshots")
local Grid = require("audrey/lib/grid")
local LFOs = require("audrey/lib/lfos")

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
  LFOs.init()
  
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
  
  print("audrey v7.2.0 initialized")
end

function cleanup()
  screen_timer:stop()
  if grid_timer then
    grid_timer:stop()
  end
  Grid.cleanup()
  LFOs.cleanup()
end

function key(n, z)
  if n == 1 then
    g.key1_down = (z == 1)
  end
  
  local page = Pages.page_list[g.current_page]
  
  -- LFO page key handling (when no grid knob is active)
  if page.lfo_id and not (Grid.connected and Grid.active_knob) then
    if z == 1 then
      local LFOs = require("audrey/lib/lfos")
      local lfo = LFOs.data[page.lfo_id]
      if not lfo then return end
      
      if n == 1 then
        -- K1: delete focused assignment
        local cursor = Pages.lfo_cursor[page.lfo_id]
        if lfo.assignments[cursor] then
          table.remove(lfo.assignments, cursor)
          Pages.lfo_cursor[page.lfo_id] = util.clamp(cursor, 1, math.max(1, #lfo.assignments))
          g.screen_dirty = true
        end
        
      elseif n == 2 then
        -- K2: toggle waveform
        lfo.wave = (lfo.wave == LFOs.WAVE_TRI) and LFOs.WAVE_PERLIN or LFOs.WAVE_TRI
        lfo.phase = 0
        lfo.perlin_noise = {
          x = math.random() * 1000,
          y = math.random() * 1000,
          z = math.random() * 1000,
        }
        g.screen_dirty = true
        
      elseif n == 3 then
        -- K3: toggle enabled
        lfo.enabled = not lfo.enabled
        g.screen_dirty = true
      end
    end
    return
  end
  
  if z == 1 then
    if n == 2 then
      Pages.prev_page()
      g.screen_dirty = true
      
    elseif n == 3 then
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
  
  -- Draw LFO overlay (takes priority over knob overlay when patching)
  if LFOs.overlay then
    UI.draw_lfo_overlay()
  elseif Grid.connected then
    UI.draw_overlay()
  end
  
  screen.update()
end
