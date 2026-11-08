-- Schiffs-Quellen: unendliche Lagerstaetten, die man aufs Fundament stellt (Fulgora: Schrott, Aquilo: Lithium, Fluor).
-- Gemeinsam genutzt von prototypes/sources.lua (Datenphase) und scripts/sources.lua (Laufzeit).
-- Zahlen sind vorlaeufig und werden beim Testen festgelegt.
--
-- Je Quelle:
--   item / marker / resource: Namen von Item, Markierung (3x3) und unendlicher Lagerstaette
--   template:   Vorlage der Lagerstaette (Vanilla-Rohstoff)
--   amount:     Menge = "normal" der Lagerstaette, also volle Abbaugeschwindigkeit, wird nie weniger
--   tiles:      true = Lagerstaette auf allen 3x3 Feldern (feste Rohstoffe, Bohrer),
--               false = eine Lagerstaette in der Mitte (Fluessigkeiten, Pumpe)
--   chain:      Freischalt-Forschung (siehe config.chains)

local config = {}

config.sources =
{
  {
    item = "ncs-scrap-vein", marker = "ncs-scrap-vein-marker", resource = "ncs-scrap-vein",
    template = "scrap", amount = 1000, tiles = true, chain = "ncs-scrap-vein",
    icon = "__space-age__/graphics/icons/scrap.png", tint = {r = 0.8, g = 0.85, b = 1}
  },
  {
    item = "ncs-lithium-source", marker = "ncs-lithium-source-marker", resource = "ncs-lithium-source",
    template = "lithium-brine", amount = 50000, tiles = false, chain = "ncs-lithium-source",
    icon = "__space-age__/graphics/icons/fluid/lithium-brine.png", tint = {r = 0.85, g = 0.9, b = 1}
  },
  {
    item = "ncs-fluorine-source", marker = "ncs-fluorine-source-marker", resource = "ncs-fluorine-source",
    template = "fluorine-vent", amount = 100000, tiles = false, chain = "ncs-fluorine-source",
    icon = "__space-age__/graphics/icons/fluid/fluorine.png", tint = {r = 0.9, g = 1, b = 0.85}
  },
  -- Seit 1.16.0: Vulcanus (Wolfram, Calcit) und Nauvis (Rohoel, Uran), damit das Schiff im Lategame
  -- auch ohne Planeten auskommt.
  {
    item = "ncs-tungsten-vein", marker = "ncs-tungsten-vein-marker", resource = "ncs-tungsten-vein",
    template = "tungsten-ore", amount = 1000, tiles = true, chain = "ncs-tungsten-vein",
    icon = "__space-age__/graphics/icons/tungsten-ore.png", tint = {r = 0.85, g = 0.85, b = 1}
  },
  {
    item = "ncs-calcite-vein", marker = "ncs-calcite-vein-marker", resource = "ncs-calcite-vein",
    template = "calcite", amount = 1000, tiles = true, chain = "ncs-calcite-vein",
    icon = "__space-age__/graphics/icons/calcite.png", tint = {r = 0.9, g = 0.9, b = 1}
  },
  {
    item = "ncs-oil-source", marker = "ncs-oil-source-marker", resource = "ncs-oil-source",
    template = "crude-oil", amount = 300000, tiles = false, chain = "ncs-oil-source",
    icon = "__base__/graphics/icons/fluid/crude-oil.png", tint = {r = 0.9, g = 0.9, b = 1}
  },
  {
    item = "ncs-uranium-vein", marker = "ncs-uranium-vein-marker", resource = "ncs-uranium-vein",
    template = "uranium-ore", amount = 1000, tiles = true, chain = "ncs-uranium-vein",
    icon = "__base__/graphics/icons/uranium-ore.png", tint = {r = 0.85, g = 1, b = 0.85}
  }
}

-- Freischalt-Forschungen: erlauben den Abbau ihrer Quelle (ncs-ammonia-zone: des Ammoniak-Beckens) mit dem
-- Boden-Extraktor (scripts/extractor-config.lua). Jede Quelle und jeder Boden hat eine eigene Forschung (seit 1.13.0).
config.chains =
{
  {
    technology = "ncs-scrap-vein",
    pack = "electromagnetic-science-pack",
    icon = "__space-age__/graphics/technology/scrap-recycling-productivity.png"
  },
  {
    technology = "ncs-lithium-source",
    pack = "cryogenic-science-pack",
    icon = "__space-age__/graphics/technology/lithium-processing.png"
  },
  {
    technology = "ncs-fluorine-source",
    pack = "cryogenic-science-pack",
    icon = "__space-age__/graphics/technology/cryogenic-plant.png"
  },
  {
    technology = "ncs-ammonia-zone",
    pack = "cryogenic-science-pack",
    icon = "__space-age__/graphics/technology/aquilo.png"
  },
  {
    technology = "ncs-tungsten-vein",
    pack = "metallurgic-science-pack",
    icon = "__space-age__/graphics/technology/tungsten-carbide.png"
  },
  {
    technology = "ncs-calcite-vein",
    pack = "metallurgic-science-pack",
    icon = "__space-age__/graphics/technology/calcite-processing.png"
  },
  -- Nauvis hat keinen eigenen Planeten-Pack, deshalb Produktion
  {
    technology = "ncs-oil-source",
    pack = "production-science-pack",
    icon = "__base__/graphics/technology/oil-gathering.png"
  },
  {
    technology = "ncs-uranium-vein",
    pack = "production-science-pack",
    icon = "__base__/graphics/technology/uranium-mining.png"
  }
}
-- Kosten: prototypes/upgrade-costs.lua (pack = eigener Planeten-Pack, zugleich Voraussetzung).

return config
