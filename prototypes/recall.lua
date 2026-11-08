-- Rueckholstrahl (Laufzeit: scripts/recall.lua): holt den Spieler vom Planeten zurueck auf ein Schiff im Orbit,
-- ohne Raketensilo. Freigeschaltet mit dem Raketensilo und Weltraum-Science.

data:extend(
{
  {
    type = "technology",
    name = "ncs-recall-beam",
    icons = {{icon = "__space-age__/graphics/technology/space-platform.png", icon_size = 256, tint = {r = 0.7, g = 1, b = 0.7}}},
    effects = {{type = "nothing", effect_description = {"ncs-tech.recall-beam"}}},
    prerequisites = {"rocket-silo", "space-science-pack"},
    unit =
    {
      count = 5000,
      ingredients =
      {
        {"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1},
        {"space-science-pack", 1}
      },
      time = 60
    },
    order = "z[ncs]-r[recall-beam]"
  }
})
