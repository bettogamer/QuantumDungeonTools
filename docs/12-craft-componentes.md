# 12 — Componentes de Craft aplicables a QDT

> Revisión de Craft v2.48.0 (build 50, vendoreado READ-ONLY en `QuantumDungeonTools/libs/Craft/`) frente
> a lo que el addon pinta hoy y a lo que el plan M1 (F2-F6) va a pintar. Fecha: 2026-11-13.
> Solo lectura/diagnóstico: no hay cambios de código ni FRs creados. Las referencias `archivo:línea` de
> UI.lua y de Craft están abiertas y verificadas; lo marcado «(no probado)» es lectura, no medida in-game.

Componentes disponibles en `libs/Craft/components/`: Avatar, Badge, Button, Checkbox, CodeEditor, ColorSwatch,
Combobox, Dialog, DragList, Empty, Field, Input, Label, Menu, Panel, Popover, Progress, ProgressRing,
RadioGroup, Scroll, ScrollBar, Section, Select, Separator, Sidebar, Slider, Switch, Tabs, Textarea,
Toast, Toggle, ToggleGroup, Tooltip, Window. Más `layout/Flex`, `layout/Grid`, `theme/{Theme,Presets,
RoundedSurface,Shapes}`, `icons/` y `Reactive.lua`.

## 1. Qué usa hoy UI.lua de Craft y qué está a mano

**De Craft (4 usos):**

| Uso | Dónde | Para qué |
|---|---|---|
| `Craft.Theme.context(THEME_NAME, {...})` | `UI.lua:741` | contexto de tema propio (no toca Coffer & co.) |
| `Craft.Theme.resolve(nil, {theme=ctx}, root)` | `UI.lua:623` | marca el frame raíz para que los overlays de Craft hereden el contexto |
| `ctx:applyFont` / `ctx:getFont` | `UI.lua:49` | fuentes BettoGeo con sondas asíncronas de métricas |
| `Craft.Theme.AnchorBorder` | `UI.lua:72` | borde de 1 px sin esquinas dobles (4 texturas) |
| `Craft.Tooltip.Attach(f, {lines, fontFlags="", side="bottom", delay=150})` | `UI.lua:578` | detalle de jefes en el modo compacto |

**A mano (todo lo demás):**

| Pieza | Dónde | Nota |
|---|---|---|
| `newBorder`/`colorBorder` (anillo de 4 texturas) | `UI.lua:69-78` | envoltorio de `AnchorBorder` |
| **Tags** (`newTag`/`setTag`): marco + FontString + borde, medida con `GetStringWidth/Height`, descender `DESCENT` a mano | `UI.lua:81-99`, `descentOf` `UI.lua:132-139`; usos: `W.diff` 225, `W.first` 236, `W.record` 241, `W.instances` 281, `r.tag` (RARE) 306 | candidatos directos a `Craft.Badge` |
| Alineación por línea base (`chainBaseline`) | `UI.lua:146-169` | hoy mezcla FontStrings y tags con `DESCENT = 192/932` fijo (`UI.lua:39`) |
| Barra de tiempo 14 px + borde + segmentos por jefe (`barTrack/barFill/barBorder`, segmentos) | `UI.lua:246-249, 314-335` | texturas planas, marcadores |
| Barra de XP (pista + descansado + actual + base) | `UI.lua:259-268` | cuatro capas de textura |
| Fondo + borde + separadores del modo compacto | `UI.lua:567-583` | `K.bg`, `K.border`, `K.sep1/2` |
| Texto con sombra y contorno propio | `newText` `UI.lua:52-61` | `SetShadowOffset(1,-1)` |
| Raíz, filas, posición, click-through | `UI.lua:564, 622` | `CreateFrame("Frame")` sin Flex |

## 2. Sustituciones inmediatas

### 2.1 Tags -> `Craft.Badge` (FR-140, ya en el build 50) — encaje ALTO
Lo pedimos nosotros (`craft/docs/requests/FR-140-badge-colores-y-tamano-compacto.md`) y la demo de Craft trae
«los cinco tags de QDT» (CHANGELOG 2.48.0). Equivalencias con la config actual:

