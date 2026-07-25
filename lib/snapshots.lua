-- snapshots.lua
-- v7.4.0 - Per-PSET snapshots (8 slots) + LFO state save/load

local Snapshots = {}

Snapshots.num_slots = 8
Snapshots.current_slot = nil
Snapshots.slots = {}

function Snapshots.get_path()
  local pset_num = 1
  if _G.g and _G.g.pset_num then
    pset_num = _G.g.pset_num
  end
  return _path.data .. "audrey/snapshots/pset_" .. string.format("%02d", pset_num) .. "/"
end

function Snapshots.init()
  Snapshots.ensure_dirs()
  Snapshots.scan()
end

function Snapshots.ensure_dirs()
  local path = Snapshots.get_path()
  if util.file_exists(path) == false then
    util.make_dir(path)
  end
end

function Snapshots.scan()
  local path = Snapshots.get_path()
  for i = 1, Snapshots.num_slots do
    local filename = path .. "snapshot_" .. i .. ".pset"
    Snapshots.slots[i] = {
      exists = util.file_exists(filename),
      name = Snapshots.load_name(i, path),
    }
  end
end

function Snapshots.load_name(slot, path)
  path = path or Snapshots.get_path()
  local filename = path .. "snapshot_" .. slot .. ".pset"
  if util.file_exists(filename) then
    local f = io.open(filename, "r")
    if f then
      local first_line = f:read("*line")
      f:close()
      if first_line and string.sub(first_line, 1, 2) == "--" then
        return string.sub(first_line, 4)
      end
    end
  end
  return "Empty"
end

-- Save LFO state as a Lua table file (serialized for dofile)
local function save_lfo_state(slot, path)
  local LFOs = require("audrey/lib/lfos")
  local state = LFOs.get_state()
  local filename = path .. "snapshot_" .. slot .. "_lfo.data"
  local f = io.open(filename, "w")
  if not f then return end
  f:write("return {\n")
  for i = 1, 4 do
    local s = state[i]
    if s then
      f:write("  [" .. i .. "] = {\n")
      f:write("    freq = " .. s.freq .. ",\n")
      f:write("    wave = " .. s.wave .. ",\n")
      f:write("    enabled = " .. tostring(s.enabled) .. ",\n")
      f:write("    assignments = {\n")
      for _, a in ipairs(s.assignments) do
        f:write('      {"' .. a[1] .. '", ' .. a[2] .. "},\n")
      end
      f:write("    },\n")
      f:write("  },\n")
    end
  end
  f:write("}\n")
  f:close()
end

-- Load LFO state from file
local function load_lfo_state(slot, path)
  local filename = path .. "snapshot_" .. slot .. "_lfo.data"
  if not util.file_exists(filename) then return end
  local ok, data = pcall(dofile, filename)
  if not ok or not data then return end
  local LFOs = require("audrey/lib/lfos")
  LFOs.set_state(data)
end

function Snapshots.save(slot, name)
  if slot < 1 or slot > Snapshots.num_slots then return false end
  name = name or ("S" .. slot)
  local path = Snapshots.get_path()
  Snapshots.ensure_dirs()
  local filename = path .. "snapshot_" .. slot .. ".pset"
  local f = io.open(filename, "w")
  if f then
    f:write("-- " .. name .. "\n")
    f:write("-- Audrey v7.4.0 snapshot\n")
    f:write("-- Saved: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
    f:write("return {\n")
    f:write("  -- Synthesis\n")
    Snapshots.write_param(f, "frequency")
    Snapshots.write_param(f, "feedback_gain")
    Snapshots.write_param(f, "feedback_body_delay")
    f:write("  -- Filters\n")
    Snapshots.write_param(f, "lpf_cutoff")
    Snapshots.write_param(f, "hpf_cutoff")
    f:write("  -- Reverb\n")
    Snapshots.write_param(f, "reverb_mix")
    Snapshots.write_param(f, "reverb_decay")
    f:write("  -- Echo\n")
    Snapshots.write_param(f, "echo_send")
    Snapshots.write_param(f, "echo_time")
    Snapshots.write_param(f, "echo_feedback")
    f:write("  -- Output\n")
    Snapshots.write_param(f, "master_level")
    f:write("}\n")
    f:close()
    
    save_lfo_state(slot, path)
    
    Snapshots.slots[slot] = { exists = true, name = name }
    Snapshots.current_slot = slot
    print("Snapshot saved to slot " .. slot .. ": " .. name)
    return true
  end
  return false
end

function Snapshots.write_param(f, param_id)
  local val = params:get(param_id)
  f:write("  " .. param_id .. " = " .. val .. ",\n")
end

function Snapshots.load(slot)
  if slot < 1 or slot > Snapshots.num_slots then return false end
  local path = Snapshots.get_path()
  local filename = path .. "snapshot_" .. slot .. ".pset"
  if util.file_exists(filename) == false then
    print("Snapshot slot " .. slot .. " is empty")
    return false
  end
  local snapshot_data = dofile(filename)
  if snapshot_data then
    for param_id, value in pairs(snapshot_data) do
      if params:lookup_param(param_id) then
        params:set(param_id, value)
      end
    end
    Snapshots.current_slot = slot
    
    -- Restore LFO state
    load_lfo_state(slot, path)
    
    print("Loaded snapshot " .. slot .. ": " .. Snapshots.slots[slot].name)
    return true
  end
  return false
end

function Snapshots.delete(slot)
  if slot < 1 or slot > Snapshots.num_slots then return false end
  local path = Snapshots.get_path()
  local filename = path .. "snapshot_" .. slot .. ".pset"
  if util.file_exists(filename) then
    os.remove(filename)
    -- Also remove LFO state file
    local lfo_filename = path .. "snapshot_" .. slot .. "_lfo.data"
    if util.file_exists(lfo_filename) then
      os.remove(lfo_filename)
    end
    Snapshots.slots[slot] = { exists = false, name = "Empty" }
    if Snapshots.current_slot == slot then Snapshots.current_slot = nil end
    print("Deleted snapshot " .. slot)
    return true
  end
  return false
end

function Snapshots.get_slot_info(slot)
  return Snapshots.slots[slot] or { exists = false, name = "Empty" }
end

function Snapshots.quick_save()
  if Snapshots.current_slot then
    return Snapshots.save(Snapshots.current_slot, Snapshots.slots[Snapshots.current_slot].name)
  end
  return false
end

return Snapshots