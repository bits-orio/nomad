-- Laeuft in data-final-fixes, damit auch Prototypen aus anderen Mods fertig sind.
-- (Die Mutterschiff-Ausbauten pro Planet wurden in 1.12.0 entfernt, das Schiff hat keine Grenzen mehr.)

-- Labor-Regeln hier, damit Labore aus Planeten-Mods (die Eingaben teils erst in data-final-fixes setzen) erfasst sind.
require("prototypes.lab-rules")
require("prototypes.spacesuit-character")

-- Regel-Varianten fuer Planeten (je nach Einstellung): A = nur Abbau, C = Space-Age-Gebaeude nur im All
require("prototypes.variant-a")
require("prototypes.variant-b")
-- Variante D: Abfuellstation (braucht die Fass-Rezepte aus data-updates)
require("prototypes.barrel-station")
-- Gefangenes Beissernest auch im All (alle Varianten), nach den Varianten
require("prototypes.space-also")

-- Phase 6: Rekombinator-Rezepte pro Item
require("prototypes.recombination-recipes")

-- Hauptmenue (seit 1.24.1, Wunsch des Users): im Hintergrund nur Raumschiff-Szenen. Space Age hat drei
-- (platform_science, platform_moving, platform_messy_nuclear). Gibt es keine (ohne Space Age), bleibt alles.
do
  local constants = data.raw["utility-constants"] and data.raw["utility-constants"]["default"]
  -- Standbild hinter dem Menue (wenn die Menue-Szenen ausgeschaltet sind): Vanilla-Bild mit NOMAD-Schriftzug.
  -- Der Ladebildschirm beim Spielstart kommt vor den Mods und ist nicht aenderbar.
  if constants then
    constants.main_menu_background_image_location = "__nomad__/graphics/menu/nomad-background.jpg"
  end
  local sims = constants and constants.main_menu_simulations
  if sims then
    local ships = {}
    for name, sim in pairs(sims) do
      if string.sub(name, 1, 9) == "platform_" then ships[name] = sim end
    end
    if next(ships) then
      constants.main_menu_simulations = ships
      -- Schriftzug "NOMAD" ueber dem Factorio-Logo. Das Logo ist kein GUI-Element, sondern ein Gebaeude
      -- (factorio-logo-11tiles) in der Szene; darueber zeichnet die Szene das Bild per rendering.
      -- Kein Gebaeude: create_entity rastet auf halbe/ganze Felder ein, Feinjustierung war damit unmoeglich.
      data:extend({{
        type = "sprite",
        name = "ncs-menu-logo",
        filename = "__nomad__/graphics/menu/nomad-menu-logo.png",
        width = 704,
        height = 197,
        scale = 0.5,
      }})
      local add_logo = [[
        do
          local s = game.surfaces["platform-1"]
          local logo = s and s.find_entities_filtered{name = "factorio-logo-11tiles", limit = 1}[1]
          if logo then
            -- 11 Felder breit (wie "FACTORIO"), knapp ueber dem Logo. Ausgangspunkt war die eingerastete
            -- Gebaeude-Position {-0,5, -3}, die dem User fast passte ("ein bisschen weiter rechts").
            rendering.draw_sprite{sprite = "ncs-menu-logo", surface = s, render_layer = "object",
              target = {logo.position.x - 0.25, logo.position.y - 3}}
            -- Kamera (Vanilla: Logo + 9,75) um die halbe Zusatzhoehe hoch, damit Logo + NOMAD als Block sitzen
            game.simulation.camera_position = {logo.position.x, logo.position.y + 8.15}
          end
        end
      ]]
      for _, sim in pairs(ships) do
        sim.init = (sim.init or "") .. "\n" .. add_logo
      end
    end
  end
end

-- Erkennbare Bilder fuer Boden-Items und Mod-Forschungen
require("prototypes.tech-icons")

-- Einstellung "Forschungskosten (Nomad)": Faktor auf die Anzahl Packs jeder Nomad-Forschung (ncs-*).
-- Forschungen aus dem Grundspiel und Space Age bleiben unveraendert.
do
  local factor = settings.startup["ncs-research-cost"].value
  if factor ~= 1 then
    for name, tech in pairs(data.raw.technology) do
      if string.sub(name, 1, 4) == "ncs-" and tech.unit then
        if tech.unit.count then
          tech.unit.count = math.max(1, math.floor(tech.unit.count * factor + 0.5))
        elseif tech.unit.count_formula then
          tech.unit.count_formula = factor .. "*(" .. tech.unit.count_formula .. ")"
        end
      end
    end
  end
end

-- "(Nomad)" hinter dem Namen jeder Mod-Forschung, damit die Suche im Forschungsbaum sie findet (seit 1.24.1,
-- Wunsch des Users; die Suche schaut nur auf Namen, nicht auf Beschreibungen, im Spiel geprueft).
-- Stufen-Forschungen (name-1 ... name-5) nutzen wie im Spiel den Namen ohne Stufe, die Stufe haengt die Engine an.
for name, tech in pairs(data.raw.technology) do
  if string.sub(name, 1, 4) == "ncs-" and name ~= "ncs-nomad-achieved" then -- "Nomade vollendet" hat Nomad schon im Namen
    local key = string.match(name, "^(.-)%-%d+$") or name
    tech.localised_name = {"ncs-tech.mod-name", tech.localised_name or {"technology-name." .. key}}
  end
end
