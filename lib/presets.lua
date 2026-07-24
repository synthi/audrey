-- presets.lua
-- v6.0.0 - preset management system with PSET integration
-- Updated for 11 params (matching C++ original)

local Presets = {}

Presets.num_slots = 16
Presets.current_slot = nil
Presets.slots = {}
Presets.preset_path = _path.data .. "audrey/"

function Presets.init()
  if util.file_exists(Presets.preset_path) == false then
    util.make_dir(Presets.preset_path)
  end
  Presets.scan_presets()
end

function Presets.scan_presets()
  for i = 1, Presets.num_slots do
    local filename = Presets.preset_path .. "preset_" .. i .. ".pset"
    Presets.slots[i] = {
      exists = util.file_exists(filename),
      name = Presets.load_preset_name(i),
      modified = false
    }
  end
end

function Presets.load_preset_name(slot)
  local filename = Presets.preset_path .. "preset_" .. slot .. ".pset"
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

function Presets.save(slot, name)
  if slot < 1 or slot > Presets.num_slots then
    print("Invalid preset slot")
    return false
  end
  name = name or ("Preset " .. slot)
  local filename = Presets.preset_path .. "preset_" .. slot .. ".pset"
  local f = io.open(filename, "w")
  if f then
    f:write("-- " .. name .. "\n")
    f:write("-- Audrey v6.0.0 preset (faithful to C++ original)\n")
    f:write("-- Saved: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
    f:write("return {\n")
    f:write("  -- Synthesis\n")
    Presets.write_param(f, "frequency")
    Presets.write_param(f, "feedback_gain")
    Presets.write_param(f, "feedback_body_delay")
    f:write("  -- Filters\n")
    Presets.write_param(f, "lpf_cutoff")
    Presets.write_param(f, "hpf_cutoff")
    f:write("  -- Reverb\n")
    Presets.write_param(f, "reverb_mix")
    Presets.write_param(f, "reverb_decay")
    f:write("  -- Echo\n")
    Presets.write_param(f, "echo_send")
    Presets.write_param(f, "echo_time")
    Presets.write_param(f, "echo_feedback")
    f:write("  -- Output\n")
    Presets.write_param(f, "master_level")
    f:write("}\n")
    f:close()
    Presets.slots[slot] = {
      exists = true,
      name = name,
      modified = false
    }
    Presets.current_slot = slot
    print("Preset saved to slot " .. slot .. ": " .. name)
    return true
  else
    print("Error: could not write preset file")
    return false
  end
end

function Presets.write_param(f, param_id)
  local val = params:get(param_id)
  f:write("  " .. param_id .. " = " .. val .. ",\n")
end

function Presets.load(slot)
  if slot < 1 or slot > Presets.num_slots then
    print("Invalid preset slot")
    return false
  end
  local filename = Presets.preset_path .. "preset_" .. slot .. ".pset"
  if util.file_exists(filename) == false then
    print("Preset slot " .. slot .. " is empty")
    return false
  end
  local preset_data = dofile(filename)
  if preset_data then
    for param_id, value in pairs(preset_data) do
      if params:lookup_param(param_id) then
        params:set(param_id, value)
      end
    end
    Presets.current_slot = slot
    print("Loaded preset " .. slot .. ": " .. Presets.slots[slot].name)
    return true
  else
    print("Error loading preset file")
    return false
  end
end

function Presets.delete(slot)
  if slot < 1 or slot > Presets.num_slots then
    return false
  end
  local filename = Presets.preset_path .. "preset_" .. slot .. ".pset"
  if util.file_exists(filename) then
    os.remove(filename)
    Presets.slots[slot] = {
      exists = false,
      name = "Empty",
      modified = false
    }
    if Presets.current_slot == slot then
      Presets.current_slot = nil
    end
    print("Deleted preset " .. slot)
    return true
  end
  return false
end

function Presets.check_modified()
  if Presets.current_slot == nil then
    return false
  end
  return false
end

function Presets.get_slot_info(slot)
  return Presets.slots[slot] or {
    exists = false,
    name = "Empty",
    modified = false
  }
end

function Presets.quick_save()
  if Presets.current_slot then
    local name = Presets.slots[Presets.current_slot].name
    return Presets.save(Presets.current_slot, name)
  else
    print("No preset loaded, use save with slot number")
    return false
  end
end

return Presets
