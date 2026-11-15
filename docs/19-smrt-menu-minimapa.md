# 19 — Menú e icono del minimapa en SMRT (referencia para F6e)

Fuente única: `C:\Users\Usuario\Documents\Workspace\SMRT\SMRT\wow\MinimapButton.lua` (218 líneas, leído entero).
Citas `archivo:línea` relativas a `SMRT/` salvo indicación.

## 1. Veredicto corto

SMRT **NO usa LibDBIcon ni LibDataBroker**: botón propio hecho a mano (`wow/MinimapButton.lua:11-12`: «LibDBIcon-1.0 is not vendored and AGENTS.md section 4 does not allow adding a dependency without an ADR»). El menú es **`Craft.Menu`** (no MenuUtil/Blizzard_Menu/EasyMenu). El tooltip es un `GameTooltip` propio. QDT ya tiene LibDBIcon vendoreada, así que **solo se copia la parte de menú/tooltip/clics, no el botón**.

## 2. Botón

- `CreateFrame("Button", "SMRT_MinimapButton", Minimap)`, 31x31, strata MEDIUM, nivel `Minimap:GetFrameLevel()+8` (`:141-144`).
- Icono 19x19 propio, borde `Interface\Minimap\MiniMap-TrackingBorder` 53x53, highlight `UI-Minimap-ZoomButton-Highlight` (`:149-161`).
- Creado desde `wow/Bootstrap.lua:193` (`if ns.MinimapButton then ns.MinimapButton.Create() end`); cargado en `SMRT.toc:161`.
- Posición: ángulo alrededor del minimapa, RADIUS 80, defecto 215° (`:19-20`, `place` `:119-123`).
- Arrastre: `RegisterForDrag("LeftButton")`, `OnDragStart` pone un `OnUpdate` que calcula `atan2` del cursor respecto al centro y guarda `db().angle` (`:127-136`, `:163-168`).

## 3. Clics (`:170-180`)

| Acción | Resultado |
|---|---|
| Clic izquierdo | `ns.ConfigWindow.Toggle()` (abre/cierra la ventana de opciones) |
| Mayús + clic izq. | `ns.Timeline.Open()` si el módulo está activo (atajo); si no, Toggle de ventana |
| Clic derecho | cierra tooltip y abre el menú `Craft.Menu` |
| Arrastre izq. | recoloca el botón en el aro |

```lua
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:SetScript("OnClick", function(self, click)
  if menu then menu:Close() end
  if click == "RightButton" then
    getTooltip():Hide()
    openMenu(self)
  elseif IsShiftKeyDown() and tlOn() then
    ns.Timeline.Open()
  elseif ns.ConfigWindow then
    ns.ConfigWindow.Toggle()
  end
end)
```

## 4. Menú contextual (Craft.Menu)

Se reconstruye en cada apertura (`:34-47`, el estado de módulos puede cambiar). Items `{ label, icon (lucide), disabled, onClick }` y `{ type = "separator" }`. Instancia perezosa y reutilizada; sin Craft.Menu (build viejo) degrada a otra acción (`:49-59`):

```lua
menu = menu or Craft.Menu:Create({ width = 180 })
menu:SetItems(menuItems())
menu:Open(anchor, { point = "TOPRIGHT", relativePoint = "BOTTOMLEFT", x = 8, y = 8 })
```

Contenido: Timeline, Notes, separador, Opciones, Modo edición. Nota: QDT ya tiene `Craft.Menu` vendoreado (`QuantumDungeonTools/libs/Craft/components/Menu.lua:131`, `Menu:Create`), así que la API es la misma.

## 5. Tooltip (`:61-111`)

- `CreateFrame("GameTooltip", "SMRT_MinimapTooltip", UIParent, "GameTooltipTemplate")` propio, NO el GameTooltip compartido (para no filtrar la fuente Inter a otros tooltips).
- Logo 48px hijo anclado a la izquierda (`:75-80`).
- Anclaje replicando LibDBIcon (`tooltipAnchor`, `:87-93`): debajo si el botón está en mitad superior, y pegado al borde según tercio de pantalla; `SetOwner(self, "ANCHOR_NONE")` + `SetPoint(tooltipAnchor(self))`.
- Líneas (`:187-191`): título, `L.MINIMAP_LEFT`, `L.MINIMAP_RIGHT`, `L.MINIMAP_SHIFT` (blanco), `L.MINIMAP_DRAG` (gris 0.6). Fuentes Inter vía `Craft.mediaPath` tras añadir líneas (`applyFonts`, `:97-111`); sin Craft usa la fuente por defecto.
- `OnLeave` oculta el tooltip.

## 6. Persistencia y ocultación

- `ns.db.minimap = { angle, hide }` (`:113-117`). `hide` se lee en `Create` (`:200`).
- Slash: `/smrt minimap` → `MinimapButton.Toggle()` (`Config.lua:116-118`, imprime `L.MINIMAP_SHOWN/HIDDEN`).
- Ajuste: Switch en la página General de opciones (`wow/GeneralOptions.lua:25-28`, sincroniza con `IsShown()` en `:66`).

## 7. Qué copiar para QDT F6e

1. **No copiar el botón a mano**: QDT ya vendorea LibDBIcon; usar `LDB:NewDataObject` + `LibDBIcon:Register(name, obj, QDT.db.minimap)`. LibDBIcon ya aporta arrastre, ángulo y `hide` guardados en la tabla que se le pasa (`{ hide = false, minimapPos = 215 }`), y `LibDBIcon:Show/Hide` para el slash/ajuste. Ahorra los ~60 líneas de SMRT.
2. **Clics**: en el objeto LDB `OnClick(self, button)`: `RightButton` → menú; mayús+clic → Historial; clic → Inicio. Misma estructura que `:170-180`. `RegisterForClicks` lo hace LibDBIcon.
3. **Clic derecho = menú `Craft.Menu`** (opcional pero barato; ya está en `libs/Craft`): `Menu:Create({width=180})` una vez, `SetItems` en cada apertura, `Open(self, {point="TOPRIGHT", relativePoint="BOTTOMLEFT", x=8, y=8})`. Items sugeridos: Inicio, Historial, separador, Ajustes. Mantener el fallback si `Craft.Menu` falta. Si el owner no quiere menú, omitirlo: clic = Inicio, mayús = Historial basta.
4. **Tooltip**: con LDB basta `OnTooltipShow(tip)` o `OnEnter` (LibDBIcon posiciona el GameTooltip solo, `tooltipAnchor` de SMRT no hace falta). Si se quiere Inter sin contaminar el GameTooltip global, copiar el patrón de tooltip propio (`:72-82` + `applyFonts`), pero es coste extra: solo si el diseño lo pide. Líneas: título, «Clic: Inicio», «Mayús+clic: Historial», «Arrastrar: mover».
5. **Ocultar**: copiar `/qdt minimap` (Toggle + mensaje) y un Switch en ajustes (`GeneralOptions.lua:25-28`); con LibDBIcon el Toggle es `db.minimap.hide = not hide; LibDBIcon[hide and "Hide" or "Show"](LibDBIcon, name)`.
6. **Avisos**: (a) el icono de SMRT es una moneda redonda propia; un icono provisional de Blizzard (el actual de F6e) encaja igual en el aro de LibDBIcon. (b) Regla del proyecto: color/estilo del tooltip solo de la paleta (memoria «Colores solo de la paleta»). (c) Según memoria «Diseño antes que código», el menú (contenido/estilo) espera el OK del lienzo.
