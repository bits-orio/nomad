-- Phase 4, Variante C (frueher B, Einstellung "space-age"): Space-Age-Gebaeude duerfen nur aufs Schiff (ins All).
-- Ausnahmen, die auf Planeten erlaubt bleiben: Recycler und Agrarturm.
-- Gebaeude aus dem Grundspiel (inkl. Assembler 3, Beacons, Module) bleiben ueberall erlaubt.
-- Erkennung: Gebaeude, die von einem Item platziert werden und deren Icon aus Space Age stammt.
-- Laeuft in data-final-fixes, damit alle Prototypen fertig sind.

if settings.startup["ncs-rules-variant"].value ~= "space-age" then return end

local EXCEPTIONS =
{
  ["recycler"] = true,
  ["agricultural-tower"] = true
}

-- Typen, die keine Gebaeude im Sinne der Regel sind
local SKIPPED_TYPES =
{
  ["plant"] = true,
  ["tree"] = true,
  ["simple-entity"] = true,
  ["unit"] = true,
  ["spider-unit"] = true,
  ["segmented-unit"] = true,
  ["unit-spawner"] = true,
  ["asteroid"] = true,
  ["corpse"] = true,
  ["character"] = true
}

local function icon_path(prototype)
  if prototype.icon then return prototype.icon end
  if prototype.icons and prototype.icons[1] then return prototype.icons[1].icon end
  return nil
end

-- Nur Space Age zaehlt. Gebaeude aus Planeten-Mods (Cerys, Maraxsis, Moshine, Corrundum) bleiben auf ihren
-- Planeten erlaubt, weil deren Fortschritt teils an Gebaeude vor Ort gebunden ist (z. B. Ruinen auf Cerys).
local EXPANSION_MODS = {"space-age"}

local function from_space_age(prototype)
  local path = icon_path(prototype)
  if not path then return false end
  for _, mod_name in pairs(EXPANSION_MODS) do
    local prefix = "__" .. mod_name .. "__/"
    if string.sub(path, 1, #prefix) == prefix then return true end
  end
  return false
end

-- Alle Entities, die ein Item platziert
local placed = {}
for _, prototypes_of_type in pairs(data.raw) do
  for _, prototype in pairs(prototypes_of_type) do
    if type(prototype) == "table" and prototype.place_result then
      placed[prototype.place_result] = true
    end
  end
end

-- Werte der Raumplattform-Oberflaeche fuer die Pruefung, ob ein Gebaeude im All ueberhaupt stehen kann
local platform_surface = data.raw.surface["space-platform"]
local function platform_value(property)
  local value = platform_surface and platform_surface.surface_properties and platform_surface.surface_properties[property]
  if value ~= nil then return value end
  local definition = data.raw["surface-property"] and data.raw["surface-property"][property]
  return definition and definition.default_value or 0
end

local function allowed_in_space(conditions)
  for _, condition in pairs(conditions or {}) do
    local value = platform_value(condition.property)
    if (condition.min and value < condition.min) or (condition.max and value > condition.max) then
      return false
    end
  end
  return true
end

local changed, skipped = {}, {}
for type_name, prototypes_of_type in pairs(data.raw) do
  if not SKIPPED_TYPES[type_name] then
    for name, prototype in pairs(prototypes_of_type) do
      -- collision_box: nur echte Gebaeude, nicht gleichnamige Items, Rezepte oder Technologien
      if type(prototype) == "table" and placed[name] and prototype.type == type_name and prototype.collision_box
        and not EXCEPTIONS[name] and string.sub(name, 1, 4) ~= "ncs-" and from_space_age(prototype) then
        if allowed_in_space(prototype.surface_conditions) then
          prototype.surface_conditions = prototype.surface_conditions or {}
          table.insert(prototype.surface_conditions, {property = "pressure", max = 0})
          table.insert(changed, name)
        else
          table.insert(skipped, name)
        end
      end
    end
  end
end

table.sort(changed)
table.sort(skipped)
log("[nomad] Variante B, nur im All: " .. table.concat(changed, ", "))
if #skipped > 0 then
  log("[nomad] Variante B, unveraendert (koennen nicht im All stehen): " .. table.concat(skipped, ", "))
end
