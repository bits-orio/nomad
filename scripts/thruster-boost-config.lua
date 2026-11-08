-- Triebwerk-Boost: gemeinsame Daten fuer prototypes/ship-balance.lua (Datenphase) und scripts/thruster-boost.lua
-- (Laufzeit). Jede Stufe erhoeht das Reisetempo aller Schiffe der Force.

local config = {}

-- Reisetempo pro Stufe als Vielfaches des Originals
config.FACTORS = {1.2, 1.4, 1.6, 1.8, 2}

-- Forschungskosten pro Stufe (sehr teuer, Wunsch des Users)
config.COSTS = {5000, 10000, 15000, 20000, 25000}

config.TECH_PREFIX = "ncs-thruster-boost-"

return config
