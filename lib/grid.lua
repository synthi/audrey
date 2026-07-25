-- grid.lua
-- v7.2.0 - LFO buttons (row 8), patching gestures, knob highlight
--
-- Layout:
--   Row 1: Snapshots 1-16
--   Rows 2-7: Audrey-II knob layout (hold + K2/K3 to adjust)
--   Row 8, Col 1: SHIFT button
--   Row 8, Col 3-6: LFO 1-4 buttons
--   All other cells: off
--
-- LFO gestures:
--   Hold LFO btn + tap knob → connect (or disconnect if exists)
--   SHIFT + hold LFO + tap knob → remove that assignment
--   SHIFT + tap LFO → remove ALL assignments

local Grid = {}
local grid_dev = grid.connect()

Grid.connected = false

-- ============================================
-- KNOB LAYOUT (11 params in Audrey-II positions)
-- ============================================
Grid.knob_map = {
  {2, 6, "frequency"},
  {4, 4, "feedback_gain"},
  {8, 7, "feedback_body_delay"},
  {6, 6, "lpf_cutoff"},
  {10, 6, "hpf_cutoff"},
  {8, 3, "reverb_mix"},
  {8, 5, "reverb_decay"},
  {14, 5, "echo_send"},
  {14, 7, "echo_time"},
  {12, 6, "echo_feedback"},
  {14, 3, "master_level"},
}

-- ============================================
-- LFO BUTTONS (row 8, cols 3-6)
-- ============================================
Grid.lfo_cols = {3, 4, 5, 6}

-- ============================================
-- SNAPSHOT GESTURE TRACKING
-- ============================================
Grid.snapshot_press_time = {}
Grid.snapshot_delete_warned = {}

-- ============================================
-- SHIFT STATE
-- ============================================
Grid.shift_down = false

-- ============================================
-- ACTIVE KNOB (for encoder adjustment)
-- ============================================
Grid.active_knob = nil

-- Helper: find knob at position
local function find_knob(x, y)
  for _, knob in ipairs(Grid.knob_map) do
    if knob[1] == x and knob[2] == y then
      return knob[3]
    end
  end
  return nil
end

-- ============================================
-- INIT
-- ============================================
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

-- ============================================
-- KEY HANDLER
-- ============================================
function Grid.key_handler(x, y, z)
  -- ROW 1: Snapshots
  if y == 1 and x <= 16 then
    if z == 1 then
      Grid.snapshot_press_time[x] = clock.get_beats()
      Grid.snapshot_delete_warned[x] = false
    elseif z == 0 then
      local press_time = Grid.snapshot_press_time[x]
      local elapsed = press_time and (clock.get_beats() - press_time) or 0
      Grid.snapshot_press_time[x] = nil
      Grid.snapshot_delete_warned[x] = nil
      
      if elapsed < 2.0 then
        local info = Grid.get_snapshot_info(x)
        if info.exists then
          if Grid.shift_down or _G.g.key1_down then
            Grid.save_snapshot(x)
          else
            Grid.load_snapshot(x)
          end
        else
          Grid.save_snapshot(x)
        end
      end
    end
    Grid.redraw()
    return
  end
  
  -- ROW 8, COL 1: SHIFT button
  if x == 1 and y == 8 then
    Grid.shift_down = (z == 1)
    _G.g.grid_shift_down = (z == 1)
    _G.g.key1_down = _G.g.key1_down or (z == 1)
    Grid.redraw()
    return
  end
  
  -- ROW 8, LFO BUTTONS (cols 3-6)
  if y == 8 then
    local LFOs = require("audrey/lib/lfos")
    for i, col in ipairs(Grid.lfo_cols) do
      if x == col then
        if z == 1 then
          if Grid.shift_down or _G.g.key1_down then
            -- SHIFT + tap LFO → clear ALL assignments
            LFOs.clear_assignments(i)
          else
            -- Normal press → enter patch mode
            LFOs.start_patch_mode(i)
          end
          Grid.redraw()
        end
        return
      end
    end
  end
  
  -- KNOB AREA (rows 2-7)
  local param_id = find_knob(x, y)
  if param_id then
    local LFOs = require("audrey/lib/lfos")
    
    if z == 1 then
      -- Check if any LFO is in patch mode
      local target_lfo = nil
      for i = 1, 4 do
        if LFOs.data[i] and LFOs.data[i].patch_mode then
          target_lfo = i
          break
        end
      end
      
      if target_lfo then
        -- Patching gesture active
        if Grid.shift_down or _G.g.key1_down then
          LFOs.remove_assignment(target_lfo, param_id)
        else
          LFOs.toggle_assignment(target_lfo, param_id)
        end
        _G.g.screen_dirty = true
        Grid.redraw()
        return
      end
      
      -- Normal knob press: activate with possible LFO highlight
      Grid.active_knob = {col = x, row = y, param_id = param_id}
      local UI = require("audrey/lib/ui")
      UI.activate_knob(param_id)
      _G.g.screen_dirty = true
      
    elseif z == 0 then
      if Grid.active_knob and Grid.active_knob.param_id == param_id then
        Grid.active_knob = nil
        local UI = require("audrey/lib/ui")
        UI.deactivate_knob()
        _G.g.screen_dirty = true
      end
    end
    
    Grid.redraw()
    return
  end
  
  -- Any other button release clears active knob
  if z == 0 and Grid.active_knob then
    Grid.active_knob = nil
    local UI = require("audrey/lib/ui")
    UI.deactivate_knob()
    _G.g.screen_dirty = true
    Grid.redraw()
  end
