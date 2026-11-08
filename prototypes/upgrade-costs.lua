-- Kosten der Freischalt-Forschungen fuer Spezialboeden und Schiffs-Quellen (Lava-Becken, Bio-Boden,
-- Ammoniak-Becken, Schrott-Ader, Lithium-Quelle, Fluor-Quelle). Jede wird einmal erforscht, danach ist die Anzahl nur durch die (sehr teure)
-- Herstellung begrenzt.
-- Kosten: 10000 x Basis-Packs + eigener Planeten-Pack (seit 1.13.0 auf Wunsch des Users sehr teuer, vorher 1000).
-- Der kryogene Pack setzt im Grundspiel schon alle anderen voraus, Aquilo verlangt sie deshalb mit.

local costs = {}

costs.COUNT = 10000

local BASE = {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "space-science-pack"}
local PLANET_PACKS = {"metallurgic-science-pack", "electromagnetic-science-pack", "agricultural-science-pack", "cryogenic-science-pack"}

-- Forschungskosten mit eigenem Planeten-Pack `own`
function costs.unit(own)
  local seen, ingredients = {}, {}
  local function add(pack)
    if not seen[pack] then
      seen[pack] = true
      table.insert(ingredients, {pack, 1})
    end
  end
  for _, pack in pairs(BASE) do add(pack) end
  if own == "cryogenic-science-pack" then
    add("production-science-pack")
    add("utility-science-pack")
    for _, pack in pairs(PLANET_PACKS) do add(pack) end
  end
  add(own)
  return {count = costs.COUNT, ingredients = ingredients, time = 60}
end

return costs
