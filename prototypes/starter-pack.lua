-- Unsichtbares Starterpaket fuer das Startschiff. Nur per Script verwendet.
-- Es legt nur den Hub mit Fundament darunter an; den Rest baut control.lua aus dem Startschiff-Blueprint.

local tiles = {}
for x = -4, 3 do
  for y = -4, 3 do
    table.insert(tiles, {position = {x, y}, tile = "space-platform-foundation"})
  end
end

local pack = table.deepcopy(data.raw["space-platform-starter-pack"]["space-platform-starter-pack"])
pack.name = "ncs-mothership-starter-pack"
pack.hidden = true
pack.hidden_in_factoriopedia = true
pack.tiles = tiles
pack.initial_items =
{
  {type = "item", name = "space-platform-foundation", amount = 20, quality_min = "normal", quality_max = "normal"}
}

data:extend({pack})
