-- pages.lua
-- v6.0.0 - Page navigation with grid sync
-- 6 pages organized by function (matching 11 params of C++ original)

local Pages = {}

Pages.page_list = {
  {name = "SYNTHESIS", params = {"frequency", "feedback_gain", "feedback_body_delay"}},
  {name = "FILTERS", params = {"lpf_cutoff", "hpf_cutoff"}},
  {name = "REVERB", params = {"reverb_mix", "reverb_decay"}},
  {name = "ECHO", params = {"echo_send", "echo_time", "echo_feedback"}},
  {name = "OUTPUT", params = {"master_level"}},
  {name = "PRESETS", params = {}}
}

function Pages.init()
  _G.g.current_page = 1
  _G.g.param_focus = 1
  _G.g.preset_focus = 1
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
    local Presets = require("audrey/lib/snapshots")
    _G.g.preset_focus = util.clamp(_G.g.preset_focus + delta, 1, Snapshots.num_slots)
  else
    if #page.params > 0 then
      _G.g.param_focus = util.clamp(_G.g.param_focus + delta, 1, #page.params)
    end
  end
end

function Pages.adjust_focused_param(delta)
  local page = Pages.page_list[_G.g.current_page]
  if page.name == "SNAPSHOTS" then return end
  if #page.params > 0 then
    local param_id = page.params[_G.g.param_focus]
    params:delta(param_id, delta)
  end
end

function Pages.draw_current()
  local page = Pages.page_list[_G.g.current_page]
  if page.name == "SNAPSHOTS" then
    Pages.draw_snapshot_page()
  else
    Pages.draw_param_page()
  end
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

function Pages.draw_snapshot_page()
  local Presets = require("audrey/lib/snapshots")
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

  end
end

return Pages
