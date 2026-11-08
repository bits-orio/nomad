-- Volle Tanks auf dem Startschiff (seit 1.24.1, Wunsch des Users: "alle Tanks voll, Wasser und Treibstoff").
-- Welcher Tank wofuer ist, steht nicht im Blueprint, und ein frisches Rohrnetz nimmt jede Fluessigkeit an. Deshalb:
--   1. seed: Jede Fabrik mit Rezept bekommt etwas von ihren fluessigen Produkten in den Ausgang (Treibstoff-Werk ->
--      Treibstoff, Eisschmelzer -> Wasser ...). Die Engine verteilt das in die angeschlossenen Rohre und Tanks.
--   2. fill (WAIT Ticks spaeter): Jeder Tank wird mit der Fluessigkeit, die darin angekommen ist, bis zum Rand
--      gefuellt; Triebwerke bekommen Treibstoff und Oxidator voll.
-- Headless gegen das Nomad-Schiff geprueft: links Treibstoff, Mitte Wasser, rechts Oxidator.

local start_fluids = {}

local WAIT = 60
local SEED = 100
local FULL = 1000000 -- add_fluid fuellt hoechstens bis zur Kapazitaet

local function fill_by_filter(entity)
  for i = 1, entity.fluids_count do
    local filter = entity.get_fluid_filter(i)
    local name = type(filter) == "string" and filter or (filter and filter.name)
    if name then entity.add_fluid(i, {name = name, amount = FULL}) end
  end
end

function start_fluids.seed(platform)
  local surface = platform.surface
  for _, machine in pairs(surface.find_entities_filtered{type = {"assembling-machine", "furnace"}}) do
    local recipe = machine.get_recipe()
    if recipe then
      for _, product in pairs(recipe.products) do
        if product.type == "fluid" then
          for i = 1, machine.fluids_count do
            local filter = machine.get_fluid_filter(i)
            local name = type(filter) == "string" and filter or (filter and filter.name)
            if name == product.name then
              machine.add_fluid(i, {name = name, amount = SEED})
              break
            end
          end
        end
      end
    end
  end
  storage.start_fluids = storage.start_fluids or {}
  table.insert(storage.start_fluids, {platform = platform, tick = game.tick + WAIT})
end

local function fill(platform)
  local surface = platform.surface
  local tanks = 0
  for _, tank in pairs(surface.find_entities_filtered{type = "storage-tank"}) do
    local fluid = tank.get_fluid(1)
    if fluid then
      -- Ein Rohrnetz teilt sich die Fuellung mit Rohren und Maschinen: nachfuellen, bis nichts mehr hineingeht
      for _ = 1, 20 do
        if tank.add_fluid(1, {name = fluid.name, amount = FULL, temperature = fluid.temperature}) <= 0 then break end
      end
      tanks = tanks + 1
    end
  end
  for _, thruster in pairs(surface.find_entities_filtered{type = "thruster"}) do
    for _ = 1, 5 do fill_by_filter(thruster) end
  end
  log("[nomad] Startschiff: " .. tanks .. " Tanks gefuellt")
end

-- Jede Sekunde aus control.lua
function start_fluids.update()
  local list = storage.start_fluids
  if not list then return end
  for i = #list, 1, -1 do
    local entry = list[i]
    if not (entry.platform.valid and entry.platform.surface) then
      table.remove(list, i)
    elseif game.tick >= entry.tick then
      fill(entry.platform)
      table.remove(list, i)
    end
  end
  if #list == 0 then storage.start_fluids = nil end
end

return start_fluids