end

-- ============================================
-- SNAPSHOT HELPERS
-- ============================================
function Grid.get_snapshot_info(slot)
  local Snapshots = require("audrey/lib/snapshots")
  return Snapshots.get_slot_info(slot)
end

function Grid.load_snapshot(slot)
  local Snapshots = require("audrey/lib/snapshots")
  Snapshots.load(slot)
  _G.g.screen_dirty = true
end

function Grid.save_snapshot(slot)
  local Snapshots = require("audrey/lib/snapshots")
  local name = "Snapshot " .. slot
  Snapshots.save(slot, name)
  _G.g.screen_dirty = true
end

function Grid.delete_snapshot(slot)
  local Snapshots = require("audrey/lib/snapshots")
  Snapshots.delete(slot)
  _G.g.screen_dirty = true
end

-- ============================================
-- ENCODER DELTA (called from audrey.lua when K2/K3 move)
-- ============================================
function Grid.encoder_delta(delta)
  -- If LFO overlay is active, adjust depth/mode instead
  local LFOs = require("audrey/lib/lfos")
  if LFOs.overlay then
    LFOs.adjust_overlay(delta, 0)
    _G.g.screen_dirty = true
    return
  end
  
  if Grid.active_knob then
    local param_id = Grid.active_knob.param_id
    if param_id and params:lookup_param(param_id) then
      if param_id == "frequency" or param_id == "lpf_cutoff" or param_id == "hpf_cutoff" then
        step_cents(param_id, delta)
      else
        step_accel(param_id, delta)
      end
    end
    _G.g.screen_dirty = true
  end
end

-- ============================================
-- REDRAW
-- ============================================
function Grid.redraw()
  if not Grid.connected then return end
  grid_dev:all(0)
  local Snapshots = require("audrey/lib/snapshots")
  local LFOs = require("audrey/lib/lfos")
  
  -- Row 1: Snapshots
  for i = 1, 16 do
    local info = Snapshots.get_slot_info(i)
    local brightness = 1
    if info.exists then
      brightness = 3
      if Snapshots.current_slot == i then
        brightness = 11
      end
    end
    if Grid.snapshot_press_time[i] and info.exists then
      local elapsed = clock.get_beats() - Grid.snapshot_press_time[i]
      if elapsed > 1.5 then
        local phase = (elapsed * 4) % 1
        if phase < 0.5 then
          brightness = 11
        else
          brightness = 0
        end
      end
    end
    grid_dev:led(i, 1, util.clamp(math.floor(brightness), 0, 15))
  end
  
  -- Row 8, Col 1: SHIFT
  local shift_brightness = (Grid.shift_down or _G.g.key1_down) and 14 or 1
  grid_dev:led(1, 8, util.clamp(math.floor(shift_brightness), 0, 15))
  
  -- Row 8, LFO buttons (cols 3-6)
  for i, col in ipairs(Grid.lfo_cols) do
    local brightness = 2
    if LFOs.data[i] then
      local lfo = LFOs.data[i]
      if lfo.patch_mode then
        brightness = 14
      elseif lfo.enabled then
        -- Oscillate between 2-12 based on LFO value
        local val = lfo.value
        brightness = math.floor(util.linlin(-1, 1, 2, 12, val))
      end
    end
    grid_dev:led(col, 8, util.clamp(math.floor(brightness), 0, 15))
  end
  
  -- Knobs (rows 2-7)
  for _, knob in ipairs(Grid.knob_map) do
    local col, row, param_id = knob[1], knob[2], knob[3]
    local brightness = 5
    if Grid.active_knob and Grid.active_knob.col == col and Grid.active_knob.row == row then
      -- Highlight brighter (15) if this param has LFO assignments
      if LFOs.has_assignments(param_id) then
        brightness = 15
      else
        brightness = 14
      end
    end
    grid_dev:led(col, row, util.clamp(math.floor(brightness), 0, 15))
  end
  
  grid_dev:refresh()
end

-- ============================================
-- HOLD CHECK (called from redraw timer in audrey.lua)
-- ============================================
function Grid.check_holds()
  for slot = 1, 16 do
    if Grid.snapshot_press_time[slot] then
      local elapsed = clock.get_beats() - Grid.snapshot_press_time[slot]
      if elapsed >= 2.0 then
        local info = Grid.get_snapshot_info(slot)
        if info.exists then
          Grid.delete_snapshot(slot)
        end
        Grid.snapshot_press_time[slot] = nil
        Grid.snapshot_delete_warned[slot] = nil
        Grid.redraw()
      end
    end
  end
end

-- ============================================
-- CLEANUP
-- ============================================
function Grid.cleanup()
  if Grid.connected then
    grid_dev:all(0)
    grid_dev:refresh()
  end
end

return Grid