```lua
local b = Craft.Badge:Create(parent, {          -- (firma verificada: Badge.lua:58 `Badge:Create(parent, config)`)
  text = "Normal", variant = "outline",
  textColor = C.sand, borderColor = C.goldSoft, fillColor = nil,   -- {r,g,b,a} o token
  fontSize = 11, fontWeight = "bold",                               -- "regular"|"medium"|"bold"
  paddingX = S.tagPadX, paddingY = S.tagPadY,                       -- 6 / 1 hoy
  fontFlags = "",                                                   -- sin contorno propio del tema
})
b:SetText(t); b:SetColors({ text=, border=, fill= })                -- Badge.lua:352 / 370
b:GetFrame()                                                         -- Badge.lua:401 (anclar/mostrar)
b:GetBaselineOffset()                                                -- Badge.lua:379
```
- Con `fontSize`/`paddingY` el alto sale del texto (`línea + 2·padY + 2·px`; `Badge.lua:322-324`), como el
  `th + 2·padY + 2` de `setTag`. El centrado (cap nudge 0.1 em, ancla TOPLEFT en píxeles enteros) lo hace
  `Theme.placeText` (`Badge.lua:328`): **desaparece** el `-floor(th*DESCENT/2+0.5)` a mano de `UI.lua:98`.
- `GetBaselineOffset()` sustituye a `descentOf` para tags (`UI.lua:134-137`) y encaja con `chainBaseline`.
  Los FontStrings siguen necesitando `DESCENT`; el offset del Badge es «preciso al píxel de redondeo»
  (comentario `Badge.lua:376-378`), usa un ratio genérico 0.2 (`Badge.lua:50`) frente a nuestro 0.206.
- `fontFlags` por instancia existe (`Badge.lua:73`): `""` evita el contorno global del tema (importante: el
  tag es solo borde, sin relleno).
- Colores con alfa (`C.goldSoft`, `C.mutedHalf`, `C.xpLightHalf`): `borderColor` acepta `{r,g,b,a}`; el
  borde cuadrado ya es anillo de 1 px, sin tinte interior (`Badge.lua:100-104`). `pill = true` -> RoundedSurface.
- **Riesgos:** (a) Badge crea un `Button` con `EnableMouse(selectable)` falso -> click-through correcto
  (`Badge.lua:98`), pero verificar que no roba el hover del header; (b) re-mide al frame siguiente
  (`remeasureNextFrame`): el ancho del tag cambia un frame después de `SetText`, y `chainBaseline` lee
  `GetWidth` ya -> re-encadenar tras el frame o hacer `chain` dependiente de un callback; (c) el texto lo
  pinta el propio Badge: `C.shadow`/OUTLINE del HUD no se aplican salvo vía `fontFlags` y el tema (ahora
  usamos `SetShadowOffset(1,-1)` en `newText`; el Badge no); (d) bold 11 px con BettoGeo: el cap nudge se
  midió con Inter+BettoGeo (CHANGELOG), no probado en el rare de 9 px; (e) un `fontSize` de 9 queda fuera
  del `text-xs`: usar `fontSize` explícito.
- Coste/ganancia: -~20 líneas (`newTag`, `setTag`, rama de `descentOf`) y un único sitio de métricas.

### 2.2 Fondo+borde del modo compacto -> `Craft.RoundedSurface` o `Craft.Panel` — encaje MEDIO
`RoundedSurface.Create(frame, {layer, sublevel})` + `SetRadius(r)` + `SetFillColor` + `SetBorderColor` +
`Layout()` (`RoundedSurface.lua:28-34`). Con `r = 0` cae al anillo `AnchorBorder` + relleno inset 1 px
(`RoundedSurface.lua:22-23`) = lo que hace hoy `K.bg`+`K.border`. Gana: píxel entero y re-ajuste al cambiar
la escala (FR-142). Pierde: nada. Vale la pena solo si queremos esquinas redondeadas; con radio 0 es un
cambio cosmético. **No** sustituir el HUD completo: no hay fondo (memoria de estilo).

### 2.3 Contorno de las barras -> NO sustituir ya
`Craft.Progress` (`value/min/max/marker/width/height/variant/color`, doc `components/progress.md:159-166`) usa
un `StatusBar` nativo y acepta secretos, pero no tiene borde propio, ni segmentos, ni capas de descansado/base.
Nuestras barras (14 px, 4 capas de XP, marcadores por jefe) quedan mejor a mano. Ver §3 (`marker`).

### 2.4 `Craft.Theme.AnchorBorder` propio -> mantener
Sigue siendo la pieza correcta para `barBorder`/`xpBorder`/segmentos. No hay un «contorno» suelto mejor.

