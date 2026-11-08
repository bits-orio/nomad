-- Grosse Frachtbucht: wie die Frachtbucht aus Space Age (wird an Hub oder Landefeld angebaut), aber mit
-- 100 statt 20 zusaetzlichen Plaetzen. Gegen den vollen Hub, wenn Raketen und Roboter viel liefern.
-- Zahlen sind vorlaeufig und werden beim Testen festgelegt.

local BONUS = 100
local TINT = {r = 0.7, g = 0.85, b = 1}

local bay = table.deepcopy(data.raw["cargo-bay"]["cargo-bay"])
bay.name = "ncs-large-cargo-bay"
bay.inventory_size_bonus = BONUS
bay.minable = {mining_time = (bay.minable and bay.minable.mining_time) or 1, result = "ncs-large-cargo-bay"}
bay.placeable_by = nil
bay.next_upgrade = nil
bay.icon = nil
bay.icons = {{icon = "__space-age__/graphics/icons/cargo-bay.png", tint = TINT}}

local item = table.deepcopy(data.raw.item["cargo-bay"])
item.name = "ncs-large-cargo-bay"
item.icon = nil
item.icons = table.deepcopy(bay.icons)
item.place_result = "ncs-large-cargo-bay"
item.order = (item.order or "") .. "-ncs"

data:extend(
{
  bay,
  item,
  {
    type = "recipe",
    name = "ncs-large-cargo-bay",
    enabled = false,
    energy_required = 30,
    ingredients =
    {
      {type = "item", name = "cargo-bay", amount = 5},
      {type = "item", name = "low-density-structure", amount = 200},
      {type = "item", name = "processing-unit", amount = 100}
    },
    results = {{type = "item", name = "ncs-large-cargo-bay", amount = 1}}
  },
  {
    type = "technology",
    name = "ncs-large-cargo-bay",
    icons = {{icon = "__space-age__/graphics/technology/space-platform.png", icon_size = 256, tint = TINT}},
    effects = {{type = "unlock-recipe", recipe = "ncs-large-cargo-bay"}},
    prerequisites = {"space-platform", "production-science-pack", "utility-science-pack"},
    unit =
    {
      count = 10000,
      ingredients =
      {
        {"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1},
        {"production-science-pack", 1}, {"utility-science-pack", 1}, {"space-science-pack", 1}
      },
      time = 60
    },
    order = "z[ncs]-s[large-cargo-bay]"
  }
})
