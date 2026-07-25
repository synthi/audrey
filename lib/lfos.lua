-- lfos.lua
-- v7.4.0 - ncoco-style signed depth (-1..+1), no modes, continuous bar
--
-- LFNoise: random target every 1/freq seconds, linear slew between samples
-- Depth: signed continuous -1..+1 (ncoco exact: val = clamp(depth + delta/100, -1, 1))
-- Overlay: bar centered at 0, negative=left, positive=right
-- K2/K3: flip polarity (depth *= -1)

local LFOs = {}

LFOs.data = {}
LFOs.overlay = nil
LFOs.base_values = {}

LFOs.WAVE_TRI = 1
LFOs.WAVE_SLEW = 2   -- LFNoise with slew (replaces Perlin)

function LFOs.init()
  LFOs.data = {}
  for i = 1, 5 do
    LFOs.data[i] = {
      enabled = true,
      freq = 0.25 + (i-1) * 0.125,  -- LFO1=0.25, LFO2=0.375, LFO3=0.5, LFO4=0.625, LFO5=0.75 Hz
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
  for i = 1, 5 do
    if LFOs.data[i] and LFOs.data[i].metro then
      LFOs.data[i].metro:stop()
    end
  end
  LFOs.data = {}
  LFOs.overlay = nil
end

-- Get base value (without LFO modulation)
function LFOs.get_base_value(param_id)
  if LFOs.base_values[param_id] ~= nil then
    return LFOs.base_values[param_id]
  end
  local p = params:lookup_param(param_id)
  return p and p:get() or 0
end

-- Get modulation info for a param: {lfos = {1,3}, pct = 0.37}
function LFOs.get_modulation(param_id)
  local lfo_ids = {}
  local total_contrib = 0
  local p = params:lookup_param(param_id)
  if not p then return {lfos = {}, pct = 0} end
  local range = p.controlspec.maxval - p.controlspec.minval
  for i = 1, 5 do
    if LFOs.data[i] then
      for _, a in ipairs(LFOs.data[i].assignments) do
        if a[1] == param_id then
          table.insert(lfo_ids, i)
          total_contrib = total_contrib + (a[3] or 0)
          break
        end
      end
    end
  end
  return {lfos = lfo_ids, pct = range > 0 and (total_contrib / range) or 0}
end

function LFOs.has_assignments(param_id)
  for i = 1, 5 do
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
  for i = 1, 5 do
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
    -- Already connected: show overlay with current depth
    LFOs.overlay = {
      lfo_id = lfo_id,
      param_id = param_id,
      depth = existing[2],
    }
    return
  end

  -- New connection: signed depth 0.25, contrib starts at 0
  -- (Multiple LFOs can modulate the same parameter - ncoco style)
  table.insert(LFOs.data[lfo_id].assignments, {param_id, 0.25, 0.0})
  LFOs.overlay = {
    lfo_id = lfo_id,
    param_id = param_id,
    depth = 0.25,
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

-- ncoco exact: depth + delta/100, clamped -1..+1
function LFOs.adjust_overlay(delta)
  if not LFOs.overlay then return end
  local o = LFOs.overlay

  o.depth = util.clamp(o.depth + delta / 100, -1, 1)

  -- Update actual assignment
  local lfo = LFOs.data[o.lfo_id]
  if lfo then
    for _, a in ipairs(lfo.assignments) do
      if a[1] == o.param_id then
        a[2] = o.depth
        break
      end
    end
  end

  if _G.g then _G.g.screen_dirty = true end
end

-- Flip polarity (K2/K3)
function LFOs.flip_polarity()
  if not LFOs.overlay then return end
  local o = LFOs.overlay
  o.depth = -o.depth

  -- Update actual assignment
  local lfo = LFOs.data[o.lfo_id]
  if lfo then
    for _, a in ipairs(lfo.assignments) do
      if a[1] == o.param_id then
        a[2] = o.depth
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
    local param_id, depth = a[1], a[2]
    local p = params:lookup_param(param_id)
    if not p then goto continue end

    local current_raw = p:get()
    local base = current_raw - (a[3] or 0)
    LFOs.base_values[param_id] = base

    -- Unipolar modulation: (wave_val+1)/2 (0..1) * depth (-1..+1) * range
    local range = p.controlspec.maxval - p.controlspec.minval
    local contrib = ((wave_val + 1) / 2) * depth * range

    a[3] = contrib
    local new_val = util.clamp(base + contrib, p.controlspec.minval, p.controlspec.maxval)
    params:set(param_id, new_val)

    ::continue::
  end
end

-- Serialize LFO state for snapshots
function LFOs.get_state()
  local state = {}
  for i = 1, 5 do
    if LFOs.data[i] then
      local lfo = LFOs.data[i]
      local assignments = {}
      for _, a in ipairs(lfo.assignments) do
        table.insert(assignments, {a[1], a[2]})
      end
      state[i] = {
        freq = lfo.freq,
        wave = lfo.wave,
        enabled = lfo.enabled,
        assignments = assignments,
      }
    end
  end
  return state
end

-- Restore LFO state from snapshots
function LFOs.set_state(state)
  if not state then return end
  for i = 1, 5 do
    if state[i] and LFOs.data[i] then
      local s = state[i]
      LFOs.data[i].freq = s.freq or 1.0
      LFOs.data[i].wave = s.wave or LFOs.WAVE_TRI
      LFOs.data[i].enabled = s.enabled
      if s.enabled == nil then LFOs.data[i].enabled = true end
      -- Rebuild assignments with fresh contrib (will be recalculated on next tick)
      LFOs.data[i].assignments = {}
      if s.assignments then
        for _, a in ipairs(s.assignments) do
          table.insert(LFOs.data[i].assignments, {a[1], a[2], 0.0})
        end
      end
    end
  end
  LFOs.overlay = nil
end

return LFOs