## 3. Componentes útiles para pantallas futuras (F4-F6 + config)

| Componente | Pantalla / uso | Encaje | Nota |
|---|---|---|---|
| `Tooltip` (`lines`/`title`, columnas, funciones, `delay`) | F4 Detalle (oro, reputación, ritmo, récord con este grupo) | **Alto** | ya usado en compacto. `lines` admite una cadena (1 col) o par (2 col, estilo `AddDoubleLine`, `Tooltip.lua:23-30`); `lines` puede ser función evaluada en cada hover (`:31`). Para monedas con icono: texto con `GetCoinTextureString` dentro de la línea |
| `Toast` (`Show(title,{description,type,icon,duration,action,id,container,fontFlags})`) | F5 toast de fin de run + botón «Compartir» (`action={label,onClick}`) | **Alto** | `id` actualiza en sitio; `container` permite anclar a nuestra ventana; módulo (sin `Create`) -> `Toast.Configure` para posición. Cuidado con `duration=math.huge` |
| `Window` | F6 Historial; ventana de ajustes | **Alto** | `FR-005`/`019` movible, redimensionable, headless; `SetBaseScale` re-ajusta píxeles |
| `Tabs` | Historial / Récords / Ajustes en una sola ventana | **Alto** | variantes `line`/`default`, `fill` |
| `Select` / `Combobox` | filtros de Historial: mazmorra, dificultad, personaje | **Alto** | Combobox si la lista de mazmorras es larga (buscar) |
| `Scroll` + `ScrollBar` + `Flex`/`Grid` | lista del Historial (100 runs) | **Alto** | `Flex` para cabecera/filas; sin virtualización documentada, 100 filas aceptables (no probado) |
| `Switch` / `Checkbox` / `Field` / `Section` | ajustes: activar/desactivar cada línea del widget, autoShow, Compacto | **Alto** | `Switch` por línea; `Field` agrupa etiqueta+control; `Section` separa bloques |
| `Slider` | escala del widget, opacidad, ancho | Medio | `FR-034` formato + paso |
| `Menu` (contexto) | clic derecho en una fila de Historial (borrar, compartir, marcar) y en el header | Medio | `FR-015`; `Menu.IsAnyOpen()` calla tooltips (FR-148) |
| `Dialog` | confirmar «Borrar historial» / «Reset del récord» | Medio | modal con strata propia (FR-033) |
| `Badge` | Historial: marcar récords, dificultad, «Primera vez»; chip filtrable (`selectable`) | Alto | mismo componente de §2.1 |
| `Button` / `Toggle` / `ToggleGroup` | acciones, filtro Completadas/Todas, ordenación | Medio | `Button` con icono Lucide |
| `Separator`, `Label`, `Empty` | separadores, textos, «Sin runs todavía» | Medio | `Empty` para el Historial vacío |
| `Progress` (`marker`) | Historial: barra mini de tiempo contra el récord (marcador) en una fila | Bajo-Medio | `value` secreto no aplica (no son magnitudes de combate) |
| `Popover` | ayudas contextuales de ajustes | Bajo | |
| `Avatar` | icono de mazmorra/personaje en filas | Bajo | |
| `Input` | buscar en el Historial | Medio | solo si crece; con `Combobox` basta |

Pantalla «Ajustes»: hoy `Config.lua:36-37` solo tiene `/qdt` por slash; no hay opciones UI. F6 añade
una `Window` con `Tabs` + `Section`/`Field`+`Switch`.

## 4. Descartados

| Componente | Por qué |
|---|---|
| `Panel`, `Sidebar` | llevan fondo y estructura de tarjeta; el HUD es transparente. Valdrían en la ventana Historial pero `Window` ya trae el marco |
| `ProgressRing` | no hay anillos en el diseño |
| `CodeEditor`, `Textarea`, `ColorSwatch`, `DragList`, `RadioGroup`, `Slider` (HUD) | sin caso de uso en M1 |
| `Craft.Progress` para las barras del HUD | ver §2.3: sin borde, segmentos ni capas; el relleno nativo no aporta nada porque nuestros valores son públicos (tiempos, XP) |
| `Toast` para avisos «a 10/10» persistentes | un toast se agota; para el aviso fijo, usar una línea del widget (ya prevista) o `Toast` con `duration=math.huge` + `id` |
| `Craft.Flex` para el HUD actual | el widget alinea por línea base y re-encadena derecha->izquierda; Flex no resuelve baseline (no probado `align="baseline"`) |

