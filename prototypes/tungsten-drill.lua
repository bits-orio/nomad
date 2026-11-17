-- Elektrischer Bohrer auf Wolframerz (Daten: scripts/tungsten-drill-config.lua, Laufzeit: scripts/tungsten-drill.lua).
-- Der Bohrer bekommt "hard-solid", sonst laesst er sich auf Wolframerz gar nicht platzieren. Das Tempo haengt im
-- Prototyp nicht vom Erz ab, deshalb die versteckte langsame Variante (gleiches Item, gleiche Grafik).

local config = require("scripts.tungsten-drill-config")

local base = data.raw["mining-drill"][config.BASE]
if not (base and data.raw["resource-category"]["hard-solid"]) then return end

local has_hard = false
for _, category in pairs(base.resource_categories) do
  if category == "hard-solid" then has_hard = true end
end
if not has_hard then table.insert(base.resource_categories, "hard-solid") end

local description = {"entity-description.ncs-hard-drill"}
base.localised_description = {"", base.localised_description or {"entity-description." .. config.BASE}, "\n", description}

local variant = table.deepcopy(base)
variant.name = config.VARIANT
variant.localised_name = base.localised_name or {"entity-name." .. config.BASE}
variant.localised_description = table.deepcopy(base.localised_description)
variant.mining_speed = base.mining_speed * config.SPEED_FACTOR
variant.placeable_by = {item = config.BASE, count = 1}
variant.minable = {mining_time = (base.minable and base.minable.mining_time) or 0.3, result = config.BASE}
variant.hidden = true
variant.hidden_in_factoriopedia = true
variant.factoriopedia_alternative = config.BASE
variant.factoriopedia_simulation = nil
variant.next_upgrade = nil

-- Forschung (Wunsch des Users): erst danach duerfen elektrische Bohrer auf Wolframerz stehen
-- (Sperre per Skript, die Platzierung haengt im Prototyp nicht an Forschung).
local technology =
{
  type = "technology",
  name = config.TECH,
  icons =
  {
    {icon = "__base__/graphics/technology/electric-mining-drill.png", icon_size = 256},
    {icon = "__space-age__/graphics/icons/tungsten-ore.png", icon_size = 64, scale = 0.6, shift = {40, 40}}
  },
  effects = {{type = "nothing", effect_description = {"ncs-tech.tungsten-drilling"}, icon = "__space-age__/graphics/icons/tungsten-ore.png", icon_size = 64}},
  prerequisites = {"planet-discovery-vulcanus"},
  unit =
  {
    count = config.TECH_COUNT,
    ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}},
    time = 30
  },
  order = "z[ncs]-t[tungsten-drilling]"
}

data:extend({variant, technology})
