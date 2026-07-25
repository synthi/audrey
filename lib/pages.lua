-- pages.lua
-- v7.3.0 - 10 pages (5 synth + 4 LFO + SNAPSHOTS) + page indicators
local LFOs = require("audrey/lib/lfos")
local Snapshots = require("audrey/lib/snapshots")

local Pages = {}

Pages.page_list = {
  {name = "SYNTHESIS", params = {"frequency", "feedback_gain", "feedback_body_delay"}},
  {name = "FILTERS", params = {"lpf_cutoff", "hpf_cutoff"}},
  {name = "REVERB", params = {"reverb_mix", "reverb_decay"}},
  {name = "ECHO", params = {"echo_send", "echo_time", "echo_feedback"}},
  {name = "OUTPUT", params = {"master_level"}},
  {name = "LFO 1", params = {}, lfo_id = 1},
  {name = "LFO 2", params = {}, lfo_id = 2},
  {name = "LFO 3", params = {}, lfo_id = 3},
  {name = "LFO 4", params = {}, lfo_id = 4},
  {name = "LFO 5", params = {}, lfo_id = 5},
  {name = "SNAPSHOTS", params = {}}
}

Pages.lfo_cursor = {1, 1, 1, 1, 1}

function Pages.init()
  _G.g.current_page = 1
  _G.g.param_focus = 1
  _G.g.preset_focus = 1
  Pages.lfo_cursor = {1, 1, 1, 1, 1}
end

