-- Roboter-Granaten: gemeinsam fuer prototypes/robot-shells.lua (Daten) und scripts/robot-shells.lua (Laufzeit).

local config = {}

config.ROBOTS = 10    -- Roboter pro Granate (und Kapseln im Rezept)
config.SPREAD = 3     -- Streuung beim Einschlag in Feldern
config.RESEARCH = 3000 -- Forschungskosten je Granate (Packs wie Artillerie; seit 1.24.1 3000, vorher 1000)

-- Jagd (scripts/robot-shells.lua): Jeden Tick fliegen die Roboter STEP Felder auf ihr Ziel zu, bis sie STOP Felder
-- davor sind (in Waffenreichweite). Ziele sucht das Skript im Umkreis SEARCH, neu alle SEARCH_TICKS.
-- Kampfroboter lassen sich nicht befehligen (follow_target nur fuer Spinnen), deshalb Teleport in kleinen Schritten.
-- Seit 1.24.1 jeden Tick (vorher alle 12 Ticks 2,4 Felder, im Spiel "sehr stotterig"). Laeuft im on_nth_tick(1)-
-- Handler von control.lua zusammen mit dem Triebwerk-Boost (gleicher Takt wuerde den Handler ersetzen).
config.STEP = 0.1      -- 6 Felder pro Sekunde (seit 1.24.1, vorher 0,2 = 12/s, dem User zu schnell)
config.STOP = 8
config.SEARCH = 100
config.SEARCH_TICKS = 60
-- Radar (Wunsch des Users): Jeder Roboter deckt alle CHART_TICKS die Karte im Umkreis CHART_RADIUS auf (etwa ein Chunk
-- in jede Richtung).
config.CHART_RADIUS = 32
config.CHART_TICKS = 60

config.KINDS =
{
  {robot = "distractor", capsule = "distractor-capsule", technology = "distractor"},
  {robot = "defender", capsule = "defender-capsule", technology = "defender"},
  {robot = "destroyer", capsule = "destroyer-capsule", technology = "destroyer"}
}

config.ROBOT_NAMES = {}
for _, kind in pairs(config.KINDS) do
  kind.shell = "ncs-" .. kind.robot .. "-artillery-shell"
  kind.projectile = "ncs-" .. kind.robot .. "-artillery-projectile"
  config.ROBOT_NAMES[kind.robot] = true
end

return config
