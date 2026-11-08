-- Raketen-Traglast: gemeinsame Daten fuer prototypes/rocket-capacity.lua (Datenphase) und
-- scripts/rocket-capacity.lua (Laufzeit).

local config = {}

-- Silos, die mit der Forschung staerker werden (Original-Namen = Item-Namen)
config.BASES = {"rocket-silo", "ncs-supply-capsule"}

-- Traglast pro Stufe als Vielfaches des Originals (Silo 1 t -> 5 t, Kapsel 250 kg -> 1,25 t)
config.FACTORS = {1.5, 2, 3, 4, 5}

-- Forschungskosten pro Stufe (sehr teuer, Wunsch des Users)
config.COSTS = {5000, 10000, 15000, 20000, 25000}

config.TECH_PREFIX = "ncs-rocket-capacity-"

function config.variant_name(base_name, level)
  return base_name .. "-ncs-l" .. level
end

return config
