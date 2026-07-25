-- lfos.lua
-- v7.2.0 - 4 LFO modulation system (ncoco-style hold-based patching)
--
-- Patching: hold LFO + tap knob → connect. Hold knob + tap LFO → same.
-- Overlay stays visible while source/dest is held, disappears on release.
-- No timeouts. No clocks for patch mode.
--
-- Assignment format: {param_id, depth, mode, last_contrib}
--   mode: "uni+" / "uni-" / "bi+" / "bi-"

local LFOs = {}

LFOs.data = {}
LFOs.overlay = nil  -- {lfo_id, param_id, depth, mode} shown while held

LFOs.WAVE_TRI = 1
LFOs.WAVE_PERLIN = 2
LFOs.MODES = {"uni+", "uni-", "bi+", "bi-"}

function LFOs.init()
  LFOs.data = {}
  for i = 1, 4 do
    LFOs.data[i] = {
      enabled = true,
      freq = 1.0,
      wave = LFOs.WAVE_TRI,
      phase = math.random() * 2 * math.pi,
      value = 0.0,
      assignments = {},
      metro = nil,
      patch_mode = false,
      perlin_noise = nil,
      history = {},
      history_head = 1,
    }
    for j = 1, 128 do LFOs.data[i].history[j] = 0 end
    LFOs.data[i].metro = metro.init()
    LFOs.data[i].metro.time = 1/60
    LFOs.data[i].metro.event = function()
      LFOs._tick(i)
    end
    LFOs.data[i].metro:start()

    LFOs.data[i].perlin_noise = {
      x = math.random() * 1000,
      y = math.random() * 1000,
      z = math.random() * 1000,
    }
  end
  LFOs.overlay = nil
end

function LFOs.cleanup()
  for i = 1, 4 do
    if LFOs.data[i] and LFOs.data[i].metro then
      LFOs.data[i].metro:stop()
    end
  end
  LFOs.data = {}
  LFOs.overlay = nil
end

function LFOs.has_assignments(param_id)
  for i = 1, 4 do
    if LFOs.data[i] then
      for _, a in ipairs(LFOs.data[i].assignments) do
        if a[1] == param_id then return true end
      end
    end
  end
  return false
end

-- Get LFOs connected to a specific param
function LFOs.get_connected_lfos(param_id)
  local result = {}
  for i = 1, 4 do
    if LFOs.data[i] then
      for _, a in ipairs(LFOs.data[i].assignments) do
        if a[1] == param_id then
          result[i] = true
          break
        end
      end
    end
  end
  return result
end

function LFOs.set_patch_mode(lfo_id, state)
  if LFOs.data[lfo_id] then
    LFOs.data[lfo_id].patch_mode = state
  end
end

-- Toggle connection: if exists → remove, if new → add or steal from another LFO
function LFOs.toggle_assignment(lfo_id, param_id)
  if not LFOs.data[lfo_id] then return false end
  
  -- Check if already assigned to THIS lfo → remove
  for idx, a in ipairs(LFOs.data[lfo_id].assignments) do
    if a[1] == param_id then
      table.remove(LFOs.data[lfo_id].assignments, idx)
      LFOs.overlay = nil
      return false
    end
  end

  -- Steal from other LFOs
  for i = 1, 4 do
    if i ~= lfo_id and LFOs.data[i] then
      for idx, a in ipairs(LFOs.data[i].assignments) do
        if a[1] == param_id then
          table.remove(LFOs.data[i].assignments, idx)
          break
        end
      end
    end
  end
  
  -- Add new assignment
  table.insert(LFOs.data[lfo_id].assignments, {param_id, 0.25, "uni+", 0.0})
  
  -- Show overlay (persists while source/dest held)
  LFOs.overlay = {
    lfo_id = lfo_id,
    param_id = param_id,
    depth = 0.25,
    mode = "uni+",
  }
  
  return true
end

function LFOs.remove_assignment(lfo_id, param_id)
  if not LFOs.data[lfo_id] then return end
  for idx, a in ipairs(LFOs.data[lfo_id].assignments) do
    if a[1] == param_id then
      table.remove(LFOs.data[lfo_id].assignments, idx)
      LFOs.overlay = nil
      if _G.g then _G.g.screen_dirty = true end
      return
    end
  end
