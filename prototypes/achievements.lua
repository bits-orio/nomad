-- Nomad-Errungenschaften (seit 1.24.1, Wunsch des Users). Freigeschaltet per Skript (scripts/achievements.lua).
-- Texte in locale/*/locale.cfg unter [achievement-name] und [achievement-description].

local SA = "__space-age__/graphics/icons/"
local BASE = "__base__/graphics/icons/"

local function icons(main, corner)
  local list = {{icon = main, icon_size = 64}}
  if corner then table.insert(list, {icon = corner, icon_size = 64, scale = 0.25, shift = {8, 8}}) end
  return list
end

-- {Name, Bild, Ecke}
local ACHIEVEMENTS =
{
  {"ncs-nomad", SA .. "space-platform-hub.png", SA .. "solar-system-edge.png"},
  {"ncs-first-landing", BASE .. "landed-cargo-pod.png", BASE .. "nauvis.png"},
  {"ncs-spacewalk", BASE .. "modular-armor.png", SA .. "space-platform-foundation.png"},
  {"ncs-recall", BASE .. "cargo-pod.png", SA .. "space-platform-hub.png"},
  {"ncs-first-extraction", "__nomad__/graphics/cma/icons/deep-extractor-mk3.png"},
  {"ncs-all-planets", "__nomad__/graphics/cma/icons/deep-extractor-mk3.png", SA .. "planet-route.png"},
  {"ncs-avalanche-rider", SA .. "scrap.png"},
  {"ncs-mothership", SA .. "space-platform-foundation.png"},
  {"ncs-ark", SA .. "space-platform-foundation.png", SA .. "yumako.png"},
  {"ncs-carpet-bombing", BASE .. "artillery-shell.png", BASE .. "rocket.png"},
  {"ncs-swarm", BASE .. "destroyer.png"},
  {"ncs-legendary", "__nomad__/graphics/cma/icons/matter-printer-mk3.png"}
}

local list = {}
for i, a in pairs(ACHIEVEMENTS) do
  table.insert(list,
  {
    type = "achievement",
    name = a[1],
    icons = icons(a[2], a[3]),
    order = "z[nomad]-" .. string.format("%02d", i)
  })
end
data:extend(list)
