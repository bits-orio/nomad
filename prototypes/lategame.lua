-- Phase 6: Lategame nach Promethium-Science. Promethium dient als Treibstoff.
--   Promethium-Antrieb: staerkeres Triebwerk mit Promethium-Treibstoff.
--   Promethium-Boden mit Materie-Rekombinator und Sprungantrieb (beide nur auf Promethium-Boden).
-- Rezepte "Item -> Item" fuer den Rekombinator werden in data-final-fixes pro Item erzeugt.
-- Zahlen sind vorlaeufig und werden beim Testen festgelegt.

local PROMETHIUM_ZONE_RULE =
{
  required_tiles = {layers = {ncs_promethium_zone = true}},
  colliding_tiles = {layers = {}}
}
local SPACE_ONLY = {{property = "pressure", max = 0}, {property = "gravity", max = 0}}

local LATE_PACKS =
{
  {"automation-science-pack", 1},
  {"logistic-science-pack", 1},
  {"chemical-science-pack", 1},
  {"production-science-pack", 1},
  {"utility-science-pack", 1},
  {"space-science-pack", 1},
  {"metallurgic-science-pack", 1},
  {"electromagnetic-science-pack", 1},
  {"agricultural-science-pack", 1},
  {"cryogenic-science-pack", 1},
  {"promethium-science-pack", 1}
}

local cma = require("prototypes.cma")

local function tinted(icon, size, tint)
  return {{icon = icon, icon_size = size or 64, tint = tint}}
end

local PURPLE = {r = 0.8, g = 0.55, b = 1}

local function zone_rule(collision_box)
  local rule = table.deepcopy(PROMETHIUM_ZONE_RULE)
  rule.area = table.deepcopy(collision_box)
  return {rule}
end

---------------------------------------------------------------------------
-- Lebendes Metall: Lategame-Material von Gleba, aus sehr vielen Pentapoden-Eiern und etwas Promethium.
-- Nur in der Biokammer und nur auf Gleba (Druck 2000).

local GREEN = {r = 0.55, g = 1, b = 0.6}

data:extend(
{
  {
    type = "item",
    name = "ncs-living-metal",
    icons =
    {
      {icon = "__space-age__/graphics/icons/tungsten-plate.png", icon_size = 64, tint = GREEN},
      {icon = "__space-age__/graphics/icons/pentapod-egg.png", icon_size = 64, scale = 0.25, shift = {8, 8}}
    },
    subgroup = "agriculture-products",
    order = "z[ncs]-a[living-metal]",
    stack_size = 50,
    weight = 20000
  },
  {
    type = "recipe",
    name = "ncs-living-metal",
    enabled = false,
    categories = {"organic"},
    energy_required = 30,
    ingredients =
    {
      {type = "item", name = "pentapod-egg", amount = 30},
      {type = "item", name = "promethium-asteroid-chunk", amount = 1}
    },
    results = {{type = "item", name = "ncs-living-metal", amount = 1}},
    surface_conditions = {{property = "pressure", min = 2000, max = 2000}},
    allow_productivity = false
  },
  {
    type = "technology",
    name = "ncs-living-metal",
    icon = "__space-age__/graphics/technology/biochamber.png",
    icon_size = 256,
    effects = {{type = "unlock-recipe", recipe = "ncs-living-metal"}},
    prerequisites = {"promethium-science-pack"},
    unit = {count = 1000, ingredients = table.deepcopy(LATE_PACKS), time = 60}
  }
})

---------------------------------------------------------------------------
-- Promethium-Zelle (Brennstoff fuer Rekombinator und Sprungantrieb)

data:extend(
{
  {type = "fuel-category", name = "ncs-promethium"},
  {
    type = "item",
    name = "ncs-promethium-cell",
    icons = tinted("__space-age__/graphics/icons/promethium-asteroid-chunk.png", 64, PURPLE),
    subgroup = "space-processing",
    order = "z[ncs]-a[promethium-cell]",
    fuel_categories = {"ncs-promethium"},
    fuel_value = "200MJ",
    stack_size = 50,
    weight = 20000
  },
  {
    type = "recipe",
    name = "ncs-promethium-cell",
    enabled = false,
    energy_required = 10,
    categories = {"crafting"},
    ingredients =
    {
      {type = "item", name = "low-density-structure", amount = 1},
      {type = "item", name = "processing-unit", amount = 1},
      {type = "item", name = "ncs-living-metal", amount = 1}
    },
    results = {{type = "item", name = "ncs-promethium-cell", amount = 1}}
  }
})

---------------------------------------------------------------------------
-- Promethium-Antrieb

