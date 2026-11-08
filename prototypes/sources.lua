-- Schiffs-Quellen (Fulgora: Schrott-Ader, Aquilo: Lithium- und Fluor-Quelle), Daten in scripts/sources-config.lua.
-- Das Item stellt eine Markierung (3x3) aufs Fundament; scripts/sources.lua legt darunter eine unendliche
-- Lagerstaette an, die normale Bohrer bzw. Pumpen abbauen. Die Markierung blockiert keine Gebaeude (nur den leeren
-- Weltraum und andere Markierungen), Bohrer und Pumpe kommen also direkt darueber. Abbauen der Markierung entfernt
-- die Lagerstaette wieder.

local config = require("scripts.sources-config")
local costs = require("prototypes.upgrade-costs")

local SPACE_ONLY = {{property = "pressure", max = 0}, {property = "gravity", max = 0}}

local prototypes_list = {}
for _, source in pairs(config.sources) do
  local icons = {{icon = source.icon, icon_size = 64, tint = source.tint}}

  -- Unendliche Lagerstaette: Kopie des Vanilla-Rohstoffs, die nie weniger wird.
  local resource = table.deepcopy(data.raw.resource[source.template])
  resource.name = source.resource
  resource.localised_name = {"entity-name." .. source.item}
  resource.autoplace = nil
  resource.infinite = true
  resource.minimum = source.amount
  resource.normal = source.amount
  resource.infinite_depletion_amount = 0
  resource.factoriopedia_simulation = nil
  resource.hidden_in_factoriopedia = true
  table.insert(prototypes_list, resource)

  table.insert(prototypes_list,
  {
    type = "simple-entity-with-owner",
    name = source.marker,
    localised_name = {"entity-name." .. source.item},
    localised_description = {"entity-description." .. source.item},
    icons = icons,
    flags = {"placeable-neutral", "player-creation"},
    minable = {mining_time = 1, result = source.item},
    max_health = 500,
    collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
    selection_priority = 40, -- Bohrer und Pumpen darueber haben Vorrang
    collision_mask = {layers = {empty_space = true}},
    render_layer = "decorative",
    picture = {filename = source.icon, size = 64, scale = 0.6, tint = source.tint},
    surface_conditions = table.deepcopy(SPACE_ONLY)
  })

  table.insert(prototypes_list,
  {
    type = "item",
    name = source.item,
    icons = icons,
    subgroup = "space-platform",
    order = "z[ncs]-c[source]-" .. source.item,
    place_result = source.marker,
    stack_size = 1,
    weight = 100000
  })
  -- Seit 1.24.0 kein Rezept mehr: Quellen kommen nur aus dem Boden-Extraktor (prototypes/extractor.lua).
end

-- Freischalt-Forschungen: erlauben den Abbau der Quelle (bzw. des Bodens) mit dem Extraktor, einmalig.
-- Die Effekte setzt prototypes/extractor.lua.
for _, chain in pairs(config.chains) do
  table.insert(prototypes_list,
  {
    type = "technology",
    name = chain.technology,
    icon = chain.icon,
    icon_size = 256,
    effects = {},
    prerequisites = {chain.pack},
    unit = costs.unit(chain.pack)
  })
end

data:extend(prototypes_list)
