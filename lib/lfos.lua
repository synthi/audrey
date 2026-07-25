-- lfos.lua
-- v7.2.0 - 4 LFO modulation system for Audrey
-- Each LFO: triangle or Perlin noise, assignable to any param
-- Self-correcting offset: always modulates from current param value
--
-- Assignment format: {param_id, depth, mode}
--   mode: "uni+" = unipolar positive, "uni-" = unipolar inverted
--         "bi+"  = bipolar positive,  "bi-"  = bipolar inverted
--
-- Grid gestures:
--   Hold LFO btn + tap knob → connect (or disconnect if exists)
--   SHIFT + hold LFO + tap knob → remove that assignment
--   SHIFT + tap LFO → remove ALL assignments
--   Tap knob with LFOs → brightness 15 (instead of 14)

local LFOs = {}

LFOs.data = {}    -- {1..4} = {freq, wave, phase, value, assignments, metro, patch_mode}
LFOs.overlay = nil -- {lfo_id, param_id, depth, mode} for popup

-- Waveforms
LFOs.WAVE_TRI = 1
LFOs.WAVE_PERLIN = 2

-- Modes
LFOs.MODES = {"uni+", "uni-", "bi+", "bi-"}

function LFOs.init()
  LFOs.data = {}
  for i = 1, 4 do
    LFOs.data[i] = {
      enabled = true,
      freq = 1.0,          -- Hz (0.01 - 100)
      wave = LFOs.WAVE_TRI,
      phase = math.random() * 2 * math.pi,
      value = 0.0,         -- current output (-1 to 1 for bi, 0 to 1 for uni)
      assignments = {},     -- {{param_id, depth, mode, last_contrib}, ...}
      metro = nil,
      patch_mode = false,   -- true while waiting for knob target
      patch_timer = nil,
      perlin_noise = nil,   -- {x, y, z} seed for Perlin
    }
    -- Start metro for this LFO
    LFOs.data[i].metro = metro.init()
    LFOs.data[i].metro.time = 1/60
    LFOs.data[i].metro.event = function()
      LFOs._tick(i)
    end
    LFOs.data[i].metro:start()

    -- Random Perlin seed
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

-- Check if any LFO has assignments for a given param
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

-- Enter patch mode for a specific LFO
function LFOs.start_patch_mode(lfo_id)
  if not LFOs.data[lfo_id] then return end
  LFOs.data[lfo_id].patch_mode = true
  if LFOs.data[lfo_id].patch_timer then
    clock.cancel(LFOs.data[lfo_id].patch_timer)
  end
  LFOs.data[lfo_id].patch_timer = clock.run(function()
    clock.sleep(5)
    if LFOs.data[lfo_id] then
      LFOs.data[lfo_id].patch_mode = false
    end
  end)
end

-- Toggle connection: if exists → remove, if new → add
function LFOs.toggle_assignment(lfo_id, param_id)
  if not LFOs.data[lfo_id] then return false end
  
  -- Check if already assigned to THIS lfo
  for idx, a in ipairs(LFOs.data[lfo_id].assignments) do
    if a[1] == param_id then
      -- Remove
      table.remove(LFOs.data[lfo_id].assignments, idx)
      LFOs.data[lfo_id].patch_mode = false
      LFOs.overlay = nil
      return false
    end
  end

  -- Check if assigned to ANOTHER lfo → steal it
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
  
  -- Add new assignment with default uni+ mode at depth 0.25
  table.insert(LFOs.data[lfo_id].assignments, {
    param_id, 0.25, "uni+", 0.0
  })
  
  -- Show overlay
  LFOs.overlay = {
    lfo_id = lfo_id,
    param_id = param_id,
    depth = 0.25,
    mode = "uni+",
    timer = clock.run(function()
      clock.sleep(3)
      LFOs.overlay = nil
      if _G.g then _G.g.screen_dirty = true end
    end)
  }
  
  LFOs.data[lfo_id].patch_mode = false
  return true
end

-- Remove a specific assignment (SHIFT + LFO + knob)
function LFOs.remove_assignment(lfo_id, param_id)
  if not LFOs.data[lfo_id] then return end
  for idx, a in ipairs(LFOs.data[lfo_id].assignments) do
    if a[1] == param_id then
      table.remove(LFOs.data[lfo_id].assignments, idx)
      LFOs.data[lfo_id].patch_mode = false
      LFOs.overlay = nil
      if _G.g then _G.g.screen_dirty = true end
      return
    end
  end
end

-- Remove ALL assignments from an LFO
function LFOs.clear_assignments(lfo_id)
  if not LFOs.data[lfo_id] then return end
  LFOs.data[lfo_id].assignments = {}
  LFOs.data[lfo_id].patch_mode = false
  LFOs.overlay = nil
  if _G.g then _G.g.screen_dirty = true end