local fuel = table.deepcopy(data.raw.fluid["thruster-fuel"])
fuel.name = "ncs-promethium-thruster-fuel"
fuel.icon = nil
fuel.icons = tinted("__space-age__/graphics/icons/fluid/thruster-fuel.png", 64, PURPLE)
fuel.base_color = {r = 0.5, g = 0.2, b = 0.8}
fuel.flow_color = {r = 0.75, g = 0.5, b = 1}
fuel.order = (fuel.order or "") .. "-ncs"

local thruster = table.deepcopy(data.raw.thruster["thruster"])
thruster.name = "ncs-promethium-thruster"
thruster.icon = nil
thruster.icons = tinted("__space-age__/graphics/icons/thruster.png", 64, PURPLE)
thruster.minable = {mining_time = 0.1, result = "ncs-promethium-thruster"}
thruster.fast_replaceable_group = "thruster"
thruster.next_upgrade = nil
thruster.max_health = 600
thruster.fuel_fluid_box.filter = "ncs-promethium-thruster-fuel"
-- 3-facher Schub fuer das schwere Mutterschiff, aber 5-facher Verbrauch (seit 1.24.1, Wunsch des Users: das Rezept
-- macht aus 100 Treibstoff 1000 Promethium-Treibstoff, die Triebwerke sollen deshalb ordentlich saugen; vorher 2-fach).
-- Voll: 150 Promethium-Treibstoff + 150 Oxidator pro Sekunde (nach ship-balance.lua), ein Chemiewerk reicht fuer ~1,3.
local USAGE, THRUST = 5, 3 -- Schub seit 1.24.1 3-fach (Wunsch des Users, vorher 2)
for _, key in pairs({"min_performance", "max_performance"}) do
  thruster[key].fluid_usage = thruster[key].fluid_usage * USAGE
  thruster[key].effectivity = thruster[key].effectivity * THRUST / USAGE
end

local thruster_item = table.deepcopy(data.raw.item["thruster"])
thruster_item.name = "ncs-promethium-thruster"
thruster_item.icon = nil
thruster_item.icons = thruster.icons
thruster_item.place_result = "ncs-promethium-thruster"
thruster_item.order = (thruster_item.order or "") .. "-ncs"

data:extend(
{
  fuel,
  thruster,
  thruster_item,
  {
    type = "recipe",
    name = "ncs-promethium-thruster-fuel",
    icons = fuel.icons,
    categories = {"chemistry"},
    subgroup = "space-processing",
    order = "z[ncs]-b[promethium-thruster-fuel]",
    enabled = false,
    auto_recycle = false,
    energy_required = 5,
    ingredients =
    {
      {type = "item", name = "promethium-asteroid-chunk", amount = 1},
      {type = "fluid", name = "thruster-fuel", amount = 100}
    },
    results = {{type = "fluid", name = "ncs-promethium-thruster-fuel", amount = 1000}},
    surface_conditions = {{property = "gravity", min = 0, max = 0}}
  },
  {
    type = "recipe",
    name = "ncs-promethium-thruster",
    enabled = false,
    energy_required = 20,
    ingredients =
    {
      {type = "item", name = "thruster", amount = 1},
      {type = "item", name = "quantum-processor", amount = 10},
      {type = "item", name = "ncs-promethium-cell", amount = 10}
    },
    results = {{type = "item", name = "ncs-promethium-thruster", amount = 1}}
  }
})

---------------------------------------------------------------------------
-- Materie-Rekombinator: Ofen mit eingebautem Qualitaetsbonus, laeuft mit Promethium-Zellen.
-- Ein Item rein, dasselbe Item raus; mit 25 % Chance eine Qualitaetsstufe hoeher.

-- Grafik: "Matter Printer" aus CMA Graphics (seit 1.24.0, vorher eingefaerbter Elektroofen).
local recombinator_graphics, recombinator_icon = cma.crafting_graphics("matter-printer", "mk3", 3, false)
local recombinator = table.deepcopy(data.raw.furnace["electric-furnace"])
recombinator.name = "ncs-matter-recombinator"
recombinator.icon = nil
recombinator.icons = {{icon = recombinator_icon, icon_size = 64}}
recombinator.graphics_set = recombinator_graphics
recombinator.water_reflection = nil
recombinator.minable = {mining_time = 0.5, result = "ncs-matter-recombinator"}
recombinator.fast_replaceable_group = nil
recombinator.next_upgrade = nil
recombinator.crafting_categories = {"ncs-recombination"}
recombinator.crafting_speed = 1
recombinator.source_inventory_size = 1
recombinator.result_inventory_size = 1 -- Ergebnisse muessen per Greifarm abgeholt werden (verschiedene Qualitaeten stapeln nicht)
recombinator.module_slots = 0
recombinator.allowed_effects = {"quality"}
recombinator.effect_receiver = {base_effect = {quality = 0.25}, uses_module_effects = false, uses_beacon_effects = false, uses_surface_effects = false}
recombinator.energy_usage = "2MW"
recombinator.energy_source =
{
  type = "burner",
  fuel_categories = {"ncs-promethium"},
  effectivity = 1,
  fuel_inventory_size = 1
}
recombinator.surface_conditions = table.deepcopy(SPACE_ONLY)
recombinator.tile_buildability_rules = zone_rule(recombinator.collision_box)
recombinator.cant_insert_at_source_message_key = nil

