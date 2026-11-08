-- Mit Inventar in die Rakete (scripts/rocket-ride.lua): Diese Taste haengt an "Einsteigen" (Enter) und loest vor dem
-- Spiel aus. So kann das Skript das Inventar verstauen, bevor Space Age "Inventar muss leer sein" prueft.

data:extend(
{
  {
    type = "custom-input",
    name = "ncs-board-rocket",
    key_sequence = "",
    linked_game_control = "toggle-driving"
  }
})