end

-- Simple Perlin-like noise (value noise with interpolation)
local function perlin_noise(x, y, z)
  local function hash(n)
    -- Simple pseudo-random hash
    local h = n * 2654435761 % (2^32)
    return h / (2^32)
  end

  local xi = math.floor(x)
  local yi = math.floor(y)
  local zi = math.floor(z)
  
  local xf = x - xi
  local yf = y - yi
  local zf = z - zi

  -- Smooth step interpolation
  local function smooth(t)
    return t * t * (3 - 2 * t)
  end
  
  local u = smooth(xf)
  local v = smooth(yf)
  local w = smooth(zf)
  
  -- 8 corners of the cube
  local function corner(ox, oy, oz)
    return hash(xi + ox + (yi + oy) * 256 + (zi + oz) * 65536)
  end
  
  -- Trilinear interpolation
  local a = corner(0, 0, 0) + u * (corner(1, 0, 0) - corner(0, 0, 0))
  local b = corner(0, 1, 0) + u * (corner(1, 1, 0) - corner(0, 1, 0))
  local c = corner(0, 0, 1) + u * (corner(1, 0, 1) - corner(0, 0, 1))
  local d = corner(0, 1, 1) + u * (corner(1, 1, 1) - corner(0, 1, 1))
  
  local ab = a + v * (b - a)
  local cd = c + v * (d - c)
  
  return ab + w * (cd - ab)
end

-- Tick one LFO (called at 60 Hz)
function LFOs._tick(lfo_id)
  local lfo = LFOs.data[lfo_id]
  if not lfo or not lfo.enabled then return end
  if #lfo.assignments == 0 then
    lfo.value = 0
    return
  end
  
  -- Advance phase
  lfo.phase = lfo.phase + (2 * math.pi * lfo.freq / 60)
  if lfo.phase > 2 * math.pi then lfo.phase = lfo.phase - 2 * math.pi end
  
  -- Calculate waveform value (-1 to 1)
  local wave_val
  if lfo.wave == LFOs.WAVE_TRI then
    -- Triangle wave
    local p = lfo.phase / (2 * math.pi)
    wave_val = 4 * math.abs(p - 0.5) - 1
  else
    -- Perlin noise (drift through 3D noise space)
    local speed = lfo.freq * 0.5
    local t = lfo.phase / (2 * math.pi)
    local noise_val = perlin_noise(
      lfo.perlin_noise.x + t * speed * 5,
      lfo.perlin_noise.y,
      lfo.perlin_noise.z
    )
    wave_val = (noise_val - 0.5) * 2  -- map 0-1 to -1+1
  end
  
  lfo.value = wave_val
  
  -- Apply to all assignments
  for _, a in ipairs(lfo.assignments) do
    local param_id = a[1]
    local depth = a[2]
    local mode = a[3]
    
    local p = params:lookup_param(param_id)
    if not p then goto continue end
    
    local current_raw = p:get()
    
    -- Infer base by removing our last contribution
    local base = current_raw - (a[4] or 0)
    
    -- Calculate contribution based on mode
    local contrib = 0
    if mode == "uni+" then
      -- Unipolar positive: 0 to +depth
      contrib = ((wave_val + 1) / 2) * depth
    elseif mode == "uni-" then
      -- Unipolar inverted: 0 to -depth
      contrib = ((wave_val + 1) / 2) * (-depth)
    elseif mode == "bi+" then
      -- Bipolar positive: -depth to +depth
      contrib = wave_val * depth
    elseif mode == "bi-" then
      -- Bipolar inverted: +depth to -depth
      contrib = (-wave_val) * depth
    end
    
    a[4] = contrib
    
    -- Clamp and set
    local new_val = util.clamp(base + contrib, p.controlspec.minval, p.controlspec.maxval)
    params:set(param_id, new_val)
    
    ::continue::
  end
end

-- Adjust overlay depth/cycle mode
function LFOs.adjust_overlay(depth_delta, mode_cycle)
  if not LFOs.overlay then return end
  local o = LFOs.overlay
  o.depth = util.clamp(o.depth + depth_delta * 0.01, 0.001, 1.0)
  
  if mode_cycle ~= 0 then
    local idx = 1
    for i, m in ipairs(LFOs.MODES) do
      if m == o.mode then idx = i; break end
    end
    idx = ((idx - 1 + mode_cycle) % #LFOs.MODES) + 1
    if idx < 1 then idx = #LFOs.MODES end
    o.mode = LFOs.MODES[idx]
  end
  
  -- Update actual assignment
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