## 5. Huecos (candidatos a FR, solo listados)

1. **Badge/Text: control de sombra y contorno por instancia coherente con el HUD** (sombra 1,-1 + `OUTLINE` de tema) o aviso en doc de que `fontFlags=""` quita el contorno pero no pone la sombra.
2. **Alineación por línea base en Flex** (`align="baseline"`) con FontStrings y Badges: hoy cada consumidor reimplementa `DESCENT`.
3. **Badge: `GetBaselineOffset` documentado para fuentes específicas** (ratio 0.2 fijo vs 0.206 de BettoGeo; hasta 1 px de error en 42 px).
4. **Progress con borde 1 px y segmentos/marcadores múltiples** (barra de jefes) y capa secundaria (descansado/base de XP).
5. **Widget «money»** (`MoneyDisplay` de Coffer) como componente reutilizable de Craft.
6. **Lista virtualizada** en `Scroll` si el Historial supera ~100 filas con 4-5 columnas.
7. **Tooltip `lines` con textura de moneda** (`GetCoinTextureString`) y ancho medido sin `GetStringWidth` sobre secretos (ver §6).
8. **Click-through garantizado en overlays de Craft** sobre un HUD (hoy solo el header toma ratón; confirmar para Badge/Toast).
9. Un **modo HUD sin fondo** para `Window`/`Toast` (transparente + contorno), por si el aviso 10/10 debe parecerse al widget.

## 6. Riesgos: secret values y combate

- **Medida de texto.** Badge (`Badge.lua:335`), Tooltip y otros 19 componentes usan `GetStringWidth/Height`
  (55 ocurrencias). Con una cadena secreta `GetStringWidth()` devuelve **secreto** (global CLAUDE.md, caso
  «12.1: un número secreto SÍ se concatena»). En QDT el texto es **nuestro** (nombres de mazmorra, tiempos
  formateados, XP): públicos. Los riesgos reales: (a) nombres de jefe/mazmorra que vengan de
  `GetInstanceLockTimeRemainingEncounter` -> públicos por la sonda F1; (b) **`UnitName`/`UnitGUID` de criaturas
  dentro de la mazmorra son secretos en Forever** (global CLAUDE.md): **nunca** pasarlos a `Badge:SetText`,
  `Tooltip.lines` ni `Toast.Show` sin `issecretvalue` + descartar o poner placeholder; si no, el componente
  intentaría aritmética sobre un ancho secreto y rompería. Saneo en `View.lua` (puro, ya testeado), no en UI.
- **Cualquier número de combate** (daño, vida) quedaría fuera: QDT no lo muestra. XP/oro/tiempo salen de eventos
  públicos; entran al snapshot con `scrubNum` (plan F4).
- **Frames en combate:** crear frames (`Badge:Create`, `Toast.Show`) es seguro en 12.1.5 para addons (los
  marcos propios no son «protegidos»), pero conviene crear todo en `Init` y solo `SetText`/`SetColors` en combate.
  Evitar `Toast.Show` dentro de la ventana de encuentro si el toast ancla a nameplates (no lo hace: contenedor
  `UIParent`). Nameplates: **no anclar** nada nuestro a placas (restricted regions, `GetCenter` lanza).
- **Pool de componentes:** `Toast` reparte tarjetas de un pool; no debe recibir texto secreto (queda «marcado»).
- **Escala:** `Theme.RefreshPixels` re-ajusta en `UI_SCALE_CHANGED`; si escalamos nuestra raíz llamar a
  `Craft.Theme.RefreshPixels(root)` (mismo patrón que `Window:SetBaseScale`).
- **Vendoreo:** todo cambio en Craft = FR en `craft/docs/requests/`, nunca editar `libs/Craft/` (regla global).
  Build vendoreado: v2.48.0 build 50 @68ab8ea (commit `309f08d`).

## 7. Siguiente paso sugerido (sin ejecutar)
1. Migrar los cinco tags de `UI.lua` a `Craft.Badge` y borrar `newTag`/`setTag`/rama tag de `descentOf` (dentro de F2, antes de `ui-critic`).
2. Reutilizar `Tooltip` (F4), `Toast` (F5), `Window`+`Tabs`+`Select`+`Switch` (F6) tal cual.
3. Dejar barras y contorno a mano; abrir los FR de §5 solo si molestan.
