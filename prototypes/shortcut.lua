-- Knopf in der Shortcut-Leiste (rechts neben der Schnellleiste): Info-Fenster "Mutterschiff" mit Stand und Upgrades.

data:extend(
{
  {
    type = "shortcut",
    name = "ncs-mothership-info",
    order = "z[ncs]-b[mothership-info]",
    action = "lua",
    icon = "__space-age__/graphics/icons/space-platform-hub.png",
    icon_size = 64,
    small_icon = "__space-age__/graphics/icons/space-platform-hub.png",
    small_icon_size = 64
  }
})
