-- Info-Fenster "Mutterschiff": aktueller Stand und alle Upgrades des Mods mit ihrem Status.
-- Oeffnen ueber den Knopf in der Shortcut-Leiste oder /schiff. Klick auf ein Upgrade oeffnet es im Forschungsbaum.
-- Zusaetzlich: Chat-Hinweis, sobald ein neues Upgrade erforschbar wird.

local floors = require("scripts.floors")
local sources = require("scripts.sources")

local info = {}

local SHORTCUT = "ncs-mothership-info"
local FRAME = "ncs_mothership_info"
local CLOSE = "ncs_mothership_info_close"
local TECH_BUTTON = "ncs_info_tech"

local COLOR_DONE = {r = 0.5, g = 0.9, b = 0.5}
local COLOR_READY = {r = 1, g = 0.85, b = 0.3}
local COLOR_LOCKED = {r = 0.75, g = 0.75, b = 0.75}

-- Upgrade-Gruppen in Anzeigereihenfolge; Technologien werden ueber ihren Namensanfang zugeordnet.
local GROUPS =
{
  {caption = "start", prefixes = {"ncs-spacesuit"}},
  {caption = "floors", prefixes = {"ncs-lava-zone", "ncs-bio-zone", "ncs-jellynut-zone", "ncs-ammonia-zone", "ncs-scrap-vein", "ncs-lithium-source",
    "ncs-fluorine-source", "ncs-tungsten-vein", "ncs-calcite-vein", "ncs-oil-source", "ncs-uranium-vein",
    "ncs-promethium-zone"}},
  {caption = "planets", prefixes = {"ncs-planet-factories", "ncs-planet-industry"}},
  {caption = "transport", prefixes = {"ncs-rocket-capacity-", "ncs-thruster-boost-", "ncs-large-cargo-bay", "ncs-recall-beam"}},
  {caption = "lategame", prefixes = {"ncs-living-metal", "ncs-promethium-drive"}}
}

