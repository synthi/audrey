-- grid.lua
-- v7.3.0 - Knobs rows 2-6, HPF↔LPF swapped, snapshots row 8 cols 9-16 (8 slots)
--
-- Layout:
--   Row 1: empty
--   Rows 2-6: Audrey-II knob layout (shifted up 1 row, HPF/LPF swapped)
--   Row 7: empty
--   Row 8: [SH] [---] [L1] [L2] [L3] [L4] [L5] [---] [S1..S8]

local LFOs = require("audrey/lib/lfos")
local UI = require("audrey/lib/ui")
local Snapshots = require("audrey/lib/snapshots")

local Grid = {}
local grid_dev = grid.connect()

Grid.connected = false

Grid.knob_map = {
  {2, 5, "frequency"},
  {4, 3, "feedback_gain"},
  {8, 6, "feedback_body_delay"},
  {6, 5, "hpf_cutoff"},
  {10, 5, "lpf_cutoff"},
  {8, 2, "reverb_mix"},
  {8, 4, "reverb_decay"},
  {14, 4, "echo_send"},
  {14, 6, "echo_time"},
  {12, 5, "echo_feedback"},
  {14, 2, "master_level"},
}

Grid.lfo_cols = {3, 4, 5, 6, 7}
Grid.snapshot_cols = {9, 10, 11, 12, 13, 14, 15, 16}  -- 8 slots
Grid.snapshot_press_time = {}
Grid.snapshot_delete_warned = {}
Grid.shift_down = false
Grid.active_knob = nil
Grid.saved_page = 0
Grid.cache = {}

local function find_knob(x, y)
  for _, knob in ipairs(Grid.knob_map) do
    if knob[1] == x and knob[2] == y then return knob[3] end
  end
  return nil
end

local function snap_index(x)
  for i, col in ipairs(Grid.snapshot_cols) do
    if x == col then return i end
  end
  return nil
end

function Grid.init()
  for x = 1, 16 do
    Grid.cache[x] = {}
    for y = 1, 8 do Grid.cache[x][y] = -1 end
  end
  if grid_dev and grid_dev.device then
    Grid.connected = true
    grid_dev.key = Grid.key_handler
    print("Grid connected: " .. grid_dev.rows .. "x" .. grid_dev.cols)
  else
    Grid.connected = false
    print("No grid detected")
  end
end

function Grid.key_handler(x, y, z)
  -- ROW 8: Snapshots (cols 9-16)
  if y == 8 and x >= 9 and x <= 16 then
    local slot = snap_index(x)
    if not slot then return end
    if z == 1 then
      Grid.snapshot_press_time[slot] = clock.get_beats()
      Grid.snapshot_delete_warned[slot] = false
    elseif z == 0 then
      local press_time = Grid.snapshot_press_time[slot]
      local elapsed = press_time and (clock.get_beats() - press_time) or 0
      Grid.snapshot_press_time[slot] = nil
      Grid.snapshot_delete_warned[slot] = nil
      if elapsed < 2.0 then
        local info = Grid.get_snapshot_info(slot)
        if info.exists then
          if Grid.shift_down then
            Grid.save_snapshot(slot)
          else
            Grid.load_snapshot(slot)
          end
        else
          Grid.save_snapshot(slot)
        end
      end
    end
    Grid.redraw()
    return
  end
  
  -- ROW 8, COL 1: SHIFT (momentary)
  if x == 1 and y == 8 then
    Grid.shift_down = (z == 1)
    _G.g.grid_shift_down = (z == 1)
    Grid.redraw()
    return
  end
  
  -- ROW 8, LFO BUTTONS (cols 3-7)
  if y == 8 and x >= 3 and x <= 7 then
    for i, col in ipairs(Grid.lfo_cols) do
      if x == col then
        if z == 1 then
          if Grid.shift_down and Grid.active_knob then
            LFOs.remove_assignment(i, Grid.active_knob.param_id)
            _G.g.screen_dirty = true
          elseif Grid.active_knob then
            local knob_param = Grid.active_knob.param_id
            if Grid.shift_down then
              LFOs.remove_assignment(i, knob_param)
            else
              LFOs.connect_or_show(i, knob_param)
            end
            _G.g.screen_dirty = true
          elseif Grid.shift_down then
            LFOs.clear_assignments(i)
          else
            Grid.saved_page = _G.g.current_page
            _G.g.current_page = 5 + i  -- LFO pages are 6-10, SNAPSHOTS=11
            LFOs.set_patch_mode(i, true)
            _G.g.screen_dirty = true
          end
        elseif z == 0 then
          if Grid.saved_page > 0 then
            _G.g.current_page = Grid.saved_page
            Grid.saved_page = 0
          end
          LFOs.set_patch_mode(i, false)
          LFOs.overlay = nil
          _G.g.screen_dirty = true
        end
        Grid.redraw()
        return
      end
    end
  end
  
  -- KNOB AREA (rows 2-6)
  local param_id = find_knob(x, y)
  if param_id then
    if z == 1 then
      local active_lfo = nil
      for i = 1, 5 do
        if LFOs.data[i] and LFOs.data[i].patch_mode then
          active_lfo = i
          break
        end
      end
      
      if active_lfo then
        if Grid.shift_down then
          LFOs.remove_assignment(active_lfo, param_id)
        else
          LFOs.connect_or_show(active_lfo, param_id)
        end
        _G.g.screen_dirty = true
        Grid.redraw()
        return
      end
      
      Grid.active_knob = {col = x, row = y, param_id = param_id}
      UI.activate_knob(param_id)
      _G.g.screen_dirty = true
      
    elseif z == 0 then
      if Grid.active_knob and Grid.active_knob.param_id == param_id then
        Grid.active_knob = nil
        UI.deactivate_knob()
        _G.g.screen_dirty = true
      end
      
      if LFOs.overlay then
        for i = 1, 5 do
          if LFOs.data[i] and LFOs.data[i].patch_mode then
            goto keep_overlay
          end
        end
        LFOs.overlay = nil
        _G.g.screen_dirty = true
        ::keep_overlay::
      end
    end
    
    Grid.redraw()
    return
  end
  
  if z == 0 and Grid.active_knob then
    Grid.active_knob = nil
    UI.deactivate_knob()
    _G.g.screen_dirty = true
    Grid.redraw()
  end
