-- Variante D "Hardcore" (seit 1.0.5, Wunsch des Users): Bis nach Vulcanus auf Planeten keine Fabriken und Oefen.
-- Jedes Fabrikgebaeude bekommt eine eigene Forschung "Planetenbau: <Gebaeude>", alle setzen Metallurgie-Science
-- voraus. Wird von prototypes/variant-a.lua aufgerufen (gleiche Erkennung der Gebaeude, gleiche Durchsetzung durch
-- scripts/planet-rules.lua). Zahlen laut Konzept vom 2026-11-15.

local costs = require("prototypes.upgrade-costs")

local hardcore = {}

local BASE = {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "space-science-pack",
  "metallurgic-science-pack"}

-- Gebaeude -> Anzahl und zusaetzliche Packs. "all" = alle Packs bis Kryo.
local TIERS =
{
  -- I Grundversorgung
  ["stone-furnace"] = {count = 500},
  ["assembling-machine-1"] = {count = 500},
  ["steel-furnace"] = {count = 1000},
  ["assembling-machine-2"] = {count = 1500},
  ["chemical-plant"] = {count = 1500},
  ["oil-refinery"] = {count = 2000},
  -- II Ausbau
  ["electric-furnace"] = {count = 3000},
  ["foundry"] = {count = 5000},
  ["centrifuge"] = {count = 5000, packs = {"production-science-pack"}},
  ["assembling-machine-3"] = {count = 5000, packs = {"production-science-pack"}},
  ["beacon"] = {count = 8000, packs = {"production-science-pack", "utility-science-pack"}},
  -- III Space Age
  ["recycler"] = {count = 5000, packs = {"electromagnetic-science-pack"}},
  ["electromagnetic-plant"] = {count = 10000, packs = {"electromagnetic-science-pack"}},
  ["biochamber"] = {count = 10000, packs = {"agricultural-science-pack"}},
  ["cryogenic-plant"] = {count = 20000, all = true},
}
local DEFAULT = {count = 10000, all = true}

-- Forschung, die ein Pack freischaltet (im Grundspiel gleichnamig)
local function pack_tech(pack)
  return data.raw.technology[pack] and pack or nil
end

-- Item, das das Gebaeude platziert
local function placing_item(entity_name)
  for _, items in pairs(data.raw) do
    for item_name, item in pairs(items) do
      if type(item) == "table" and item.place_result == entity_name then return item_name, item end
    end
  end
end

-- Forschung, die das Rezept des Items freischaltet (nil, wenn es ab Start da ist)
local function unlocking_tech(item_name)
  local recipes = {}
  local own_recipe = data.raw.recipe[item_name]
  if own_recipe then
    if own_recipe.enabled ~= false then return nil end -- ab Start (Steinofen)
    recipes[item_name] = true
  else
    -- Recycling-Rezepte liefern auch Gebaeude, zaehlen aber nicht
    for recipe_name, recipe in pairs(data.raw.recipe) do
      if not string.find(recipe_name, "%-recycling$") then
        for _, result in pairs(recipe.results or {}) do
          if result.name == item_name then recipes[recipe_name] = true end
        end
      end
    end
  end
  for tech_name, tech in pairs(data.raw.technology) do
    for _, effect in pairs(tech.effects or {}) do
      if effect.type == "unlock-recipe" and recipes[effect.recipe] then return tech_name end
    end
  end
end

local function item_icons(item)
  if item and item.icons then return table.deepcopy(item.icons) end
  if item and item.icon then return {{icon = item.icon, icon_size = item.icon_size or 64}} end
  return {{icon = "__base__/graphics/icons/assembling-machine-1.png", icon_size = 64}}
end

-- Legt die Forschung fuer ein Gebaeude an und gibt ihren Namen zurueck.
-- Name endet nicht auf eine Zahl, sonst haelt Factorio sie fuer eine Stufen-Forschung (assembling-machine-2).
function hardcore.tech_for(entity_name, prototype)
  local tech_name = "ncs-planet-" .. entity_name .. "-build"
  if data.raw.technology[tech_name] then return tech_name end
  local tier = TIERS[entity_name] or DEFAULT

  local unit
  if tier.all then
    unit = costs.unit("cryogenic-science-pack")
  else
    local ingredients = {}
    for _, pack in pairs(BASE) do table.insert(ingredients, {pack, 1}) end
    for _, pack in pairs(tier.packs or {}) do table.insert(ingredients, {pack, 1}) end
    unit = {ingredients = ingredients, time = 60}
  end
  unit.count = tier.count

  local prerequisites = {"metallurgic-science-pack"}
  for _, ingredient in pairs(unit.ingredients) do
    local tech = pack_tech(ingredient[1])
    if tech and tech ~= "metallurgic-science-pack" and tech ~= "automation-science-pack" then
      table.insert(prerequisites, tech)
    end
  end
  local item_name, item = placing_item(entity_name)
  local own = item_name and unlocking_tech(item_name)
  if own and own ~= tech_name then table.insert(prerequisites, own) end

  -- Gebaeude gross, Planet in der Ecke (Forschungsbilder 256, Item-Bilder 64: Ebenen x4)
  local icons = {}
  for _, layer in pairs(item_icons(item)) do
    local size = layer.icon_size or 64
    layer.icon_size = size
    layer.scale = (layer.scale or (32 / size)) * 4
    if layer.shift then layer.shift = {layer.shift[1] * 4, layer.shift[2] * 4} end
    table.insert(icons, layer)
  end
  table.insert(icons, {icon = "__base__/graphics/icons/nauvis.png", icon_size = 64, scale = 0.75, shift = {38, 38}})

  local entity_label = prototype.localised_name or {"entity-name." .. entity_name}
  data:extend({{
    type = "technology",
    name = tech_name,
    localised_name = {"ncs-tech.planet-build", entity_label},
    localised_description = {"ncs-tech.planet-build-description", entity_label},
    icons = icons,
    effects = {{type = "nothing", effect_description = {"ncs-tech.planet-build-effect", "[entity=" .. entity_name .. "]"}}},
    prerequisites = prerequisites,
    unit = unit,
    order = "z[ncs]-q[planet-build]-" .. string.format("%06d", tier.count) .. "-" .. entity_name
  }})
  return tech_name
end

return hardcore
