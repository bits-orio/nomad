-- Phase 6: Rezepte fuer den Materie-Rekombinator, eines pro Item: 1 Item -> dasselbe Item.
-- Der Rekombinator ist ein Ofen, waehlt das Rezept also selbst nach dem eingelegten Item (inkl. Qualitaet),
-- und hebt das Ergebnis ueber seinen eingebauten Qualitaetsbonus mit einer Chance eine Stufe an.
-- Laeuft in data-final-fixes, damit Items aller Mods erfasst sind.

local ITEM_TYPES =
{
  "item", "ammo", "capsule", "gun", "item-with-entity-data", "module", "rail-planner",
  "repair-tool", "tool", "armor", "space-platform-starter-pack"
}

local function has_flag(item, flag)
  for _, f in pairs(item.flags or {}) do
    if f == flag then return true end
  end
  return false
end

local recipes = {}
for _, item_type in pairs(ITEM_TYPES) do
  for name, item in pairs(data.raw[item_type] or {}) do
    if (item.icon or item.icons) and not item.hidden and not item.parameter and not has_flag(item, "spawnable") and not has_flag(item, "only-in-cursor") then
      table.insert(recipes,
      {
        type = "recipe",
        name = "ncs-recombine-" .. name,
        localised_name = {"recipe-name.ncs-recombine", item.localised_name or {"?", {"item-name." .. name}, {"entity-name." .. name}, name}},
        icons = item.icons and table.deepcopy(item.icons) or {{icon = item.icon, icon_size = item.icon_size or 64}},
        categories = {"ncs-recombination"},
        subgroup = "space-processing",
        order = "z[ncs]-z[recombine]-" .. name,
        enabled = true,
        hidden = true,
        hidden_in_factoriopedia = true,
        hide_from_player_crafting = true,
        hide_from_signal_gui = true,
        auto_recycle = false,
        allow_decomposition = false,
        allow_productivity = false,
        energy_required = 10,
        ingredients = {{type = "item", name = name, amount = 1}},
        results = {{type = "item", name = name, amount = 1}}
      })
    end
  end
end

if #recipes > 0 then
  data:extend(recipes)
end
log("[nomad] Rekombinator-Rezepte: " .. #recipes)
