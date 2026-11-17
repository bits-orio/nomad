-- Elektrischer Bohrer auf Wolframerz (Daten: scripts/tungsten-drill-config.lua, Prototypen: prototypes/tungsten-drill.lua).
-- Beim Bauen: Liegt hard-solid-Erz im Abbaugebiet, wird der Bohrer gegen die langsame Variante getauscht, sonst
-- zurueck. Auch nach dem Setzen einer Schiffs-Quelle (Wolfram-Ader) werden die Bohrer darueber geprueft.
-- Jede Sekunde verliert jede arbeitende Variante etwas Leben (Reparaturpakete helfen), bei 0 geht sie kaputt.

local config = require("scripts.tungsten-drill-config")

local drill = {}

drill.FILTER =
{
  {filter = "name", name = config.BASE},
  {filter = "name", name = config.VARIANT}
}

local hard_resources = nil
local function hard_names()
  if not hard_resources then
    hard_resources = {}
    for name, proto in pairs(prototypes.get_entity_filtered{{filter = "type", type = "resource"}}) do
      if proto.resource_category == "hard-solid" then table.insert(hard_resources, name) end
    end
  end
  return hard_resources
end

local function on_hard(entity)
  local names = hard_names()
  if #names == 0 then return false end
  return entity.surface.count_entities_filtered{area = entity.mining_area, type = "resource", name = names, limit = 1} > 0
end

local function track(entity)
  storage.hard_drills[entity.unit_number] = entity
end

local function update(entity)
  if not (entity and entity.valid) then return end
  if entity.name ~= config.BASE and entity.name ~= config.VARIANT then return end
  local target = on_hard(entity) and config.VARIANT or config.BASE
  if entity.name == target then
    if target == config.VARIANT then track(entity) end
    return
  end

  local modules = {}
  local module_inventory = entity.get_module_inventory()
  if module_inventory then modules = module_inventory.get_contents() end
  local health_ratio = entity.health / entity.max_health
  storage.hard_drills[entity.unit_number] = nil

  local new = entity.surface.create_entity{name = target, position = entity.position, direction = entity.direction,
    quality = entity.quality, force = entity.force, fast_replace = true, spill = false,
    create_build_effect_smoke = false, raise_built = false}
  if not new then
    log("[nomad] Bohrer-Tausch fehlgeschlagen: " .. target .. " bei " .. serpent.line(entity.position))
    return
  end
  new.health = new.max_health * health_ratio
  local new_modules = new.get_module_inventory()
  if new_modules and new_modules.is_empty() then
    for _, stack in pairs(modules) do
      new_modules.insert{name = stack.name, count = stack.count, quality = stack.quality}
    end
  end
  if target == config.VARIANT then track(new) end
end

local function researched(force)
  local tech = force.technologies[config.TECH]
  return tech == nil or tech.researched
end

-- Ohne Forschung: Bohrer zurueckgeben (Spieler, Roboter oder Hub), Hinweis an den Spieler
local function reject(event, entity)
  local player = event.player_index and game.get_player(event.player_index)
  local text = {"ncs-tungsten-drill.blocked", "[technology=" .. config.TECH .. "]"}
  if player and player.valid then
    player.create_local_flying_text{text = text, position = entity.position, create_at_cursor = true}
    player.print(text)
    if not player.mine_entity(entity, true) and entity.valid then entity.destroy() end
  elseif event.robot and event.robot.valid then
    local cargo = event.robot.get_inventory(defines.inventory.robot_cargo)
    if not entity.mine{inventory = cargo, force = true, ignore_minable = true} and entity.valid then entity.destroy() end
  elseif event.platform and event.platform.valid and event.platform.hub and event.platform.hub.valid then
    local hub = event.platform.hub.get_inventory(defines.inventory.hub_main)
    if not entity.mine{inventory = hub, force = true, ignore_minable = true} and entity.valid then entity.destroy() end
  else
    entity.destroy()
  end
end

-- Fuer alle Bau-Ereignisse; muss als letzter Handler laufen (der Bohrer ist danach evtl. ersetzt).
-- Bauen durch Skripte anderer Mods wird nicht gesperrt, nur getauscht.
function drill.on_built(event)
  local entity = event.entity
  if not (entity and entity.valid) then return end
  if entity.name ~= config.BASE and entity.name ~= config.VARIANT then return end
  if (event.player_index or event.robot or event.platform) and not researched(entity.force) and on_hard(entity) then
    reject(event, entity)
    return
  end
  update(entity)
end

function drill.recheck_area(surface, area)
  for _, entity in pairs(surface.find_entities_filtered{area = area, name = {config.BASE, config.VARIANT}}) do
    update(entity)
  end
end

local WORKING = defines.entity_status.working
function drill.update_all()
  for key, entity in pairs(storage.hard_drills) do
    if not entity.valid then
      storage.hard_drills[key] = nil
    elseif entity.status == WORKING then
      local health = entity.health - config.DAMAGE_PER_SECOND
      if health <= 0 then
        storage.hard_drills[key] = nil
        entity.die()
      else
        entity.health = health
      end
    end
  end
end

function drill.init()
  storage.hard_drills = storage.hard_drills or {}
end

-- Nach Mod-Aenderungen: alle elektrischen Bohrer pruefen (vorher konnten sie neben Wolframerz stehen)
function drill.update_all_drills()
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{name = {config.BASE, config.VARIANT}}) do
      update(entity)
    end
  end
end

return drill