local function starts_with(text, prefix)
  return string.sub(text, 1, #prefix) == prefix
end

local function group_techs(force, group)
  local list = {}
  for name, tech in pairs(force.technologies) do
    for _, prefix in pairs(group.prefixes) do
      if starts_with(name, prefix) then
        table.insert(list, tech)
        break
      end
    end
  end
  table.sort(list, function(a, b)
    if a.prototype.order ~= b.prototype.order then return a.prototype.order < b.prototype.order end
    return a.name < b.name
  end)
  return list
end

local function missing_prerequisites(tech)
  local missing = {}
  for name, prerequisite in pairs(tech.prerequisites) do
    if not prerequisite.researched then
      table.insert(missing, "[technology=" .. name .. "]")
    end
  end
  return missing
end

-- Status: "done", "ready" (erforschbar) oder "locked"
local function status_of(tech)
  if tech.researched then return "done" end
  if #missing_prerequisites(tech) == 0 then return "ready" end
  return "locked"
end

local function add_status(flow, force)
  local ship = storage.ships[force.index]
  if not (ship and ship.valid) then ship = nil end
  local table_element = flow.add{type = "table", column_count = 2}
  local function row(label, value)
    table_element.add{type = "label", caption = label, style = "caption_label"}
    table_element.add{type = "label", caption = value}
  end
  row({"ncs-info.mass"}, {"ncs-info.mass-value", ship and math.floor(ship.weight / 1000) or "-"})
  for _, floor in pairs(floors.status(force)) do
    row({"", "[item=" .. floor.name .. "] ", {"item-name." .. floor.name}},
      floor.unlocked and {"ncs-info.floor-value", floor.used} or {"ncs-info.locked"})
  end
  for _, source in pairs(sources.status(force)) do
    row({"", "[item=" .. source.name .. "] ", {"item-name." .. source.name}},
      source.unlocked and {"ncs-info.source-value", source.used} or {"ncs-info.locked"})
  end
end

local function add_tech_row(parent, tech)
  local status = status_of(tech)
  local row = parent.add{type = "flow", direction = "horizontal"}
  row.style.vertical_align = "center"
  row.add{type = "sprite-button", sprite = "technology/" .. tech.name, style = "slot_button",
    tags = {[TECH_BUTTON] = tech.name}, tooltip = {"ncs-info.open-tech"}}
  local caption = tech.localised_name
  if tech.prototype.max_level and tech.prototype.max_level > 1 then
    caption = {"", tech.localised_name, " (", {"ncs-info.level", tech.level}, ")"}
  end
  local name_label = row.add{type = "label", caption = caption}
  name_label.style.width = 260
  local text
  if status == "done" then
    text = {"ncs-info.done"}
  elseif status == "ready" then
    text = {"ncs-info.ready"}
  else
    text = {"ncs-info.needs", table.concat(missing_prerequisites(tech), " ")}
  end
  local status_label = row.add{type = "label", caption = text}
  status_label.style.font_color = status == "done" and COLOR_DONE or (status == "ready" and COLOR_READY or COLOR_LOCKED)
end

function info.close(player)
  local frame = player.gui.screen[FRAME]
  if frame then frame.destroy() end
end

function info.open(player)
  info.close(player)
  local frame = player.gui.screen.add{type = "frame", name = FRAME, direction = "vertical"}
  frame.auto_center = true

  local titlebar = frame.add{type = "flow", direction = "horizontal"}
  titlebar.drag_target = frame
  titlebar.add{type = "label", caption = {"ncs-info.title"}, style = "frame_title", ignored_by_interaction = true}
  local filler = titlebar.add{type = "empty-widget", style = "draggable_space_header", ignored_by_interaction = true}
  filler.style.height = 24
  filler.style.horizontally_stretchable = true
  titlebar.add{type = "sprite-button", name = CLOSE, sprite = "utility/close", style = "frame_action_button"}

  local inner = frame.add{type = "frame", direction = "vertical", style = "inside_shallow_frame_with_padding"}
  add_status(inner, player.force)

  local scroll = inner.add{type = "scroll-pane", direction = "vertical"}
  scroll.style.maximal_height = 500
  scroll.style.top_margin = 8
  for _, group in pairs(GROUPS) do
    local techs = group_techs(player.force, group)
    if #techs > 0 then
      local header = scroll.add{type = "label", caption = {"ncs-info.group-" .. group.caption}, style = "caption_label"}
      header.style.top_margin = 6
      for _, tech in pairs(techs) do
        add_tech_row(scroll, tech)
      end
    end
  end
end

function info.toggle(player)
  if player.gui.screen[FRAME] then info.close(player) else info.open(player) end
end

-- Offene Fenster der Force neu aufbauen
function info.refresh(force)
  for _, player in pairs(force.players) do
    if player.gui.screen[FRAME] then info.open(player) end
  end
end

function info.on_lua_shortcut(event)
  if event.prototype_name == SHORTCUT then
    info.toggle(game.get_player(event.player_index))
  end
end

function info.on_gui_click(event)
  local element = event.element
  if not (element and element.valid) then return end
  local player = game.get_player(event.player_index)
  if element.name == CLOSE then
    info.close(player)
  elseif element.tags and element.tags[TECH_BUTTON] then
    player.open_technology_gui(element.tags[TECH_BUTTON])
  end
end

-- Chat-Hinweis: welche Mod-Upgrades durch diese Forschung neu erforschbar wurden.
function info.on_research_finished(event)
  local research = event.research
  local force = research.force
  for _, group in pairs(GROUPS) do
    for _, tech in pairs(group_techs(force, group)) do
      if not tech.researched and tech.prerequisites[research.name] and status_of(tech) == "ready" then
        force.print({"ncs-info.new-upgrade", "[technology=" .. tech.name .. "]"})
      end
    end
  end
  info.refresh(force)
end

return info
