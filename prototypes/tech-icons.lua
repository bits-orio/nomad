-- Erkennbare Bilder fuer die Forschungen und Boden-Items des Mods (seit 1.24.1, Wunsch des Users):
-- Vorher nutzten mehrere Forschungen dasselbe Vanilla-Bild (z. B. Promethium-Flasche fuer Promethium-Antrieb
-- und Promethium-Boden), man sah nicht, was kommt.
--   Boden:   eingefaerbtes Plattform-Fundament gross, Material (Lava, Yumako ...) in der Ecke
--   Quelle:  Rohstoff gross, Plattform-Fundament in der Ecke
--   Sonst:   das freigeschaltete Item gross, Zusatz in der Ecke
-- Laeuft in data-final-fixes, damit alle Items und Forschungen existieren.

local FOUNDATION = "__space-age__/graphics/icons/space-platform-foundation.png"
local SA = "__space-age__/graphics/icons/"

-- Forschungsbilder werden mit 256 erwartet, Item-Bilder mit 64: Standard-Skalierung eines Layers ist
-- (erwartet / 2) / icon_size, bei Forschung also 4-mal so gross wie bei Items.
local function item_to_tech(icons)
  local result = {}
  for _, layer in pairs(icons) do
    local copy = table.deepcopy(layer)
    local size = copy.icon_size or 64
    copy.icon_size = size
    copy.scale = (copy.scale or (32 / size)) * 4
    if copy.shift then copy.shift = {copy.shift[1] * 4, copy.shift[2] * 4} end
    table.insert(result, copy)
  end
  return result
end

local function item_icons(name)
  local item = data.raw.item[name]
  if not item then return nil end
  return item.icons and table.deepcopy(item.icons) or {{icon = item.icon, icon_size = item.icon_size or 64}}
end

-- Ecke unten rechts (Forschung)
local function tech_corner(icon, tint)
  return {icon = icon, icon_size = 64, scale = 0.75, shift = {38, 38}, tint = tint}
end

local function set_tech(name, icons)
  local tech = data.raw.technology[name]
  if not tech then return end
  tech.icon = nil
  tech.icon_size = nil
  tech.icons = icons
end

---------------------------------------------------------------------------
-- Spezialboeden: Item und Forschung

-- Die Item-Bilder (Fundament + Material in der Ecke) setzt prototypes/floors.lua, die Forschung zeigt dasselbe.
local FLOORS =
{
  {item = "ncs-lava-pool", tech = "ncs-lava-zone"},
  {item = "ncs-bio-foundation", tech = "ncs-bio-zone"},
  {item = "ncs-jellynut-foundation", tech = "ncs-jellynut-zone"},
  {item = "ncs-ammonia-pool", tech = "ncs-ammonia-zone"},
  {item = "ncs-promethium-foundation", tech = "ncs-promethium-zone"}
}

for _, floor in pairs(FLOORS) do
  local icons = item_icons(floor.item)
  if icons then
    icons = item_to_tech(icons)
    -- Material in der Ecke etwas groesser als beim Item, damit man es in der Forschung gut sieht
    if icons[2] then
      icons[2].scale = 0.75
      icons[2].shift = {38, 38}
    end
    set_tech(floor.tech, icons)
  end
end

---------------------------------------------------------------------------
-- Schiffs-Quellen: Forschung = Rohstoff gross, Fundament in der Ecke

local sources = require("scripts.sources-config")
for _, source in pairs(sources.sources) do
  set_tech(source.chain,
  {
    {icon = source.icon, icon_size = 64, scale = 2, tint = source.tint},
    tech_corner(FOUNDATION)
  })
end

---------------------------------------------------------------------------
-- Weitere Forschungen, deren Bild doppelt oder nichtssagend war

local function item_tech(tech, item, corner)
  local icons = item_icons(item)
  if not icons then return end
  icons = item_to_tech(icons)
  if corner then table.insert(icons, corner) end
  set_tech(tech, icons)
end

-- Promethium-Antrieb: lila Triebwerk + Promethium
item_tech("ncs-promethium-drive", "ncs-promethium-thruster", tech_corner(SA .. "promethium-asteroid-chunk.png"))
-- Lebendes Metall: das Item selbst
item_tech("ncs-living-metal", "ncs-living-metal")
-- Grosse Frachtbucht: das Item + Kapazitaets-Symbol
item_tech("ncs-large-cargo-bay", "ncs-large-cargo-bay",
  {icon = "__core__/graphics/icons/technology/constants/constant-capacity.png", icon_size = 128, scale = 0.5, shift = {50, 50}})
