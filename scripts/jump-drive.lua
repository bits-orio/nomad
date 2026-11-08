-- Phase 6: Sprungantrieb.
-- Wer den Sprungantrieb oeffnet, bekommt daneben ein Fenster mit allen entdeckten Planeten.
-- Ein Klick versetzt die Plattform sofort dorthin (LuaSpacePlatform::space_location) und verbraucht
-- Promethium-Zellen aus dem Sprungantrieb. Laufende Anforderungen der Plattform werden dabei vom Spiel abgebrochen.

local jump = {}

local ENTITY = "ncs-jump-drive"
local FUEL = "ncs-promethium-cell"
local COST = 50 -- vorlaeufig
local FRAME = "ncs_jump_drive_frame"
local BUTTON_PREFIX = "ncs_jump_to_"

local function close(player)
  local frame = player.gui.relative[FRAME]
  if frame then frame.destroy() end
end

local function planets_for(force)
  local list = {}
  for name, location in pairs(prototypes.space_location) do
    if location.type == "planet" and force.is_space_location_unlocked(name) then
      table.insert(list, location)
    end
  end
  table.sort(list, function(a, b) return a.order < b.order end)
  return list
end

local function open(player, entity)
  close(player)
  local platform = entity.surface.platform
  local frame = player.gui.relative.add{
    type = "frame",
    name = FRAME,
    direction = "vertical",
    caption = {"ncs-jump.title"},
    anchor = {gui = defines.relative_gui_type.container_gui, position = defines.relative_gui_position.right, name = ENTITY}
  }
  frame.add{type = "label", caption = {"ncs-jump.cost", COST, "[item=" .. FUEL .. "]"}}
  if not platform then
    frame.add{type = "label", caption = {"ncs-jump.no-platform"}}
    return
  end
  local current = platform.space_location and platform.space_location.name
  for _, location in pairs(planets_for(player.force)) do
    frame.add{
      type = "button",
      name = BUTTON_PREFIX .. location.name,
      caption = {"", "[space-location=" .. location.name .. "] ", location.localised_name},
      enabled = location.name ~= current,
      tags = {unit_number = entity.unit_number}
    }
  end
end

function jump.on_gui_opened(event)
  local entity = event.entity
  if entity and entity.valid and entity.name == ENTITY then
    open(game.get_player(event.player_index), entity)
  end
end

function jump.on_gui_closed(event)
  local entity = event.entity
  if entity and entity.valid and entity.name == ENTITY then
    close(game.get_player(event.player_index))
  end
end

function jump.on_gui_click(event)
  local element = event.element
  if not (element and element.valid) then return end
  if string.sub(element.name, 1, #BUTTON_PREFIX) ~= BUTTON_PREFIX then return end
  local player = game.get_player(event.player_index)
  local target = string.sub(element.name, #BUTTON_PREFIX + 1)

  local entity = player.opened
  if not (entity and entity.valid and entity.object_name == "LuaEntity" and entity.name == ENTITY) then return end
  local platform = entity.surface.platform
  if not platform then return end
  if not (prototypes.space_location[target] and player.force.is_space_location_unlocked(target)) then return end

  local inventory = entity.get_inventory(defines.inventory.chest)
  if inventory.get_item_count(FUEL) < COST then
    player.print({"ncs-jump.not-enough", COST, "[item=" .. FUEL .. "]"})
    return
  end

  inventory.remove{name = FUEL, count = COST}
  platform.space_location = target
  player.force.print({"ncs-jump.done", platform.name, prototypes.space_location[target].localised_name})
  open(player, entity)
end

return jump