end

function LFOs.clear_assignments(lfo_id)
  if not LFOs.data[lfo_id] then return end
  LFOs.data[lfo_id].assignments = {}
  LFOs.overlay = nil
  if _G.g then _G.g.screen_dirty = true end
end

-- Simple Perlin noise
local function perlin_noise(x, y, z)
  local function hash(n)
    local h = n * 2654435761 % (2^32)
    return h / (2^32)
  end
  local xi, yi, zi = math.floor(x), math.floor(y), math.floor(z)
  local xf, yf, zf = x - xi, y - yi, z - zi
  local function smooth(t) return t * t * (3 - 2 * t) end
  local u, v, w = smooth(xf), smooth(yf), smooth(zf)
  local function corner(ox, oy, oz)
    return hash(xi + ox + (yi + oy) * 256 + (zi + oz) * 65536)
  end
  local a = corner(0, 0, 0) + u * (corner(1, 0, 0) - corner(0, 0, 0))
  local b = corner(0, 1, 0) + u * (corner(1, 1, 0) - corner(0, 1, 0))
  local c = corner(0, 0, 1) + u * (corner(1, 0, 1) - corner(0, 0, 1))
  local d = corner(0, 1, 1) + u * (corner(1, 1, 1) - corner(0, 1, 1))
  return (a + v * (b - a)) + w * ((c + v * (d - c)) - (a + v * (b - a)))
end

function LFOs._tick(lfo_id)
  local lfo = LFOs.data[lfo_id]
  if not lfo or not lfo.enabled then return end
  
  lfo.phase = lfo.phase + (2 * math.pi * lfo.freq / 60)
  if lfo.phase > 2 * math.pi then lfo.phase = lfo.phase - 2 * math.pi end
  
  local wave_val
  if lfo.wave == LFOs.WAVE_TRI then
    local p = lfo.phase / (2 * math.pi)
    wave_val = 4 * math.abs(p - 0.5) - 1
  else
    local speed = lfo.freq * 0.5
    local t = lfo.phase / (2 * math.pi)
    local noise_val = perlin_noise(
      lfo.perlin_noise.x + t * speed * 5,
      lfo.perlin_noise.y,
      lfo.perlin_noise.z
    )
    wave_val = (noise_val - 0.5) * 2
  end
  
  lfo.value = wave_val
  
  -- Push to scope history
  lfo.history_head = (lfo.history_head % 128) + 1
  lfo.history[lfo.history_head] = wave_val
  
  for _, a in ipairs(lfo.assignments) do
    local param_id, depth, mode = a[1], a[2], a[3]
    local p = params:lookup_param(param_id)
    if not p then goto continue end
    
    local current_raw = p:get()
    local base = current_raw - (a[4] or 0)
    
    local contrib = 0
    if mode == "uni+" then
      contrib = ((wave_val + 1) / 2) * depth
    elseif mode == "uni-" then
      contrib = ((wave_val + 1) / 2) * (-depth)
    elseif mode == "bi+" then
      contrib = wave_val * depth
    elseif mode == "bi-" then
      contrib = (-wave_val) * depth
    end
    
    a[4] = contrib
    local new_val = util.clamp(base + contrib, p.controlspec.minval, p.controlspec.maxval)
    params:set(param_id, new_val)
    
    ::continue::
  end
end

function LFOs.adjust_overlay(delta, mode_cycle)
  if not LFOs.overlay then return end
  local o = LFOs.overlay
  o.depth = util.clamp(o.depth + delta * 0.01, 0.001, 1.0)
  
  if mode_cycle ~= 0 then
    local idx = 1
    for i, m in ipairs(LFOs.MODES) do
      if m == o.mode then idx = i; break end
    end
    idx = ((idx - 1 + mode_cycle) % #LFOs.MODES) + 1
    if idx < 1 then idx = #LFOs.MODES end
    o.mode = LFOs.MODES[idx]
  end
  
  local lfo = LFOs.data[o.lfo_id]
  if lfo then
    for _, a in ipairs(lfo.assignments) do
      if a[1] == o.param_id then
        a[2] = o.depth
        a[3] = o.mode
        break
      end
    end
  end
  
  if _G.g then _G.g.screen_dirty = true end
end

return LFOs