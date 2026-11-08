-- Raumanzug: Anzug-Figur und Anzug-Ruestungen.
-- Laeuft in data-final-fixes, damit alle Ruestungen und Figur-Animationen anderer Mods erfasst sind.
--
-- Anzug-Figur "ncs-spacesuit-character": Kopie der Spielfigur. Am Boden kollidiert sie normal; wird sie an einem
-- Gebaeude blockiert, hebt sie ab. Im Flug kollidiert sie nur mit dem leeren Weltraum (Ebene empty_space):
-- ueber Gebaeude hinweg, aber nicht vom Schiff.
--
-- Fliegen: Den Flug-Zustand (Gleiten mit Duesenrauch) schaltet das Spiel nur mit einer Ruestung mit
-- provides_flight ein. Deshalb gibt es zu jeder Ruestung eine versteckte Anzug-Variante "ncs-suit-<ruestung>"
-- (gleiche Werte, gleiches Aussehen, aber mit Flug) und "ncs-suit-none" fuer "keine Ruestung".
-- scripts/spacesuit.lua tauscht die Ruestung beim Aussteigen gegen die Variante und beim Einsteigen zurueck.
-- Aussehen im Flug: die normale Figur (je nach Ruestung) in Stand-Pose, dazu der Duesenrauch der Mech-Ruestung.

local SUIT_PREFIX = "ncs-suit-"
local NO_ARMOR = "ncs-suit-none"

local function starts_with(text, prefix)
  return string.sub(text, 1, #prefix) == prefix
end

local mech_item = data.raw.armor["mech-armor"]
local base_character = data.raw.character["character"]

---------------------------------------------------------------------------
-- Anzug-Ruestungen

local armor_names = {}
for name in pairs(data.raw.armor) do
  if not starts_with(name, SUIT_PREFIX) then table.insert(armor_names, name) end
end
table.sort(armor_names)

local function add_flight(armor)
  armor.provides_flight = true
  if mech_item then
    armor.takeoff_sound = armor.takeoff_sound or table.deepcopy(mech_item.takeoff_sound)
    armor.landing_sound = armor.landing_sound or table.deepcopy(mech_item.landing_sound)
    armor.flight_sound = armor.flight_sound or table.deepcopy(mech_item.flight_sound)
  end
  armor.hidden = true
  armor.hidden_in_factoriopedia = true
end

local suit_armors = {}
local suit_of = {} -- Ruestung -> Anzug-Variante
for _, name in pairs(armor_names) do
  local armor = data.raw.armor[name]
  local suit = table.deepcopy(armor)
  suit.name = SUIT_PREFIX .. name
  suit.localised_name = armor.localised_name or {"item-name." .. name}
  suit.localised_description = {"item-description.ncs-suit-armor"}
  suit.order = (armor.order or "") .. "-ncs"
  add_flight(suit)
  table.insert(suit_armors, suit)
  suit_of[name] = suit.name
end

local none = table.deepcopy(data.raw.armor["light-armor"] or {})
none.type = "armor"
none.name = NO_ARMOR
none.localised_name = {"item-name.ncs-suit-none"}
none.localised_description = {"item-description.ncs-suit-armor"}
none.icon = none.icon or "__base__/graphics/icons/light-armor.png"
none.icons = nil
none.subgroup = none.subgroup or "armor"
none.order = "z[ncs]-a[suit-none]"
none.stack_size = 1
none.resistances = nil
none.equipment_grid = nil
none.inventory_size_bonus = nil
add_flight(none)
table.insert(suit_armors, none)

data:extend(suit_armors)

---------------------------------------------------------------------------
-- Anzug-Figur

local character = table.deepcopy(base_character)
character.name = "ncs-spacesuit-character"
-- Am Boden normale Kollision: Laeuft man gegen ein Gebaeude, hebt die Figur ab (so loest das Spiel den Flug aus).
-- Im Flug nur der leere Weltraum: ueber Gebaeude hinweg, aber nicht vom Schiff.
character.flying_collision_mask = {layers = {empty_space = true}}
character.hidden_in_factoriopedia = true

-- Reichweite im All (Wunsch des Users): viel weiter als die normale Figur (Grundspiel 10, Abbau von Erz 2,7).
local SPACE_REACH = 100
character.reach_distance = SPACE_REACH
character.build_distance = SPACE_REACH
character.drop_item_distance = SPACE_REACH
character.reach_resource_distance = SPACE_REACH

-- Duesenrauch der Mech-Ruestung
local smoke = nil
for _, entry in pairs(base_character.animations) do
  for _, armor in pairs(entry.armors or {}) do
    if armor == "mech-armor" then smoke = entry end
  end
end

-- Zu jedem Animations-Eintrag einen Eintrag fuer die Anzug-Varianten seiner Ruestungen (ohne Ruestung: "ncs-suit-none").
-- Im Flug: Stand-Pose der normalen Figur, ausser der Eintrag hat eigene Flug-Animationen (Mech-Ruestung).
local animations = {}
for _, entry in pairs(base_character.animations) do
  table.insert(animations, table.deepcopy(entry))
  local suit_entry = table.deepcopy(entry)
  local armors = {}
  if entry.armors then
    for _, armor in pairs(entry.armors) do
      if suit_of[armor] then table.insert(armors, suit_of[armor]) end
    end
  else
    armors = {NO_ARMOR}
  end
  if #armors > 0 then
    suit_entry.armors = armors
    suit_entry.idle_with_gun_in_air = suit_entry.idle_with_gun_in_air or table.deepcopy(entry.idle_with_gun)
    if smoke then
      suit_entry.smoke_in_air = suit_entry.smoke_in_air or table.deepcopy(smoke.smoke_in_air)
      suit_entry.smoke_cycles_per_tick = suit_entry.smoke_cycles_per_tick or smoke.smoke_cycles_per_tick
      suit_entry.extra_smoke_cycles_per_tile = suit_entry.extra_smoke_cycles_per_tile or smoke.extra_smoke_cycles_per_tile
    end
    table.insert(animations, suit_entry)
  end
end
character.animations = animations

data:extend({character})
