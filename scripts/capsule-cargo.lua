-- Kapsel-Steuerung (jede Sekunde aus control.lua fuer alle Versorgungskapseln):
--   1. Ladung pro Planet: Die Kapsel hat kein festes Rezept. Sie bekommt die Ladung ihres Planeten (aus dessen
--      Rohstoffen), auf anderen Planeten die generische (nur Strom, langsam). Setzt das Rezept neu, wenn es nicht
--      passt (neu gebaut, nach dem Traglast-Tausch oder im GUI verstellt).
--   2. Ueberschuss an Zutaten wird zur Fracht: Die Zutaten sind oft genau das, was man hochschicken will. Die Kapsel
--      behaelt nur den Bedarf fuer KEEP_LOADS Ladungen, der Rest kommt in den Frachtraum der Rakete (die Traglast
--      begrenzt, wie viel hineinpasst).

local surface_planet = require("scripts.surface-planet")

local capsule_cargo = {}

local KEEP_LOADS = 2

local LOAD_BY_PLANET =
{
  nauvis = "ncs-supply-capsule-load",
  vulcanus = "ncs-supply-capsule-load-vulcanus",
  gleba = "ncs-supply-capsule-load-gleba",
  fulgora = "ncs-supply-capsule-load-fulgora"
}
local GENERIC_LOAD = "ncs-supply-capsule-load-generic"

local function load_for(surface)
  return LOAD_BY_PLANET[surface_planet.name(surface)] or GENERIC_LOAD
end

local function ensure_recipe(capsule)
  local wanted = load_for(capsule.surface)
  local current = capsule.get_recipe()
  if not current or current.name ~= wanted then
    capsule.set_recipe(wanted)
  end
  return prototypes.recipe[wanted]
end

local function move_excess(capsule, recipe)
  local input = capsule.get_inventory(defines.inventory.crafter_input)
  if not input or input.is_empty() then return end
  local rocket_inventory = capsule.get_inventory(defines.inventory.rocket_silo_rocket)
  if not rocket_inventory then return end
  local contents = input.get_contents()
  for _, ingredient in pairs(recipe.ingredients) do
    if ingredient.type == "item" then
      for _, stack in pairs(contents) do
        if stack.name == ingredient.name then
          local excess = stack.count - ingredient.amount * KEEP_LOADS
          if excess > 0 then
            local moved = rocket_inventory.insert{name = stack.name, quality = stack.quality, count = excess}
            if moved > 0 then
              input.remove{name = stack.name, quality = stack.quality, count = moved}
            end
          end
        end
      end
    end
  end
end

-- Kapseln werden gemerkt (storage.capsules), statt jede Sekunde alle Planeten zu durchsuchen (Optimierung 1.24.1).
-- Neue kommen beim Bauen dazu (capsule_cargo.add aus control.lua); alle RESCAN Ticks einmal komplett nachzaehlen,
-- falls eine per Skript (z. B. Traglast-Tausch) ohne Ereignis entstanden ist.
local RESCAN = 600

function capsule_cargo.add(entity)
  storage.capsules = storage.capsules or {}
  if entity and entity.valid and entity.unit_number then storage.capsules[entity.unit_number] = entity end
end

-- names = alle Kapsel-Namen inkl. Traglast-Varianten
function capsule_cargo.update_all(names)
  storage.capsules = storage.capsules or {}
  if game.tick >= (storage.capsules_rescan or 0) then
    storage.capsules_rescan = game.tick + RESCAN
    storage.capsules = {}
    for _, surface in pairs(game.surfaces) do
      if not surface.platform then
        for _, capsule in pairs(surface.find_entities_filtered{name = names}) do
          storage.capsules[capsule.unit_number] = capsule
        end
      end
    end
  end
  for id, capsule in pairs(storage.capsules) do
    if capsule.valid then
      move_excess(capsule, ensure_recipe(capsule))
    else
      storage.capsules[id] = nil
    end
  end
end

return capsule_cargo