function Pages.next_page()
  _G.g.current_page = util.clamp(_G.g.current_page + 1, 1, #Pages.page_list)
  _G.g.param_focus = 1
end

function Pages.prev_page()
  _G.g.current_page = util.clamp(_G.g.current_page - 1, 1, #Pages.page_list)
  _G.g.param_focus = 1
end

function Pages.change_param_focus(delta)
  local page = Pages.page_list[_G.g.current_page]
  if page.name == "SNAPSHOTS" then
    _G.g.preset_focus = util.clamp(_G.g.preset_focus + delta, 1, Snapshots.num_slots)
  elseif page.lfo_id then
    local lfo = LFOs.data[page.lfo_id]
    local count = lfo and #lfo.assignments or 0
    Pages.lfo_cursor[page.lfo_id] = util.clamp(Pages.lfo_cursor[page.lfo_id] + delta, 1, math.max(1, count))
  else
    if #page.params > 0 then
      _G.g.param_focus = util.clamp(_G.g.param_focus + delta, 1, #page.params)
    end
  end
end

function Pages.adjust_focused_param(delta)
  local page = Pages.page_list[_G.g.current_page]
  if page.name == "SNAPSHOTS" then return end
  
  if page.lfo_id then
    -- LFO page: adjust frequency with cents-based ratio
    local lfo = LFOs.data[page.lfo_id]
    if lfo then
      local sign = (delta > 0) and 1 or -1
      local cents = (math.abs(delta) ^ 3.5) * 1.5
      local ratio = 2 ^ (sign * cents / 1200)
      lfo.freq = util.clamp(lfo.freq * ratio, 0.01, 32)
      _G.g.screen_dirty = true
    end
  elseif #page.params > 0 then
    local param_id = page.params[_G.g.param_focus]
    if param_id == "frequency" or param_id == "lpf_cutoff" or param_id == "hpf_cutoff" then
      step_cents(param_id, delta)
    else
      step_accel(param_id, delta)
    end
  end
end

function Pages.draw_current()
  local page = Pages.page_list[_G.g.current_page]
  if page.name == "SNAPSHOTS" then
    Pages.draw_snapshot_page()
  elseif page.lfo_id then
    Pages.draw_lfo_page(page.lfo_id)
  else
    Pages.draw_param_page()
  end
  Pages.draw_page_indicators()
end

function Pages.draw_param_page()
  local page = Pages.page_list[_G.g.current_page]
  screen.level(15)
  screen.move(64, 15)
  screen.text_center(page.name)
  if #page.params == 0 then
    screen.level(4)
    screen.move(64, 35)
    screen.text_center("No parameters")
    return
  end
  local y_start = 25
  local y_spacing = 9
  for i, param_id in ipairs(page.params) do
    local y = y_start + (i - 1) * y_spacing
    local param = params:lookup_param(param_id)
    screen.level(i == _G.g.param_focus and 15 or 4)
    screen.move(4, y)
    local name = param.name
    if #name > 14 then name = string.sub(name, 1, 11) .. "..." end
    screen.text(name)
    screen.move(124, y)
    screen.text_right(param:string())
  end
end

function Pages.draw_lfo_page(lfo_id)
  local lfo = LFOs.data[lfo_id]
  if not lfo then return end

  local wave_str = (lfo.wave == LFOs.WAVE_TRI) and "TRIA" or "SLEW"
  
  screen.level(0)
  screen.rect(0, 0, 128, 64)
  screen.fill()
  screen.level(15)
  
  -- Title line
  screen.move(5, 10)
  screen.text("LFO " .. lfo_id)
  screen.move(124, 10)
  screen.text_right(wave_str .. " " .. string.format("%.2fHz", lfo.freq))
  
  -- Scope rect
  screen.rect(10, 20, 108, 25)
  screen.stroke()
  
  -- Draw scope (real voltage, like ncoco draw_scope)
  Pages.draw_lfo_scope(lfo, 10, 20, 108, 25)
  
  -- Controls
  screen.level(4)
  screen.move(2, 55)
  screen.text("E2/E3:freq")
  screen.move(64, 55)
  screen.text("K2:" .. wave_str)
  screen.move(124, 55)
  screen.text_right("K3:next")
end

-- Real voltage scope, copied from ncoco draw_scope (ui.lua:39-56)
function Pages.draw_lfo_scope(lfo, x, y, w, h)
  local hist = lfo.history
  local head = lfo.history_head
  local len = 128
  screen.level(15)
  local last_px, last_py = nil, nil
  for i = 0, w - 1 do
    if i < len then
      local idx = (head - 1 - i - 1) % len + 1
      local val = util.clamp(hist[idx], -1, 1)
      local px = x + w - i
      local py = y + h - (util.clamp((val + 1) / 2, 0, 1) * h)
      if last_px then
        screen.move(last_px, last_py)
        screen.line(px, py)
      else
        screen.pixel(px, py)
      end
      last_px = px
      last_py = py
    end
  end
  screen.stroke()
end

function Pages.draw_snapshot_page()
  screen.level(15)
  screen.move(64, 15)
  screen.text_center("SNAPSHOTS")
  screen.level(4)
  screen.move(2, 24)
  screen.text("E2: select  K3: load  K1+K3: save")
  local y_start = 33
  local y_spacing = 9
  local view_start = math.max(1, math.min(_G.g.preset_focus - 1, Snapshots.num_slots - 3))
  for i = 0, 3 do
    local slot = view_start + i
    if slot >= 1 and slot <= Snapshots.num_slots then
      local y = y_start + i * y_spacing
      local info = Snapshots.get_slot_info(slot)
      screen.level(slot == _G.g.preset_focus and 15 or 8)
      screen.move(4, y)
      screen.text(string.format("%02d", slot))
      screen.level(info.exists and 15 or 4)
      screen.move(20, y)
      local name = info.name
      if #name > 18 then name = string.sub(name, 1, 15) .. "..." end
      screen.text(name)
      if Snapshots.current_slot == slot then
        screen.level(15)
        screen.move(122, y)
        screen.text("*")
      end
    end
  end
end

function Pages.draw_page_indicators()
  local total = #Pages.page_list
  local current = _G.g.current_page
  local dot_spacing = 6
  local start_x = 64 - ((total - 1) * dot_spacing) / 2
  
  for i = 1, total do
    local x = start_x + (i - 1) * dot_spacing
    screen.level(i == current and 11 or 3)
    screen.move(x, 62)
    screen.text("•")
  end
end

return Pages