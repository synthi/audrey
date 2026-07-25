-- snapshots.lua
-- v7.2.0 - Snapshot management system with PSET integration
-- Updated for 11 params (matching C++ original)

local Snapshots = {}

Snapshots.num_slots = 16
Snapshots.current_slot = nil
Snapshots.slots = {}
Snapshots.snapshot_path = _path.data .. "audrey/"

function Snapshots.init()
  if util.file_exists(Snapshots.snapshot_path) == false then
    util.make_dir(Snapshots.snapshot_path)
  end
  Snapshots.scan_snapshots()
end

function Snapshots.scan_snapshots()
  for i = 1, Snapshots.num_slots do
    local filename = Snapshots.snapshot_path .. "snapshot_" .. i .. ".pset"
    Snapshots.slots[i] = {
      exists = util.file_exists(filename),
      name = Snapshots.load_snapshot_name(i),
      modified = false
    }
  end
end

function Snapshots.load_snapshot_name(slot)
  local filename = Snapshots.snapshot_path .. "snapshot_" .. slot .. ".pset"
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

function Snapshots.save(slot, name)
  if slot < 1 or slot > Snapshots.num_slots then
    print("Invalid snapshot slot")
    return false
  end
  name = name or ("Snapshot " .. slot)
  local filename = Snapshots.snapshot_path .. "snapshot_" .. slot .. ".pset"
  local f = io.open(filename, "w")
  if f then
    f:write("-- " .. name .. "\n")
    f:write("-- Audrey v7.2.0 snapshot (faithful to C++ original)\n")
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
    Snapshots.slots[slot] = {
      exists = true,
      name = name,
      modified = false
    }
    Snapshots.current_slot = slot
    print("Snapshot saved to slot " .. slot .. ": " .. name)
    return true
  else
    print("Error: could not write preset file")
    return false
  end
end

function Snapshots.write_param(f, param_id)
  local val = params:get(param_id)
  f:write("  " .. param_id .. " = " .. val .. ",\n")
end

function Snapshots.load(slot)
  if slot < 1 or slot > Snapshots.num_slots then
    print("Invalid snapshot slot")
    return false
  end
  local filename = Snapshots.snapshot_path .. "snapshot_" .. slot .. ".pset"
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
    print("Loaded snapshot " .. slot .. ": " .. Snapshots.slots[slot].name)
    return true
  else
    print("Error loading snapshot file")
    return false
  end
end

function Snapshots.delete(slot)
  if slot < 1 or slot > Snapshots.num_slots then
    return false
  end
  local filename = Snapshots.snapshot_path .. "snapshot_" .. slot .. ".pset"
  if util.file_exists(filename) then
    os.remove(filename)
    Snapshots.slots[slot] = {
      exists = false,
      name = "Empty",
      modified = false
    }
    if Snapshots.current_slot == slot then
      Snapshots.current_slot = nil
    end
    print("Deleted snapshot " .. slot)
    return true
  end
  return false
end

function Snapshots.check_modified()
  if Snapshots.current_slot == nil then
    return false
  end
  return false
end

function Snapshots.get_slot_info(slot)
  return Snapshots.slots[slot] or {
    exists = false,
    name = "Empty",
    modified = false
  }
end

function Snapshots.quick_save()
  if Snapshots.current_slot then
    local name = Snapshots.slots[Snapshots.current_slot].name
    return Snapshots.save(Snapshots.current_slot, name)
  else
    print("No snapshot loaded, use save with slot number")
    return false
  end
end

return Snapshots
