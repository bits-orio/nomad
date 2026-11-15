-- Gebaeude, die Space Age nur auf einem Planeten erlaubt, duerfen zusaetzlich ins All (alle Varianten, seit 1.0.4,
-- Wunsch des Users: das Schiff soll alles herstellen koennen).
--   Gefangenes Beissernest (captive-biter-spawner, chinesisch "Hive Incubator"): Vanilla nur Nauvis (Druck 1000).
-- "Planet X oder All" kennt Factorio nicht. Deshalb faellt die Bedingung ganz weg; scripts/planet-rules.lua baut das
-- Gebaeude auf Planeten, die die alte Bedingung nicht erfuellen, sofort wieder ab. Die alten Bedingungen stehen in
-- mod-data "ncs-space-also".
-- Laeuft in data-final-fixes nach den Varianten, damit Variante A/C das Gebaeude als "nur Planet" uebersprungen haben.

local SPACE_ALSO = {"captive-biter-spawner"}

local original = {}
for _, name in pairs(SPACE_ALSO) do
  for _, type_name in pairs({"assembling-machine", "furnace", "unit-spawner"}) do
    local prototype = data.raw[type_name] and data.raw[type_name][name]
    if prototype and prototype.surface_conditions then
      original[name] = prototype.surface_conditions
      prototype.surface_conditions = nil
    end
  end
end

data:extend({{type = "mod-data", name = "ncs-space-also", data = {conditions = original}}})