local recombinator_item = table.deepcopy(data.raw.item["electric-furnace"])
recombinator_item.name = "ncs-matter-recombinator"
recombinator_item.icon = nil
recombinator_item.icons = recombinator.icons
recombinator_item.place_result = "ncs-matter-recombinator"
recombinator_item.subgroup = "space-platform"
recombinator_item.order = "z[ncs]-a[matter-recombinator]"

---------------------------------------------------------------------------
-- Sprungantrieb: Behaelter fuer Promethium-Zellen; Sprungziel wird per Fenster gewaehlt (scripts/jump-drive.lua).

-- Grafik: "Containment Torus" aus CMA Graphics (seit 1.24.0, vorher Kernreaktor).
local reactor = data.raw.reactor["nuclear-reactor"]
local torus = cma.machine("containment-torus", {variant = "mk3", size = 5})
local jump_drive =
{
  type = "container",
  name = "ncs-jump-drive",
  icons = {{icon = torus.icon, icon_size = 64}},
  flags = {"placeable-player", "player-creation"},
  minable = {mining_time = 1, result = "ncs-jump-drive"},
  max_health = 2000,
  collision_box = {{-2.2, -2.2}, {2.2, 2.2}},
  selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
  inventory_size = 10,
  inventory_type = "with_filters_and_bar",
  picture = torus.idle_sprite,
  surface_conditions = table.deepcopy(SPACE_ONLY),
  open_sound = reactor.open_sound,
  close_sound = reactor.close_sound,
  impact_category = "metal-large"
}
jump_drive.tile_buildability_rules = zone_rule(jump_drive.collision_box)

local jump_drive_item =
{
  type = "item",
  name = "ncs-jump-drive",
  icons = jump_drive.icons,
  subgroup = "space-platform",
  order = "z[ncs]-b[jump-drive]",
  place_result = "ncs-jump-drive",
  stack_size = 1,
  weight = 1000000
}

data:extend(
{
  {type = "recipe-category", name = "ncs-recombination"},
  recombinator,
  recombinator_item,
  {
    type = "recipe",
    name = "ncs-matter-recombinator",
    enabled = false,
    energy_required = 30,
    ingredients =
    {
      {type = "item", name = "electric-furnace", amount = 1},
      {type = "item", name = "quantum-processor", amount = 20},
      {type = "item", name = "superconductor", amount = 50},
      {type = "item", name = "ncs-promethium-cell", amount = 10}
    },
    results = {{type = "item", name = "ncs-matter-recombinator", amount = 1}}
  },
  jump_drive,
  jump_drive_item,
  {
    type = "recipe",
    name = "ncs-jump-drive",
    enabled = false,
    energy_required = 60,
    ingredients =
    {
      {type = "item", name = "fusion-reactor", amount = 1},
      {type = "item", name = "quantum-processor", amount = 100},
      {type = "item", name = "low-density-structure", amount = 200},
      {type = "item", name = "ncs-promethium-cell", amount = 50}
    },
    results = {{type = "item", name = "ncs-jump-drive", amount = 1}}
  }
})

---------------------------------------------------------------------------
-- Technologien

data:extend(
{
  {
    type = "technology",
    name = "ncs-promethium-drive",
    icon = "__space-age__/graphics/technology/promethium-science-pack.png",
    icon_size = 256,
    effects =
    {
      {type = "unlock-recipe", recipe = "ncs-promethium-cell"},
      {type = "unlock-recipe", recipe = "ncs-promethium-thruster-fuel"},
      {type = "unlock-recipe", recipe = "ncs-promethium-thruster"}
    },
    prerequisites = {"ncs-living-metal"},
    unit = {count = 2000, ingredients = table.deepcopy(LATE_PACKS), time = 60}
  },
  {
    type = "technology",
    name = "ncs-promethium-zone",
    icon = "__space-age__/graphics/technology/promethium-science-pack.png",
    icon_size = 256,
    effects =
    {
      {type = "unlock-recipe", recipe = "ncs-promethium-foundation"},
      {type = "unlock-recipe", recipe = "ncs-matter-recombinator"},
      {type = "unlock-recipe", recipe = "ncs-jump-drive"}
    },
    prerequisites = {"ncs-promethium-drive"},
    unit = {count = 10000, ingredients = table.deepcopy(LATE_PACKS), time = 60}
  }
})
