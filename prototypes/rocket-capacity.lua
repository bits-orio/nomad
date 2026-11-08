-- Raketen-Traglast: Forschungen "Raketen-Traglast 1-5" erhoehen, wie viel eine Rakete ins All mitnimmt.
-- Die Traglast (lift_weight) steht fest im Prototyp des Silos, es gibt keinen Forschungs-Bonus dafuer.
-- Deshalb gibt es pro Stufe eine versteckte Variante von Raketensilo und Versorgungskapsel, die gleich aussieht
-- und mit demselben Item gebaut wird. scripts/rocket-capacity.lua tauscht die Silos gegen die Variante der
-- erforschten Stufe aus.
-- Laeuft in data-updates nach prototypes/supply-capsule.lua.

local capacity = require("scripts.rocket-capacity-config")

local DEFAULT_LIFT = data.raw["utility-constants"]["default"].default_rocket_lift_weight or 1000000

local prototypes_list = {}

for _, base_name in pairs(capacity.BASES) do
  local base = data.raw["rocket-silo"][base_name]
  local base_lift = base.lift_weight or DEFAULT_LIFT
  for level, factor in pairs(capacity.FACTORS) do
    local variant = table.deepcopy(base)
    variant.name = capacity.variant_name(base_name, level)
    variant.localised_name = base.localised_name or {"entity-name." .. base_name}
    variant.localised_description = base.localised_description or {"entity-description." .. base_name}
    variant.lift_weight = math.floor(base_lift * factor)
    variant.placeable_by = {item = base_name, count = 1}
    variant.minable = {mining_time = (base.minable and base.minable.mining_time) or 1, result = base_name}
    variant.hidden = true
    variant.hidden_in_factoriopedia = true
    variant.factoriopedia_simulation = nil
    table.insert(prototypes_list, variant)
  end
end

-- Forschungen: Stufe k setzt Stufe k-1 voraus (Stufe 1: Raketensilo). Sehr teuer, die Packs wachsen mit.
local PACKS_BY_LEVEL =
{
  {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "space-science-pack"},
  {"production-science-pack", "utility-science-pack"},
  {"metallurgic-science-pack", "electromagnetic-science-pack"},
  {"agricultural-science-pack", "cryogenic-science-pack"},
  {"promethium-science-pack"}
}

local packs = {}
for level, factor in pairs(capacity.FACTORS) do
  for _, pack in pairs(PACKS_BY_LEVEL[level] or {}) do
    table.insert(packs, {pack, 1})
  end
  table.insert(prototypes_list,
  {
    type = "technology",
    name = capacity.TECH_PREFIX .. level,
    icon = "__base__/graphics/technology/rocket-silo.png",
    icon_size = 256,
    effects =
    {
      {type = "nothing", effect_description = {"ncs-tech.rocket-capacity",
        tostring(factor * (data.raw["rocket-silo"]["rocket-silo"].lift_weight or DEFAULT_LIFT) / 1000000),
        tostring(factor * (data.raw["rocket-silo"]["ncs-supply-capsule"].lift_weight or DEFAULT_LIFT) / 1000)}}
    },
    prerequisites = {level == 1 and "rocket-silo" or capacity.TECH_PREFIX .. (level - 1)},
    unit = {count = capacity.COSTS[level], ingredients = table.deepcopy(packs), time = 60},
    upgrade = true,
    order = "z[ncs]-r[rocket-capacity]-" .. level
  })
end

data:extend(prototypes_list)
