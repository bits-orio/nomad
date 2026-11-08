-- Orbitalkanone: Artilleriegeschuetz fuer das Schiff, das Artilleriegranaten auf den Planeten darunter schiesst
-- (Laufzeit: scripts/orbital-cannon.lua). Gezielt wird wie mit der Artillerie-Fernsteuerung: Knopf in der
-- Schnellleiste gibt die Orbital-Fernsteuerung, ein Klick (auch in der Kartenansicht) setzt ein Orbital-Leuchtsignal.
-- Auf der Plattform selbst hat sie keine Ziele; das Skript nimmt die Granaten aus ihrem Munitionsfach.
-- Zahlen sind vorlaeufig und werden beim Testen festgelegt.

local CANNON = "ncs-orbital-cannon"
local TARGETING = "ncs-orbital-targeting"
local FLARE = "ncs-orbital-flare"
local TINT = {r = 0.8, g = 0.85, b = 1}

local cannon = table.deepcopy(data.raw["artillery-turret"]["artillery-turret"])
cannon.name = CANNON
cannon.icon = nil
cannon.icons = {{icon = "__base__/graphics/icons/artillery-turret.png", icon_size = 64, tint = TINT}}
cannon.minable = {mining_time = 1, result = CANNON}
cannon.placeable_by = nil
cannon.fast_replaceable_group = nil
cannon.next_upgrade = nil
cannon.max_health = 3000
cannon.disable_automatic_firing = true
cannon.surface_conditions = {{property = "pressure", max = 0}, {property = "gravity", max = 0}} -- nur im All

-- Eigenes Geschuetz (seit 1.24.1): nimmt nur Orbital-Granaten und Roboter-Granaten, keine normalen Artilleriegranaten
-- (Wunsch des Users: Granaten fuer die Orbitalkanone teurer, dafuer groessere Explosion und lange Nachladezeit).
-- Gefeuert wird per Skript (scripts/orbital-cannon.lua), die Nachladezeit steht dort.
local gun = table.deepcopy(data.raw.gun[cannon.gun])
gun.name = "ncs-orbital-cannon-gun"
gun.attack_parameters.ammo_category = nil
gun.attack_parameters.ammo_categories = {"ncs-orbital-shell", "ncs-robot-shell"}
cannon.gun = gun.name

-- Orbital-Artilleriegranate: Radius 10 statt 4, mehr Schaden, viel Rauch und mehrere Explosionen
local ORBITAL_SHELL = "ncs-orbital-artillery-shell"
local RADIUS = 10
local projectile = table.deepcopy(data.raw["artillery-projectile"]["artillery-projectile"])
projectile.name = "ncs-orbital-artillery-projectile"
projectile.action =
{
  type = "direct",
  action_delivery =
  {
    type = "instant",
    target_effects =
    {
      {
        type = "nested-result",
        action =
        {
          type = "area",
          radius = RADIUS,
          action_delivery =
          {
            type = "instant",
            target_effects =
            {
              {type = "damage", damage = {amount = 2000, type = "physical"}},
              {type = "damage", damage = {amount = 2000, type = "explosion"}}
            }
          }
        }
      },
      {type = "create-trivial-smoke", smoke_name = "artillery-smoke", initial_height = 0, speed_from_center = 0.08,
        speed_from_center_deviation = 0.01, offset_deviation = {{-RADIUS, -RADIUS}, {RADIUS, RADIUS}},
        max_radius = RADIUS - 1, repeat_count = 600},
      {type = "create-entity", entity_name = "big-artillery-explosion"},
      {type = "create-entity", entity_name = "big-artillery-explosion", repeat_count = 12,
        offset_deviation = {{-RADIUS * 0.7, -RADIUS * 0.7}, {RADIUS * 0.7, RADIUS * 0.7}}},
      {type = "show-explosion-on-chart", scale = RADIUS / 32}
    }
  }
}
projectile.final_action = nil

