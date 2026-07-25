-- lfos.lua
-- v7.2.0 - 4 LFO modulation (ncoco-style hold patching, LFNoise slew)
--
-- LFNoise: random target every 1/freq seconds, linear slew between samples
-- Depth scales to FULL param range (100% at depth=1.0)
-- Overlay: bar stays static (not modulated by LFO), crosses ± via encoder

local LFOs = {}

LFOs.data = {}
LFOs.overlay = nil

LFOs.WAVE_TRI = 1
LFOs.WAVE_SLEW = 2   -- LFNoise with slew (replaces Perlin)
LFOs.MODES = {"uni+", "uni-", "bi+", "bi-"}

function LFOs.init()
  LFOs.data = {}
  for i = 1, 4 do
    LFOs.data[i] = {
      enabled = true,
      freq = 1.0,           -- 0.01 - 32 Hz
      wave = LFOs.WAVE_TRI,
      phase = math.random() * 2 * math.pi,
      value = 0.0,
      assignments = {},
      metro = nil,
      patch_mode = false,
      -- Slew noise state
      slew_target = math.random() * 2 - 1,
      slew_current = 0.0,
      slew_timer = 0,
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

-- Find existing assignment for this (lfo, param)
local function find_assignment(lfo_id, param_id)
  local lfo = LFOs.data[lfo_id]
  if not lfo then return nil end
  for _, a in ipairs(lfo.assignments) do
    if a[1] == param_id then return a end
  end
  return nil
end

-- Connect or show overlay (ncoco: if already connected → enter patch menu, don't disconnect)
function LFOs.connect_or_show(lfo_id, param_id)
  if not LFOs.data[lfo_id] then return end
  
  local existing = find_assignment(lfo_id, param_id)
  if existing then
    -- Already connected: show overlay with current values
    LFOs.overlay = {
      lfo_id = lfo_id,
      param_id = param_id,
      depth = existing[2],
      mode = existing[3],
    }
    return
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
  
  -- New connection
  table.insert(LFOs.data[lfo_id].assignments, {param_id, 0.25, "uni+", 0.0})
  LFOs.overlay = {
    lfo_id = lfo_id,
    param_id = param_id,
    depth = 0.25,
    mode = "uni+",
  }
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

-- Adjust overlay with encoder acceleration (^2.5, step 0.001)
-- Crosses ± boundary automatically
function LFOs.adjust_overlay(delta, mode_cycle)
  if not LFOs.overlay then return end
  local o = LFOs.overlay
  
  if mode_cycle ~= 0 then
    local idx = 1
    for i, m in ipairs(LFOs.MODES) do
      if m == o.mode then idx = i; break end
    end
    idx = ((idx - 1 + mode_cycle) % #LFOs.MODES) + 1
    if idx < 1 then idx = #LFOs.MODES end
    o.mode = LFOs.MODES[idx]
  else
    -- Accelerated depth: ^2.5, fine step 0.001
    local sign = (delta > 0) and 1 or -1
    local steps = math.abs(delta) ^ 2.5
    local change = sign * steps * 0.001
    local new_depth = o.depth + change
    
    if new_depth <= 0 then
      -- Cross ± boundary: flip polarity, abs value
      if o.mode == "uni+" then o.mode = "uni-"
      elseif o.mode == "uni-" then o.mode = "uni+"
      elseif o.mode == "bi+" then o.mode = "bi-"
      elseif o.mode == "bi-" then o.mode = "bi+" end
      o.depth = math.abs(new_depth)
    else
      o.depth = util.clamp(new_depth, 0.001, 1.0)
    end
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

function LFOs._tick(lfo_id)
  local lfo = LFOs.data[lfo_id]
  if not lfo then return end
  
  -- Always advance phase and compute waveform (for scope + value)
  lfo.phase = lfo.phase + (2 * math.pi * lfo.freq / 60)
  if lfo.phase > 2 * math.pi then lfo.phase = lfo.phase - 2 * math.pi end
  
  local wave_val
  if lfo.wave == LFOs.WAVE_TRI then
    local p = lfo.phase / (2 * math.pi)
    wave_val = 4 * math.abs(p - 0.5) - 1
  else
    -- LFNoise with linear slew
    lfo.slew_timer = lfo.slew_timer + 1/60
    local interval = 1 / lfo.freq
    if lfo.slew_timer >= interval then
      lfo.slew_timer = lfo.slew_timer - interval
      lfo.slew_target = math.random() * 2 - 1
    end
    -- Linear interpolation toward target
    local t = lfo.slew_timer / interval
    lfo.slew_current = lfo.slew_current + (lfo.slew_target - lfo.slew_current) * t * 0.5
    wave_val = lfo.slew_current
  end
  
  lfo.value = wave_val
  
  -- Push to scope history ALWAYS
  lfo.history_head = (lfo.history_head % 128) + 1
  lfo.history[lfo.history_head] = wave_val
  
  if not lfo.enabled then return end
  
  for _, a in ipairs(lfo.assignments) do
    local param_id, depth, mode = a[1], a[2], a[3]
    local p = params:lookup_param(param_id)
    if not p then goto continue end
    
    local current_raw = p:get()
    local base = current_raw - (a[4] or 0)
    
    -- Scale depth to FULL param range
    local range = p.controlspec.maxval - p.controlspec.minval
    local scaled_depth = depth * range
    
    local contrib = 0
    if mode == "uni+" then
      contrib = ((wave_val + 1) / 2) * scaled_depth
    elseif mode == "uni-" then
      contrib = ((wave_val + 1) / 2) * (-scaled_depth)
    elseif mode == "bi+" then
      contrib = wave_val * scaled_depth
    elseif mode == "bi-" then
      contrib = (-wave_val) * scaled_depth
    end
    
    a[4] = contrib
    local new_val = util.clamp(base + contrib, p.controlspec.minval, p.controlspec.maxval)
    params:set(param_id, new_val)
    
    ::continue::
  end
end

return LFOs