end

-- Snapshots
function Grid.get_snapshot_info(slot)
  return Snapshots.get_slot_info(slot)
end

function Grid.load_snapshot(slot)
  Snapshots.load(slot)
  _G.g.screen_dirty = true
end

function Grid.save_snapshot(slot)
  Snapshots.save(slot, "S" .. slot)
  _G.g.screen_dirty = true
end

function Grid.delete_snapshot(slot)
  Snapshots.delete(slot)
  _G.g.screen_dirty = true
end

function Grid.encoder_delta(delta)
  if LFOs.overlay then
    LFOs.adjust_overlay(delta)
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

function Grid.redraw()
  if not Grid.connected then return end
  
  local lfo_held = nil
  for i = 1, 5 do
    if LFOs.data[i] and LFOs.data[i].patch_mode then
      lfo_held = i
      break
    end
  end
  
  -- Row 8: Snapshots (cols 9-16, 8 slots)
  for i, col in ipairs(Grid.snapshot_cols) do
    local info = Snapshots.get_slot_info(i)
    local b = 1
    if info.exists then
      b = 3
      if Snapshots.current_slot == i then b = 11 end
    end
    if Grid.snapshot_press_time[i] and info.exists then
      local elapsed = clock.get_beats() - Grid.snapshot_press_time[i]
      if elapsed > 1.5 then
        local phase = (elapsed * 4) % 1
        if phase < 0.5 then b = 11 else b = 0 end
      end
    end
    if Grid.cache[col] and Grid.cache[col][8] ~= b then
      grid_dev:led(col, 8, util.clamp(math.floor(b), 0, 15))
      Grid.cache[col][8] = b
    end
  end
  
  -- Row 8, Col 1: SHIFT
  local shift_br = Grid.shift_down and 14 or 1
  if Grid.cache[1] and Grid.cache[1][8] ~= shift_br then
    grid_dev:led(1, 8, util.clamp(math.floor(shift_br), 0, 15))
    Grid.cache[1][8] = shift_br
  end
  
  -- Row 8, LFO buttons (cols 3-7)
  local knob_held = (Grid.active_knob ~= nil)
  for i, col in ipairs(Grid.lfo_cols) do
    local b = 2
    if LFOs.data[i] then
      local lfo = LFOs.data[i]
      if lfo.patch_mode then
        b = 14
      elseif knob_held and Grid.active_knob then
        local connected = LFOs.get_connected_lfos(Grid.active_knob.param_id)
        if connected[i] then
          b = 15
        elseif lfo.enabled then
          b = math.floor(util.linlin(-1, 1, 2, 12, lfo.value))
        end
      elseif lfo.enabled then
        b = math.floor(util.linlin(-1, 1, 2, 12, lfo.value))
      end
    end
    if Grid.cache[col] and Grid.cache[col][8] ~= b then
      grid_dev:led(col, 8, util.clamp(math.floor(b), 0, 15))
      Grid.cache[col][8] = b
    end
  end
  
  -- Knobs (rows 2-6)
  for _, knob in ipairs(Grid.knob_map) do
    local col, row, param_id = knob[1], knob[2], knob[3]
    local b = 5
    
    if Grid.active_knob and Grid.active_knob.col == col and Grid.active_knob.row == row then
      if LFOs.has_assignments(param_id) then
        b = 15
      else
        b = 14
      end
    elseif lfo_held then
      local lfo = LFOs.data[lfo_held]
      local is_connected = false
      for _, a in ipairs(lfo.assignments) do
        if a[1] == param_id then is_connected = true; break end
      end
      if is_connected then b = 15 end
    end
    
    if Grid.cache[col] and Grid.cache[col][row] ~= b then
      grid_dev:led(col, row, util.clamp(math.floor(b), 0, 15))
      Grid.cache[col][row] = b
    end
  end
  
  grid_dev:refresh()
end

function Grid.check_holds()
  for slot = 1, 8 do
    if Grid.snapshot_press_time[slot] then
      local elapsed = clock.get_beats() - Grid.snapshot_press_time[slot]
      if elapsed >= 2.0 then
        local info = Grid.get_snapshot_info(slot)
        if info.exists then Grid.delete_snapshot(slot) end
        Grid.snapshot_press_time[slot] = nil
        Grid.snapshot_delete_warned[slot] = nil
        Grid.redraw()
      end
    end
  end
end

function Grid.cleanup()
  if Grid.connected then
    grid_dev:all(0)
    grid_dev:refresh()
  end
end

return Grid