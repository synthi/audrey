-- pages.lua
-- v7.2.0 - 10 pages (6 synth + 4 LFO) + page indicators + LFO pages

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
  {name = "SNAPSHOTS", params = {}}
}

Pages.lfo_cursor = {1, 1, 1, 1}

function Pages.init()
  _G.g.current_page = 1
  _G.g.param_focus = 1
  _G.g.preset_focus = 1
  Pages.lfo_cursor = {1, 1, 1, 1}
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
    local Snapshots = require("audrey/lib/snapshots")
    _G.g.preset_focus = util.clamp(_G.g.preset_focus + delta, 1, Snapshots.num_slots)
  elseif page.lfo_id then
    local LFOs = require("audrey/lib/lfos")
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
    local LFOs = require("audrey/lib/lfos")
    local lfo = LFOs.data[page.lfo_id]
    if lfo then
      local sign = (delta > 0) and 1 or -1
      local cents = (math.abs(delta) ^ 3.5) * 1.5
      local ratio = 2 ^ (sign * cents / 1200)
      lfo.freq = util.clamp(lfo.freq * ratio, 0.01, 100)
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
  local LFOs = require("audrey/lib/lfos")
  local lfo = LFOs.data[lfo_id]
  if not lfo then return end

  local wave_str = (lfo.wave == LFOs.WAVE_TRI) and "TRIA" or "PERL"
  local enabled_str = lfo.enabled and "ON" or "OFF"
  
  screen.level(15)
  screen.move(64, 15)
  screen.text_center("LFO " .. lfo_id .. "  " .. wave_str .. " " .. string.format("%.2f", lfo.freq) .. "Hz " .. enabled_str)
  
  screen.level(4)
  screen.move(2, 24)
  screen.text("E2:sel E3:dp K1:DEL K2:WAVE K3:ON/OFF")
  
  local assignments = lfo.assignments
  if #assignments == 0 then
    screen.level(4)
    screen.move(64, 38)
    screen.text_center("No assignments")
    screen.move(64, 46)
    screen.text_center("Hold LFO"..lfo_id.." + tap knob to assign")
  else
    local y_start = 33
    local y_spacing = 9
    local cursor = Pages.lfo_cursor[lfo_id]
    local view_start = math.max(1, cursor - 2)
    local max_visible = 5
    local visible_count = math.min(#assignments - view_start + 1, max_visible)
    
    for vi = 0, visible_count - 1 do
      local ai = view_start + vi
      if ai <= #assignments then
        local a = assignments[ai]
        local y = y_start + vi * y_spacing
        
        screen.level((ai == cursor) and 15 or 8)
        local param = params:lookup_param(a[1])
        local pname = param and param.name or a[1]
        if #pname > 16 then pname = string.sub(pname, 1, 13) .. "..." end
        screen.move(4, y)
        screen.text(pname)
        screen.move(124, y)
        screen.text_right(a[3] .. " " .. string.format("%.3f", a[2]))
      end
    end
    
    if #assignments > max_visible then
      screen.level(4)
      if cursor > 2 then
        screen.move(127, 38)
        screen.text("^")
      end
      if cursor < #assignments then
        screen.move(127, 58)
        screen.text("v")
      end
    end
  end
end

function Pages.draw_snapshot_page()
  local Snapshots = require("audrey/lib/snapshots")
  screen.level(15)
  screen.move(64, 15)
  screen.text_center("SNAPSHOTS")
  screen.level(4)
  screen.move(2, 24)
  screen.text("E2: select  K3: load  K1+K3: save")
  local y_start = 33
  local y_spacing = 9
  local view_start = math.max(1, _G.g.preset_focus - 2)
  for i = 0, 3 do
    local slot = view_start + i
    if slot <= Snapshots.num_slots then
      local y = y_start + (i * y_spacing)
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