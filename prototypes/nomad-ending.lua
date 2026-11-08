-- Ende von Nomad (seit 1.24.1, Wunsch des Users: einfach statt eigener Story-Kette): eine letzte, sehr teure Forschung
-- "Nomade vollendet". Ist sie erforscht, zeigt scripts/ending.lua den Siegesbildschirm, weiterspielen geht.

local TECH = "ncs-nomad-achieved"
local COUNT = 50000

-- Alle Science Packs, die es gibt (Grundspiel + Space Age)
local PACKS =
{
  "automation-science-pack", "logistic-science-pack", "military-science-pack", "chemical-science-pack",
  "production-science-pack", "utility-science-pack", "space-science-pack", "metallurgic-science-pack",
  "electromagnetic-science-pack", "agricultural-science-pack", "cryogenic-science-pack", "promethium-science-pack"
}
local ingredients = {}
for _, pack in pairs(PACKS) do
  -- In 2.1 sind Science Packs Typ "item" (frueher "tool")
  if (data.raw.tool and data.raw.tool[pack]) or data.raw.item[pack] then table.insert(ingredients, {pack, 1}) end
end

local prerequisites = {}
for _, tech in pairs({"promethium-science-pack", "ncs-promethium-zone"}) do
  if data.raw.technology[tech] then table.insert(prerequisites, tech) end
end

data:extend(
{
  {
    type = "technology",
    name = TECH,
    icons =
    {
      {icon = "__space-age__/graphics/technology/space-platform.png", icon_size = 256, tint = {r = 1, g = 0.85, b = 0.45}},
      {icon = "__space-age__/graphics/icons/promethium-asteroid-chunk.png", icon_size = 64, scale = 0.75, shift = {38, 38}}
    },
    effects = {{type = "nothing", effect_description = {"ncs-tech.nomad-achieved"}}},
    prerequisites = prerequisites,
    unit = {count = COUNT, ingredients = ingredients, time = 60},
    order = "z[ncs]-z[nomad-achieved]"
  }
})
