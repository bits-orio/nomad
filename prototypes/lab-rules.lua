-- Labore und Biolabore nur im All (Raumplattform: Druck 0, Schwerkraft 0).
-- Laeuft in data-final-fixes, damit Labore aus Planeten-Mods schon fertig sind.
--
-- Planetengebundene Sonderlabore (z. B. das Cerys-Labor, das eine nur auf Cerys vorhandene Strahlung braucht)
-- bleiben unveraendert: Druck und Schwerkraft zu ersetzen wuerde sie sonst nirgends mehr baubar machen.

local surface_util = require("prototypes.surface-util")

local space_only =
{
  {property = "pressure", max = 0},
  {property = "gravity", max = 0}
}

local exempt = {}
for name, lab in pairs(data.raw["lab"]) do
  -- Bedingungen ausser Druck/Schwerkraft bleiben (das Biolabor verlangt z. B. Druck 1000 = Nauvis,
  -- das wuerde sich mit "nur im All" ausschliessen und wird deshalb ersetzt).
  local conditions = {}
  for _, condition in pairs(lab.surface_conditions or {}) do
    if condition.property ~= "pressure" and condition.property ~= "gravity" then
      table.insert(conditions, condition)
    end
  end

  if not surface_util.allowed_in_space(conditions) then
    table.insert(exempt, name)
  else
    for _, condition in pairs(space_only) do
      table.insert(conditions, table.deepcopy(condition))
    end
    lab.surface_conditions = conditions
  end
end

if #exempt > 0 then
  table.sort(exempt)
  log("[nomad] Planetengebundene Labore, nicht aufs All beschraenkt: " .. table.concat(exempt, ", "))
end
