-- Spezialboeden fuer das Mutterschiff.
-- Sie werden wie normales Plattform-Fundament direkt ins All gelegt (eigene Items).
-- Seit 1.24.0 gibt es sie nur aus dem Boden-Extraktor (prototypes/extractor.lua), ausser dem Promethium-Boden.
--   Lava-Becken: Lava im All, eine normale Offshore-Pumpe am Rand foerdert daraus Lava.
--   Ammoniak-Becken: dasselbe mit Ammoniak-Loesung (Aquilo).
--   Bio-Boden: Gleba-Pflanzen wachsen darauf, nur hier steht der orbitale Agrarturm.
--   Promethium-Boden: nur hier stehen Materie-Rekombinator und Sprungantrieb.
-- Zahlen sind vorlaeufig und werden beim Testen festgelegt.

local foundation_tile = data.raw.tile["space-platform-foundation"]
local foundation_item = data.raw.item["space-platform-foundation"]
local FOUNDATION_ICON = "__space-age__/graphics/icons/space-platform-foundation.png"

-- ingredients = nil: kein Rezept, der Boden kommt nur aus dem Boden-Extraktor (prototypes/extractor.lua)
local function floor_item(name, tint, order, material, ingredients)
  data:extend(
  {
    {
      type = "item",
      name = name,
      -- Fundament eingefaerbt, Material klein in der Ecke (seit 1.24.1, damit jeder Boden erkennbar ist)
      icons =
      {
        {icon = FOUNDATION_ICON, icon_size = 64, tint = tint},
        {icon = material, icon_size = 64, scale = 0.25, shift = {8, 8}}
      },
      subgroup = "space-platform",
      order = "a[space-platform-foundation]-ncs-" .. order,
      inventory_move_sound = foundation_item.inventory_move_sound,
      pick_sound = foundation_item.pick_sound,
      drop_sound = foundation_item.drop_sound,
      stack_size = 100,
      weight = foundation_item.weight,
      place_as_tile =
      {
        result = name,
        condition_size = 1,
        condition = {layers = {empty_space = true}},
        invert = true
      }
    }
  })
  if ingredients then
    data:extend(
    {
      {
        type = "recipe",
        name = name,
        enabled = false,
        energy_required = 5,
        ingredients = ingredients,
        results = {{type = "item", name = name, amount = 1}}
      }
    })
  end
end

-- Boden wie Plattform-Fundament, eingefaerbt und mit eigener Kollisionsebene (fuer die Bauregeln der Gebaeude).
local function floor_tile(name, layer, tint, map_color, order)
  if not (data.raw["collision-layer"] and data.raw["collision-layer"][layer]) then
    data:extend({{type = "collision-layer", name = layer}})
  end

  local tile = table.deepcopy(foundation_tile)
  tile.name = name
  tile.order = "a[artificial]-d[utility]-c[" .. order .. "]"
  tile.tint = tint
  tile.map_color = map_color
  tile.minable = {mining_time = 0.5, result = name}
  tile.placeable_by = {item = name, count = 1}
  tile.collision_mask = table.deepcopy(tile.collision_mask)
  tile.collision_mask.layers[layer] = true
  data:extend({tile})
  return tile
end

---------------------------------------------------------------------------
-- Bio-Boeden und Promethium-Boden
-- Zwei Bio-Boeden (seit 1.14.0): hellgruen fuer Yumako ("ncs-bio-foundation", Name von frueher behalten,
-- damit alte Spielstaende ihren Boden behalten) und magenta fuer Geleenuss. Beide teilen die Ebene
-- ncs_bio_zone, auf beiden steht der orbitale Agrarturm.

-- Seit 1.24.0 ohne Rezept, nur aus dem Boden-Extraktor
floor_tile("ncs-bio-foundation", "ncs_bio_zone", {r = 0.75, g = 1, b = 0.55}, {r = 0.45, g = 0.8, b = 0.3}, "ncs-c")
floor_item("ncs-bio-foundation", {r = 0.6, g = 1, b = 0.4}, "b", "__space-age__/graphics/icons/yumako.png")

floor_tile("ncs-jellynut-foundation", "ncs_bio_zone", {r = 1, g = 0.55, b = 0.9}, {r = 0.65, g = 0.25, b = 0.55}, "ncs-c2")
floor_item("ncs-jellynut-foundation", {r = 1, g = 0.4, b = 0.85}, "b2", "__space-age__/graphics/icons/jellynut.png")