local vanilla_shell = data.raw.ammo["artillery-shell"]
local orbital_shell = table.deepcopy(vanilla_shell)
orbital_shell.name = ORBITAL_SHELL
orbital_shell.ammo_category = "ncs-orbital-shell"
orbital_shell.icon = nil
orbital_shell.icons = {{icon = vanilla_shell.icon, icon_size = vanilla_shell.icon_size or 64, tint = TINT}}
orbital_shell.ammo_type.action.action_delivery.projectile = projectile.name
orbital_shell.order = (vanilla_shell.order or "") .. "-ncs-orbital"

-- Orbital-Clusterbombe (seit 1.24.1, Idee des Users): Erst schlaegt im Ziel eine Orbital-Granate ein, dann regnen
-- weitere Orbital-Granaten im Umkreis herab. Die zusaetzlichen Einschlaege erzeugt scripts/orbital-cannon.lua beim
-- Abfeuern (Anzahl, Umkreis, Nachladezeit dort). Rezept: 10 Orbital-Granaten + 50 Sprengstoff + 1 Rakete.
local CLUSTER_SHELL = "ncs-orbital-cluster-shell"
local cluster_shell = table.deepcopy(orbital_shell)
cluster_shell.name = CLUSTER_SHELL
cluster_shell.icons =
{
  {icon = vanilla_shell.icon, icon_size = vanilla_shell.icon_size or 64, tint = {r = 1, g = 0.75, b = 0.4}},
  {icon = "__base__/graphics/icons/rocket.png", icon_size = 64, scale = 0.3, shift = {8, 8}}
}
cluster_shell.order = (vanilla_shell.order or "") .. "-ncs-orbital-cluster"

local cannon_item = table.deepcopy(data.raw.item["artillery-turret"])
cannon_item.name = CANNON
cannon_item.icon = nil
cannon_item.icons = cannon.icons
cannon_item.place_result = CANNON
cannon_item.subgroup = "space-platform"
cannon_item.order = "z[ncs]-c[orbital-cannon]"

-- Orbital-Fernsteuerung: nur in der Hand, kommt aus dem Knopf in der Schnellleiste.
-- Seit 1.24.1 ein Auswahlwerkzeug statt Kapsel mit "artillery-remote": Die Engine laesst die Artillerie-Fernsteuerung
-- nur zu, wenn eine Artillerie derselben Oberflaeche in Reichweite ist; die Kanone steht aber auf dem Schiff
-- (im Spiel: "Problem ist die Reichweite"). Klick = ein Ziel, Rahmen = jedes gegnerische Militaerziel darin.
-- Das Leuchtsignal setzt das Skript nur zur Anzeige.
local flare = table.deepcopy(data.raw["artillery-flare"]["artillery-flare"])
flare.name = FLARE
flare.localised_name = {"entity-name." .. FLARE}
flare.map_color = {r = 0.4, g = 0.7, b = 1}
flare.shot_category = "ncs-orbital-flare-only" -- Bodenartillerie schiesst nicht darauf (keine Munition dieser Art)
flare.early_death_ticks = 60 * 60

local remote_icons = {{icon = "__base__/graphics/icons/artillery-targeting-remote.png", icon_size = 64, tint = TINT}}
local SELECT =
{
  border_color = {r = 0.4, g = 0.7, b = 1},
  cursor_box_type = "not-allowed",
  mode = {"nothing"}
}
local remote =
{
  type = "selection-tool",
  name = TARGETING,
  icons = remote_icons,
  flags = {"only-in-cursor", "not-stackable", "spawnable"},
  hidden = true,
  subgroup = "spawnables",
  order = "b[turret]-d[artillery-turret]-c[orbital-remote]",
  stack_size = 1,
  select = table.deepcopy(SELECT),
  alt_select = table.deepcopy(SELECT),
  mouse_cursor = "selection-tool-cursor",
  skip_fog_of_war = false
}

