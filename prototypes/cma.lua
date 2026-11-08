-- Grafiken aus "CMA Graphics" (CC0, siehe graphics/cma/README.txt), angepasst aus deren lib/machine_graphics.lua:
-- nur die benoetigten Bilder liegen in graphics/cma/, die Sprite-Tabellen in prototypes/cma-sprites/.
--
--   local cma = require("prototypes.cma")
--   local G = cma.machine("deep-extractor", {variant = "mk3", direction = "north", size = 3})
--
-- size: Feldgroesse des eigenen Gebaeudes; der Sprite wird von seiner gezeichneten Groesse darauf skaliert.
-- G.working (Basis + Glow + Schatten), G.base, G.emission, G.shadow, G.idle (erstes Bild + Schatten),
-- G.idle_sprite (statisch, fuer Kisten), G.frozen (Aquilo), G.icon

local cma = {}

local PATH = "__nomad__/graphics/cma/"

-- Gezeichnete Groesse in Feldern (256 px bei Massstab 0,5 = 4 Felder)
local NATIVE =
{
  ["deep-extractor"] = 3, ["matter-printer"] = 4,
  ["containment-torus"] = 5
}

function cma.machine(name, opts)
  local all = require("prototypes.cma-sprites." .. name)
  local parts = {}
  if opts.variant then table.insert(parts, opts.variant) end
  if opts.direction then table.insert(parts, opts.direction) end
  local tag = table.concat(parts, "-")
  local S = all[tag]
  assert(S and S.main, "cma: kein Sprite-Satz '" .. tag .. "' fuer " .. name)
  local prefix = name .. "-" .. tag
  local dir = PATH .. name .. "/"
  local speed = opts.animation_speed or 0.5
  local scale = 0.5 * (opts.size or NATIVE[name]) / NATIVE[name]
  local k = scale / 0.5
  local n = S.main.frame_count

  local function shift(m) return {m.shift[1] * k, m.shift[2] * k} end
  local function sheet(file, m, extra)
    local layer = {filename = dir .. file, width = m.width, height = m.height, shift = shift(m), scale = scale,
      frame_count = m.frame_count, line_length = m.line_length, animation_speed = speed}
    for key, value in pairs(extra or {}) do layer[key] = value end
    return layer
  end

  local G = {}
  G.base = sheet(prefix .. "-hr-animation.png", S.main)
  G.emission = sheet(prefix .. "-hr-emission.png", S.emission, {draw_as_glow = true, blend_mode = "additive"})
  G.shadow = {filename = dir .. prefix .. "-hr-shadow.png", width = S.shadow.width, height = S.shadow.height,
    shift = shift(S.shadow), scale = scale, draw_as_shadow = true, frame_count = 1, repeat_count = n,
    animation_speed = speed}
  local idle = {filename = dir .. prefix .. "-hr-idle.png", width = S.idle.width, height = S.idle.height,
    shift = shift(S.idle), scale = scale}
  G.idle = {layers = {
    {filename = idle.filename, width = idle.width, height = idle.height, shift = idle.shift, scale = scale,
      frame_count = 1, repeat_count = n, animation_speed = speed},
    G.shadow}}
  G.idle_sprite = {layers = {idle,
    {filename = G.shadow.filename, width = G.shadow.width, height = G.shadow.height, shift = G.shadow.shift,
      scale = scale, draw_as_shadow = true}}}
  if S.frozen then
    G.frozen = {filename = dir .. prefix .. "-hr-frozen.png", width = S.frozen.width, height = S.frozen.height,
      shift = shift(S.frozen), scale = scale}
  end
  G.working = {layers = {G.base, G.emission, G.shadow}}
  G.icon = PATH .. "icons/" .. name .. "-" .. opts.variant .. ".png"
  return G
end

-- Grafik fuer Assembler/Oefen: Basis-Animation laeuft beim Arbeiten, Glow nur beim Arbeiten.
-- directions = true: vier Richtungen (Sprites pro Richtung), sonst eine.
function cma.crafting_graphics(name, variant, size, directions)
  local function build(direction)
    return cma.machine(name, {variant = variant, direction = direction, size = size})
  end
  if directions then
    local animation, glow, frozen = {}, {fadeout = true}, {}
    local icon
    for _, d in pairs({"north", "east", "south", "west"}) do
      local G = build(d)
      animation[d] = {layers = {G.base, G.shadow}}
      glow[d .. "_animation"] = G.emission
      frozen[d] = G.frozen
      icon = icon or G.icon
    end
    return {animation = animation, working_visualisations = {glow}, frozen_patch = frozen}, icon
  end
  local G = build(nil)
  return
  {
    animation = {layers = {G.base, G.shadow}},
    working_visualisations = {{fadeout = true, animation = G.emission}},
    frozen_patch = G.frozen
  }, G.icon
end

return cma
