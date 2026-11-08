-- Roboter-Granaten (seit 1.24.1, Idee des Users): Artilleriegranaten, die beim Einschlag 10 Kampfroboter freisetzen.
-- Je Roboter (Distractor, Defender, Destroyer) eine Granate, ein Geschoss, ein Rezept und eine Forschung.
-- Gehen in jedem Artilleriegeschuetz und in der Orbitalkanone. Die Roboter suchen sich per Skript Ziele
-- (scripts/robot-shells.lua), bis ihre Lebenszeit ablaeuft.

local config = require("scripts.robot-shells-config")

local vanilla_projectile = data.raw["artillery-projectile"]["artillery-projectile"]
local vanilla_shell = data.raw.ammo["artillery-shell"]
local artillery = data.raw.technology["artillery"]

local prototypes_list = {}
for _, kind in pairs(config.KINDS) do
  local capsule = data.raw.capsule[kind.capsule]
  local capsule_icon = capsule and (capsule.icon or (capsule.icons and capsule.icons[1].icon))

  -- Geschoss: Flugbild der Artillerie, beim Einschlag Explosion und Roboter
  local projectile = table.deepcopy(vanilla_projectile)
  projectile.name = kind.projectile
  projectile.action =
  {
    type = "direct",
    action_delivery =
    {
      type = "instant",
      target_effects =
      {
        {type = "create-entity", entity_name = "big-artillery-explosion"},
        {
          type = "create-entity",
          entity_name = kind.robot,
          offset_deviation = {{-config.SPREAD, -config.SPREAD}, {config.SPREAD, config.SPREAD}},
          repeat_count = config.ROBOTS,
          trigger_created_entity = true -- scripts/robot-shells.lua schickt sie auf die Jagd
        },
        {type = "show-explosion-on-chart", scale = 8 / 32}
      }
    }
  }
  projectile.final_action = nil
  table.insert(prototypes_list, projectile)

  -- Granate: wie die Artilleriegranate, Roboter-Kapsel klein in der Ecke
  local shell = table.deepcopy(vanilla_shell)
  shell.name = kind.shell
  shell.icon = nil
  shell.icons =
  {
    {icon = vanilla_shell.icon, icon_size = vanilla_shell.icon_size or 64},
    {icon = capsule_icon, icon_size = 64, scale = 0.3, shift = {8, 8}}
  }
  shell.ammo_type.action.action_delivery.projectile = kind.projectile
  shell.ammo_category = "ncs-robot-shell" -- passt in Bodenartillerie und Orbitalkanone (siehe unten)
  shell.order = (vanilla_shell.order or "") .. "-ncs-" .. kind.robot
  table.insert(prototypes_list, shell)

  table.insert(prototypes_list,
  {
    type = "recipe",
    name = kind.shell,
    enabled = false,
    energy_required = 15,
    ingredients =
    {
      {type = "item", name = "artillery-shell", amount = 1},
      {type = "item", name = kind.capsule, amount = config.ROBOTS},
      {type = "item", name = "low-density-structure", amount = 5}
    },
    results = {{type = "item", name = kind.shell, amount = 1}}
  })

  table.insert(prototypes_list,
  {
    type = "technology",
    name = kind.shell,
    icons =
    {
      {icon = "__base__/graphics/technology/artillery.png", icon_size = 256},
      {icon = capsule_icon, icon_size = 64, scale = 0.75, shift = {38, 38}}
    },
    effects = {{type = "unlock-recipe", recipe = kind.shell}},
    prerequisites = {"artillery", kind.technology},
    unit = {count = config.RESEARCH, ingredients = table.deepcopy(artillery.unit.ingredients), time = 30},
    order = "z[ncs]-r[robot-shell]-" .. kind.robot
  })
end

table.insert(prototypes_list, 1, {type = "ammo-category", name = "ncs-robot-shell"})
data:extend(prototypes_list)

-- Eigene Kategorie, damit die Orbitalkanone sie nimmt, normale Artilleriegranaten aber nicht (seit 1.24.1).
-- Die Vanilla-Artillerie (Geschuetz und Wagen teilen sich die Waffe) nimmt sie zusaetzlich; sonst bleibt sie gleich.
local ground_gun = data.raw.gun["artillery-wagon-cannon"]
if ground_gun then
  local ap = ground_gun.attack_parameters
  local categories = ap.ammo_categories or {ap.ammo_category}
  table.insert(categories, "ncs-robot-shell")
  ap.ammo_categories = categories
  ap.ammo_category = nil
end
