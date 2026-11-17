-- Elektrischer Bohrer auf Wolframerz (Wunsch des Users 2026-11-17, gegen die Sackgasse "Wolfram braucht den grossen
-- Bohrer"): Der elektrische Bohrer darf "hard-solid" abbauen. Steht er auf Wolframerz (oder einem anderen
-- hard-solid-Erz), tauscht scripts/tungsten-drill.lua ihn gegen die versteckte Variante: sehr langsam und sie nimmt
-- beim Arbeiten Schaden. Der grosse Bohrer bleibt unveraendert.

return
{
  BASE = "electric-mining-drill",
  VARIANT = "electric-mining-drill-ncs-hard",
  SPEED_FACTOR = 0.1,      -- Abbautempo der Variante (Vanilla 0,5 -> 0,05; Wolframerz 5 s -> 0,6 Erz/min)
  DAMAGE_PER_SECOND = 0.25, -- solange sie arbeitet; 300 HP -> nach 20 min kaputt (ca. 12 Erz)
  -- Forschung direkt nach "Vulcanus entdecken", Rot/Gruen/Blau (Wunsch des Users). Vorher gibt das Skript einen
  -- elektrischen Bohrer, in dessen Abbaugebiet Wolframerz liegt, sofort zurueck.
  TECH = "ncs-tungsten-drilling",
  TECH_COUNT = 250
}