local vanilla_shortcut = data.raw.shortcut["give-artillery-targeting-remote"]
local shortcut =
{
  type = "shortcut",
  name = "ncs-give-orbital-targeting",
  order = "e[spidertron-remote]-b[orbital]",
  action = "spawn-item",
  localised_name = {"shortcut-name.ncs-give-orbital-targeting"},
  technology_to_unlock = CANNON,
  unavailable_until_unlocked = true,
  item_to_spawn = TARGETING,
  icons = {{icon = vanilla_shortcut.icon, icon_size = vanilla_shortcut.icon_size, tint = TINT}},
  small_icons = {{icon = vanilla_shortcut.small_icon, icon_size = vanilla_shortcut.small_icon_size, tint = TINT}}
}

local artillery = data.raw.technology["artillery"]
local packs = table.deepcopy(artillery.unit.ingredients)
local has_space = false
for _, pack in pairs(packs) do
  if (pack[1] or pack.name) == "space-science-pack" then has_space = true end
end
if not has_space then table.insert(packs, {"space-science-pack", 1}) end -- Space Age verlangt ihn fuer Artillerie schon

data:extend(
{
  {type = "ammo-category", name = "ncs-orbital-flare-only", hidden = true},
  {type = "ammo-category", name = "ncs-orbital-shell"},
  gun,
  projectile,
  orbital_shell,
  cluster_shell,
  {
    type = "recipe",
    name = CLUSTER_SHELL,
    enabled = false,
    energy_required = 60,
    ingredients =
    {
      {type = "item", name = ORBITAL_SHELL, amount = 10},
      {type = "item", name = "explosives", amount = 700}, -- Wunsch des Users (vorher 50)
      {type = "item", name = "rocket", amount = 1}
    },
    results = {{type = "item", name = CLUSTER_SHELL, amount = 1}}
  },
  {
    type = "technology",
    name = CLUSTER_SHELL,
    icons =
    {
      {icon = "__base__/graphics/technology/artillery.png", icon_size = 256, tint = {r = 1, g = 0.8, b = 0.55}},
      {icon = "__base__/graphics/icons/rocket.png", icon_size = 64, scale = 0.75, shift = {38, 38}}
    },
    effects = {{type = "unlock-recipe", recipe = CLUSTER_SHELL}},
    prerequisites = {CANNON},
    unit = {count = 5000, ingredients = table.deepcopy(packs), time = 30},
    order = "z[ncs]-o[orbital-cannon]-b[cluster]"
  },
  {
    type = "recipe",
    name = ORBITAL_SHELL,
    enabled = false,
    energy_required = 20,
    ingredients =
    {
      {type = "item", name = "artillery-shell", amount = 1},
      {type = "item", name = "explosives", amount = 150}, -- Wunsch des Users (vorher 10)
      {type = "item", name = "low-density-structure", amount = 5}
    },
    results = {{type = "item", name = ORBITAL_SHELL, amount = 1}}
  },
  cannon,
  cannon_item,
  {
    type = "recipe",
    name = CANNON,
    enabled = false,
    energy_required = 30,
    ingredients =
    {
      {type = "item", name = "artillery-turret", amount = 1},
      {type = "item", name = "low-density-structure", amount = 100},
      {type = "item", name = "processing-unit", amount = 50}
    },
    results = {{type = "item", name = CANNON, amount = 1}}
  },
  flare,
  remote,
  shortcut,
  {
    type = "technology",
    name = CANNON,
    icon = "__base__/graphics/technology/artillery.png",
    icon_size = 256,
    effects =
    {
      {type = "unlock-recipe", recipe = CANNON},
      {type = "unlock-recipe", recipe = ORBITAL_SHELL},
      {type = "nothing", icons = remote_icons, effect_description = {"ncs-tech.orbital-targeting"}}
    },
    prerequisites = {"artillery", "space-science-pack"},
    unit = {count = 10000, ingredients = packs, time = 30}, -- seit 1.24.1 10 000 (Wunsch des Users), vorher 2000
    order = "z[ncs]-o[orbital-cannon]"
  }
})
