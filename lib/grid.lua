-- grid.lua
-- v7.2.0 - ncoco-style hold-based patching + LFO buttons + knob highlights
--
-- Layout:
--   Row 1: Snapshots 1-16
--   Rows 2-7: Audrey-II knob layout
--   Row 8, Col 1: SHIFT
--   Row 8, Col 3-6: LFO 1-4
--
-- Patching (ncoco-style hold):
--   Hold LFO + tap knob → connect/disconnect
--   Hold knob + tap LFO → same (bidirectional)
--   Overlay stays visible while source is held
--   SHIFT + hold LFO + tap knob → remove that assignment
--   SHIFT + tap LFO → remove ALL assignments

local Grid = {}
local grid_dev = grid.connect()

Grid.connected = false

-- ============================================
-- KNOB LAYOUT
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
-- LFO BUTTONS
-- ============================================
Grid.lfo_cols = {3, 4, 5, 6}

-- ============================================
-- SNAPSHOT STATE
-- ============================================
Grid.snapshot_press_time = {}
Grid.snapshot_delete_warned = {}

-- ============================================
-- SHIFT & ACTIVE KNOB
-- ============================================
Grid.shift_down = false
Grid.active_knob = nil
Grid.saved_page = 0

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
  
  -- ROW 8, COL 1: SHIFT
  if x == 1 and y == 8 then
    Grid.shift_down = (z == 1)
    _G.g.grid_shift_down = (z == 1)
    _G.g.key1_down = _G.g.key1_down or (z == 1)
    Grid.redraw()
    return
  end
  
  local LFOs = require("audrey/lib/lfos")
  
  -- ROW 8, LFO BUTTONS (cols 3-6)
  if y == 8 then
    for i, col in ipairs(Grid.lfo_cols) do
      if x == col then
        if z == 1 then
          -- Check if a knob is held (bidirectional: knob → LFO patching)
          if Grid.active_knob then
            local knob_param = Grid.active_knob.param_id
            if Grid.shift_down or _G.g.key1_down then
              LFOs.remove_assignment(i, knob_param)
            else
              LFOs.toggle_assignment(i, knob_param)
            end
            _G.g.screen_dirty = true
          elseif Grid.shift_down or _G.g.key1_down then
            -- SHIFT + tap → clear ALL
            LFOs.clear_assignments(i)
          else
            -- Save current page, navigate to LFO page + enter patch mode
            Grid.saved_page = _G.g.current_page
            _G.g.current_page = 5 + i
            LFOs.set_patch_mode(i, true)
            _G.g.screen_dirty = true
          end
        elseif z == 0 then
          -- Release: restore page, exit patch mode, clear overlay
          if Grid.saved_page > 0 then
            _G.g.current_page = Grid.saved_page
            Grid.saved_page = 0
          end
          LFOs.set_patch_mode(i, false)
          if LFOs.overlay then
            LFOs.overlay = nil
            _G.g.screen_dirty = true
          end
        end
        Grid.redraw()
        return
      end
    end
  end
  
  -- KNOB AREA (rows 2-7)
  local param_id = find_knob(x, y)
  if param_id then
    if z == 1 then
      -- Check if any LFO is in patch mode (patching from LFO to knob)
      local active_lfo = nil
      for i = 1, 4 do
        if LFOs.data[i] and LFOs.data[i].patch_mode then
          active_lfo = i
          break
        end
      end
      
      if active_lfo then
        -- Patching: LFO → knob
        if Grid.shift_down or _G.g.key1_down then
          LFOs.remove_assignment(active_lfo, param_id)
        else
          LFOs.toggle_assignment(active_lfo, param_id)
        end
        _G.g.screen_dirty = true
        Grid.redraw()
        return
      end
      
      -- Normal knob press
      Grid.active_knob = {col = x, row = y, param_id = param_id}
      local UI = require("audrey/lib/ui")
      UI.activate_knob(param_id)
      _G.g.screen_dirty = true
      
    elseif z == 0 then
      -- Knob release
      if Grid.active_knob and Grid.active_knob.param_id == param_id then
        Grid.active_knob = nil
        local UI = require("audrey/lib/ui")
        UI.deactivate_knob()
        _G.g.screen_dirty = true
      end
      
      -- If this knob had a patching connection, clear overlay on release
      if LFOs.overlay then
        for i = 1, 4 do
          if LFOs.data[i] and LFOs.data[i].patch_mode then
            -- An LFO is still held, don't clear overlay
            goto keep_overlay
          end
        end
        -- No LFO held anymore → clear
        LFOs.overlay = nil
        _G.g.screen_dirty = true
        ::keep_overlay::
      end
    end
    
    Grid.redraw()
    return
  end
  
  -- Any other release clears active knob
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
-- ENCODER DELTA
-- ============================================
function Grid.encoder_delta(delta)
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
  
  -- Detect which LFOs are held (patch_mode)
  local lfo_held = nil
  for i = 1, 4 do
    if LFOs.data[i] and LFOs.data[i].patch_mode then
      lfo_held = i
      break
    end
  end
  
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
        if phase < 0.5 then brightness = 11 else brightness = 0 end
      end
    end
    grid_dev:led(i, 1, util.clamp(math.floor(brightness), 0, 15))
  end
  
  -- Row 8, Col 1: SHIFT
  local shift_brightness = (Grid.shift_down or _G.g.key1_down) and 14 or 1
  grid_dev:led(1, 8, util.clamp(math.floor(shift_brightness), 0, 15))
  
  -- Row 8, LFO buttons (cols 3-6)
  local knob_held = (Grid.active_knob ~= nil)
  for i, col in ipairs(Grid.lfo_cols) do
    local brightness = 2
    if LFOs.data[i] then
      local lfo = LFOs.data[i]
      if lfo.patch_mode then
        brightness = 14  -- held
      elseif knob_held and Grid.active_knob then
        -- Knob held: highlight LFOs connected to this param
        local connected = LFOs.get_connected_lfos(Grid.active_knob.param_id)
        if connected[i] then
          brightness = 15
        elseif lfo.enabled then
          local val = lfo.value
          brightness = math.floor(util.linlin(-1, 1, 2, 12, val))
        end
      elseif lfo.enabled then
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
      -- This knob is held
      if LFOs.has_assignments(param_id) then
        brightness = 15
      else
        brightness = 14
      end
    elseif lfo_held then
      -- An LFO is held: highlight only its connected knobs
      local lfo = LFOs.data[lfo_held]
      local is_connected = false
      for _, a in ipairs(lfo.assignments) do
        if a[1] == param_id then
          is_connected = true
          break
        end
      end
      if is_connected then
        brightness = 15
      else
        brightness = 5  -- stay normal (not connected)
      end
    end
    
    grid_dev:led(col, row, util.clamp(math.floor(brightness), 0, 15))
  end
  
  grid_dev:refresh()
end

-- ============================================
-- HOLD CHECK
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