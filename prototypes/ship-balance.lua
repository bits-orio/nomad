-- Balancing fuer das Fliegen mit grossen Schiffen (seit 1.18.0, Wunsch des Users):
--   1. Plattform-Fundament kostet ein Viertel (5 Stahl + 5 Kupferkabel statt 20 + 20).
--   2. Alle Triebwerke verbrauchen nur ein Viertel Treibstoff bei gleichem Schub.
--   3. Triebwerk-Boost 1-5: Forschungen, die das Reisetempo aller Schiffe erhoehen (seit 1.24.1 per Skript
--      in scripts/thruster-boost.lua, vorher versteckte Triebwerk-Varianten; Daten in scripts/thruster-boost-config.lua).
-- Laeuft in data-updates nach prototypes/lategame.lua (Promethium-Triebwerk muss schon existieren).

local boost = require("scripts.thruster-boost-config")

---------------------------------------------------------------------------
-- 1. Fundament

local foundation = data.raw.recipe["space-platform-foundation"]
if foundation then
  foundation.ingredients =
  {
    {type = "item", name = "steel-plate", amount = 5},
    {type = "item", name = "copper-cable", amount = 5}
  }
end

---------------------------------------------------------------------------
-- 2. Verbrauch: ein Viertel Treibstoff, Wirkungsgrad mal vier (Schub = Verbrauch x Wirkungsgrad bleibt gleich)

local FUEL_FACTOR = 0.25

for _, thruster in pairs(data.raw.thruster) do
  for _, key in pairs({"min_performance", "max_performance"}) do
    local performance = thruster[key]
    if performance then
      performance.fluid_usage = performance.fluid_usage * FUEL_FACTOR
      performance.effectivity = performance.effectivity / FUEL_FACTOR
    end
  end
  thruster.fast_replaceable_group = thruster.fast_replaceable_group or "thruster"
end

---------------------------------------------------------------------------
-- 3. Triebwerk-Boost

-- Nur Forschungen; die Wirkung (Reisetempo) setzt scripts/thruster-boost.lua zur Laufzeit.
local list = {}

local PACKS_BY_LEVEL =
{
  {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "space-science-pack"},
  {"production-science-pack", "utility-science-pack"},
  {"metallurgic-science-pack", "electromagnetic-science-pack"},
  {"agricultural-science-pack", "cryogenic-science-pack"},
  {"promethium-science-pack"}
}

local packs = {}
for level, factor in pairs(boost.FACTORS) do
  for _, pack in pairs(PACKS_BY_LEVEL[level] or {}) do
    table.insert(packs, {pack, 1})
  end
  table.insert(list,
  {
    type = "technology",
    name = boost.TECH_PREFIX .. level,
    icon = "__space-age__/graphics/technology/space-platform-thruster.png",
    icon_size = 256,
    effects = {{type = "nothing", effect_description = {"ncs-tech.thruster-boost", tostring(math.floor((factor - 1) * 100 + 0.5))}}},
    prerequisites = {level == 1 and "space-platform-thruster" or boost.TECH_PREFIX .. (level - 1)},
    unit = {count = boost.COSTS[level], ingredients = table.deepcopy(packs), time = 60},
    upgrade = true,
    order = "z[ncs]-t[thruster-boost]-" .. level
  })
end

data:extend(list)
