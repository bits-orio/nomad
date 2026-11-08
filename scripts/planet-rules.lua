-- Variante A: Fabriken auf Planeten per Forschung (Liste aus prototypes/variant-a.lua, mod-data "ncs-planet-rules").
-- Ob ein Gebaeude auf einer Oberflaeche stehen darf, kann Factorio nicht an eine Forschung knuepfen. Deshalb wird
-- ein gesperrtes Gebaeude auf einem Planeten sofort wieder abgebaut (Item zurueck an Spieler bzw. Roboter), ein
-- gesperrter Geist entfernt, mit Hinweis auf die noetige Forschung. Im All gilt nichts davon.

local planet_rules = {}

-- Typen der betroffenen Fabriken (fuer die Ereignis-Filter)
local TYPES = {"assembling-machine", "furnace", "beacon"}

planet_rules.FILTER = {}
for _, type_name in pairs(TYPES) do
  table.insert(planet_rules.FILTER, {filter = "type", type = type_name})
  table.insert(planet_rules.FILTER, {filter = "ghost_type", type = type_name})
end

local gated_cache
local function gated()
  if gated_cache == nil then
    local mod_data = prototypes.mod_data["ncs-planet-rules"]
    gated_cache = mod_data and mod_data.data.gated or false
  end
  return gated_cache
end

-- Noetige Forschung, wenn das Gebaeude hier (noch) gesperrt ist, sonst nil
local function blocking_tech(entity)
  local list = gated()
  if not list then return nil end
  local surface = entity.surface
  if surface.platform or not surface.planet then return nil end
  local name = entity.type == "entity-ghost" and entity.ghost_name or entity.name
  local tech_name = list[name]
  if not tech_name then return nil end
  local tech = entity.force.technologies[tech_name]
  if tech and tech.researched then return nil end
  return tech_name
end

local function notify(player, entity, tech_name)
  if not (player and player.valid) then return end
  player.create_local_flying_text{text = {"ncs-planet-rules.blocked", "[technology=" .. tech_name .. "]"},
    position = entity.position, create_at_cursor = true}
  player.print({"ncs-planet-rules.blocked", "[technology=" .. tech_name .. "]"})
end

function planet_rules.on_built(event)
  local entity = event.entity
  if not (entity and entity.valid) then return end
  -- Nur Bauen durch Spieler und Roboter, nicht Skripte anderer Mods
  if not (event.player_index or event.robot) then return end
  local tech_name = blocking_tech(entity)
  if not tech_name then return end

  local player = event.player_index and game.get_player(event.player_index)
  if entity.type == "entity-ghost" then
    notify(player, entity, tech_name)
    entity.destroy()
    return
  end

  notify(player, entity, tech_name)
  if player and player.valid then
    if not player.mine_entity(entity, true) and entity.valid then entity.destroy() end
  elseif event.robot and event.robot.valid then
    local cargo = event.robot.get_inventory(defines.inventory.robot_cargo)
    if not entity.mine{inventory = cargo, force = true, ignore_minable = true} and entity.valid then entity.destroy() end
  else
    entity.destroy()
  end
end

return planet_rules
