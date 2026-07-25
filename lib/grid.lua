-- grid.lua
-- v7.0.0 - Redesigned grid: snapshots + shift + knob layout (Audrey-II original)
--
-- Layout:
--   Row 1: Snapshots 1-16 (load/save/delete with gestures)
--   Rows 2-7: Audrey-II knob layout (hold + K2/K3 to adjust)
--   Row 8, Col 1: SHIFT button (momentary, same as K1)
--   All other cells: unused (brightness 0)
--
-- Knob mapping (col, row):
--   FREQ (2,6)  FBGN (4,4)  BODY (8,7)  LPF (6,6)   HPF (10,6)
--   DW   (8,3)  VDEC (8,5)  ESND (13,5) ETIM (13,7) EFB (12,6)
--   OUT  (13,3)

local Grid = {}
local grid_dev = grid.connect()

Grid.connected = false

-- ============================================
-- KNOB LAYOUT (11 params in Audrey-II positions)
-- ============================================
-- Each entry: {col, row, param_id}
Grid.knob_map = {
  {2, 6, "frequency"},
  {4, 4, "feedback_gain"},
  {8, 7, "feedback_body_delay"},
  {6, 6, "lpf_cutoff"},
  {10, 6, "hpf_cutoff"},
  {8, 3, "reverb_mix"},
  {8, 5, "reverb_decay"},
  {13, 5, "echo_send"},
  {13, 7, "echo_time"},
  {12, 6, "echo_feedback"},
  {13, 3, "master_level"},
}

-- ============================================
-- SNAPSHOT GESTURE TRACKING
-- ============================================
Grid.snapshot_press_time = {}   -- {slot = clock_beats}
Grid.snapshot_delete_warned = {}  -- {slot = bool}

-- ============================================
-- SHIFT STATE
-- ============================================
Grid.shift_down = false

-- ============================================
-- ACTIVE KNOB (for encoder adjustment)
-- ============================================
Grid.active_knob = nil  -- {col, row, param_id} or nil

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
      -- Press: start tracking hold time
      Grid.snapshot_press_time[x] = clock.get_beats()
      Grid.snapshot_delete_warned[x] = false
    elseif z == 0 then
      -- Release: check if tap or hold
      local press_time = Grid.snapshot_press_time[x]
      local elapsed = press_time and (clock.get_beats() - press_time) or 0
      Grid.snapshot_press_time[x] = nil
      Grid.snapshot_delete_warned[x] = nil
      
      if elapsed < 2.0 then
        -- TAP: load if occupied, save if empty
        local info = Grid.get_snapshot_info(x)
        if info.exists then
          if Grid.shift_down or _G.g.key1_down then
            -- SHIFT + tap = SAVE (overwrite)
            Grid.save_snapshot(x)
          else
            -- Normal tap = LOAD
            Grid.load_snapshot(x)
          end
        else
          -- Empty slot = SAVE
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
    -- Also sync with key1 state
    _G.g.key1_down = _G.g.key1_down or (z == 1)
    Grid.redraw()
    return
  end
  
  -- KNOB AREA (rows 2-7)
  local param_id = find_knob(x, y)
  if param_id then
    if z == 1 then
      -- Press: activate knob, show overlay
      Grid.active_knob = {col = x, row = y, param_id = param_id}
      local UI = require("audrey/lib/ui")
      UI.activate_knob(param_id)
      _G.g.screen_dirty = true
    elseif z == 0 then
      -- Release: deactivate knob
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
  if Grid.active_knob then
    local param_id = Grid.active_knob.param_id
    if param_id and params:lookup_param(param_id) then
      params:delta(param_id, delta)
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
  
  -- Row 1: Snapshots
  for i = 1, 16 do
    local info = Snapshots.get_slot_info(i)
    local brightness = 1  -- default: empty
    if info.exists then
      brightness = 3  -- occupied
      if Snapshots.current_slot == i then
        brightness = 11  -- current
      end
    end
    -- Check for delete warning flash
    if Grid.snapshot_press_time[i] and info.exists then
      local elapsed = clock.get_beats() - Grid.snapshot_press_time[i]
      if elapsed > 1.5 then
        -- Flash during last 0.5s before delete
        local phase = (elapsed * 4) % 1  -- 4 Hz flash
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
  
  -- Knobs (rows 2-7)
  for _, knob in ipairs(Grid.knob_map) do
    local col, row, param_id = knob[1], knob[2], knob[3]
    local brightness = 5  -- default: visible
    if Grid.active_knob and Grid.active_knob.col == col and Grid.active_knob.row == row then
      brightness = 14  -- pressed
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
        -- Delete!
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