floor_tile("ncs-promethium-foundation", "ncs_promethium_zone", {r = 0.85, g = 0.7, b = 1}, {r = 0.45, g = 0.3, b = 0.6}, "ncs-e")
floor_item("ncs-promethium-foundation", {r = 0.8, g = 0.55, b = 1}, "c", "__space-age__/graphics/icons/promethium-asteroid-chunk.png",
{
  {type = "item", name = "space-platform-foundation", amount = 1},
  {type = "item", name = "promethium-asteroid-chunk", amount = 50},
  {type = "item", name = "quantum-processor", amount = 10},
  {type = "item", name = "superconductor", amount = 20},
  {type = "item", name = "ncs-living-metal", amount = 20} -- seit 1.24.1 (Wunsch des Users, 5 war zu wenig)
})

-- Gleba-Pflanzen auf Bio-Boden: Yumako nur auf dem hellgruenen, Geleenuss nur auf dem magentafarbenen.
-- Andere Pflanzen mit Erde-Boden (z. B. aus Mods) wachsen auf beiden.
for _, plant in pairs(data.raw.plant) do
  local autoplace = plant.autoplace
  if autoplace and autoplace.tile_restriction then
    local soil, yumako, jellynut = false, false, false
    for _, tile_name in pairs(autoplace.tile_restriction) do
      if type(tile_name) == "string" and string.find(tile_name, "soil", 1, true) then
        soil = true
        yumako = yumako or string.find(tile_name, "yumako", 1, true) ~= nil
        jellynut = jellynut or string.find(tile_name, "jellynut", 1, true) ~= nil
      end
    end
    if soil then
      if yumako or not jellynut then table.insert(autoplace.tile_restriction, "ncs-bio-foundation") end
      if jellynut or not yumako then table.insert(autoplace.tile_restriction, "ncs-jellynut-foundation") end
    end
  end
end

---------------------------------------------------------------------------
-- Lava-Becken: Kopie der Vulcanus-Lava, die als Plattform-Fundament zaehlt.

local pool = table.deepcopy(data.raw.tile["lava"])
pool.name = "ncs-lava-pool"
pool.order = "a[artificial]-d[utility]-c[ncs-d]"
pool.autoplace = nil
pool.default_cover_tile = nil
pool.allowed_neighbors = nil
pool.is_foundation = true
pool.weight = foundation_tile.weight
pool.minable = {mining_time = 0.5, result = "ncs-lava-pool"}
pool.placeable_by = {item = "ncs-lava-pool", count = 1}
data:extend({pool})

floor_item("ncs-lava-pool", {r = 1, g = 0.5, b = 0.2}, "a", "__space-age__/graphics/icons/fluid/lava.png") -- nur aus dem Boden-Extraktor

---------------------------------------------------------------------------
-- Ammoniak-Becken: Kopie des Aquilo-Ammoniak-Ozeans, die als Plattform-Fundament zaehlt.
-- Eine normale Offshore-Pumpe am Rand foerdert Ammoniak-Loesung. Eigene Forschung "ncs-ammonia-zone"
-- (erzeugt in prototypes/sources.lua ueber scripts/sources-config.lua).

local ammonia = table.deepcopy(data.raw.tile["ammoniacal-ocean"])
ammonia.name = "ncs-ammonia-pool"
ammonia.order = "a[artificial]-d[utility]-c[ncs-f]"
ammonia.autoplace = nil
ammonia.default_cover_tile = nil
ammonia.allowed_neighbors = nil
ammonia.is_foundation = true
ammonia.weight = foundation_tile.weight
ammonia.minable = {mining_time = 0.5, result = "ncs-ammonia-pool"}
ammonia.placeable_by = {item = "ncs-ammonia-pool", count = 1}
data:extend({ammonia})

floor_item("ncs-ammonia-pool", {r = 0.6, g = 0.6, b = 1}, "d", "__space-age__/graphics/icons/fluid/ammoniacal-solution.png") -- nur aus dem Boden-Extraktor

---------------------------------------------------------------------------
-- Alte Zonenboeden (vor 1.1.0): nur noch fuer alte Spielstaende, werden beim Laden zu Fundament.

for _, old in pairs({"ncs-science-foundation", "ncs-lava-foundation"}) do
  local tile = table.deepcopy(foundation_tile)
  tile.name = old
  tile.order = "z[ncs-legacy]"
  tile.hidden = true
  tile.minable = {mining_time = 0.5, result = "space-platform-foundation"}
  tile.placeable_by = {item = "space-platform-foundation", count = 1}
  data:extend({tile})
end
