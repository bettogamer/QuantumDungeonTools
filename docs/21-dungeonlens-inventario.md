# Inventario — DungeonLens 0.2.4 (competidor directo de Minimap Lens)

**Fecha:** 2026-11-15 · **Fuente:** `F:\Games\World of Warcraft\_forever_\Interface\AddOns\DungeonLens\` (`DungeonLens.lua` 338 líneas, `DungeonLens.toc`, `README.txt`), leído completo. Autores: «Jordan & Philo». `## Interface: 16001`, un solo archivo Lua, sin libs, sin XML, sin `SavedVariables`. Se estudia, no se copia (regla de licencias).

> Idea central: DungeonLens **no es una lente del minimapa en su sitio**. Abre una ventana modal centrada (`panel`, DIALOG) y **mueve el `Minimap` real dentro de ella**, escalado. No agranda en el sitio ni persiste nada. Es un prototipo declarado («experimental», README:3-4 de `.toc`, «This is a prototype, not yet tested in the Forever client», README.txt:79).

## 1. Qué hace

| Aspecto | Detalle | Ref. |
|---|---|---|
| Función | Minimapa vivo grande, centrado, en ventana con título, pie y botón cerrar | `DungeonLens.lua:13-42` |
| Disponibilidad | Solo en `party` o `raid` (`IsInInstance`); fuera avisa «Enter a dungeon or raid first» | `:48-51`, `:213-216` |
| Disparador principal | Tecla del mapa del mundo (M): override temporal de `TOGGLEWORLDMAP` hacia un botón oculto; solo dentro de mazmorra/banda | `:270-284` |
| Cerrar | M, Escape (`UISpecialFrames`), botón X, `/dlens close`; cierre automático al salir de la instancia | `:38-42`, `:289-291`, `:314-315` |
| Zoom | Fuerza `SetZoom(0)` (el más lejano) al abrir; restaura el zoom previo | `:259`, `:117` |
| Tamaño | Fijo: `min(70 % ancho UI, 68 % alto UI, 800)` px, **no configurable** | `:247-248` |
| Opacidad | No hay. Solo `/dlens status` imprime alpha local/efectivo | `:326-327` |
| Experimento «native» | Multiplica el tamaño de render del Minimap ×1/×2/×4 (límite 2048) para ver si aumenta el alcance; por defecto ×4 | `:5`, `:132-145`, `:241-245` |
| SavedVariables | **Ninguna.** «A manual mode choice is never saved» | README.txt:33-34, :86 |
| Configuración/UI de ajustes | Ninguna |  — |

Comandos (`:295-337`):

| Comando | Efecto |
|---|---|
| `/dlens` | alterna la lente |
| `/dlens native 2` / `native 4` / `normal` | cierra, cambia `nativeFactor` y reabre; imprime tamaño de render y radio de vista |
| `/dlens world` | cierra y llama `ToggleWorldMap()` (la tecla M queda secuestrada dentro de mazmorra) |
| `/dlens close` | cierra |
| `/dlens status` | build, interface, parent del Minimap, tamaño, escala, alpha, radio, resets de layout |

## 2. Cómo manipula el Minimap

**Frame objetivo:** el propio `Minimap` (`:223`), con comentario de que suites como MelloUI lo reparentan y dejan `MinimapCluster` vacío (`:221-222`). **No toca `MinimapCluster` ni `MinimapBackdrop` como contenedor**; solo oculta algunas decoraciones del cluster (ver §3).

**Estado guardado al abrir (`:228-240`):** todos los puntos (`GetPoint(i)` por cada `GetNumPoints`), parent (solo para mostrarlo en status), ancho/alto, escala, strata, nivel, zoom, `IsShown`, radio de vista inicial, y `GetHitRectInsets` si existe.

**Colocación (`placeMap`, `:132-145`):**
- `ClearAllPoints()` + `SetSize(w*factor, h*factor)` solo si difiere.
- `SetScale(targetSize * UIParent:GetEffectiveScale() / (max(w,h) * parent:GetEffectiveScale()))` — escala calculada para que el mapa mida `targetSize` en pantalla (`:139-140`).
- `SetPoint("CENTER", panel, "CENTER")`, `SetFrameStrata("DIALOG")`, `SetFrameLevel(panel+2)`, `Show()`.
- `Minimap:SetZoom(0)` y `redraw()` (`:259-260`).
- **No usa `SetParent`**: decisión explícita tras un bug con MelloUI (comentario `:103-105`, README.txt:44-48). **No usa `SetAlpha`.**

**Truco de refresco (`redraw`, `:147-157`):** «blink» de zoom: `SetZoom(1)` y `SetZoom(0)` en el mismo frame y otra vez con `C_Timer.After(0)`, porque el renderer no repinta tras cambiar el tamaño (`:148-149`).

**Restauración (`restore`, `:99-129`, enganchada a `panel:OnHide` `:130`):** `ClearAllPoints`, escala, tamaño, strata, nivel, hit insets, `SetPoint` de cada punto guardado, `SetZoom`, `Show/Hide` según estado previo, y restaura la visibilidad de cada control ocultado. Después `refreshOwner()` en el mismo frame y otra vez en `C_Timer.After(0)`.

**Eventos (`:285-293`):** `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, `UPDATE_BINDINGS`, `PLAYER_REGEN_ENABLED`. Handler único: si no es mazmorra → `panel:Hide()` (esto restaura); siempre `bindings()`; si fin de combate y sin lente → `refreshOwner()`.

**Combate:** el addon **no restringe nada por combate** salvo (a) `bindings()` no toca overrides con `InCombatLockdown` (`:276`) y (b) `refreshOwner()` espera al fin de combate (`:55`). Abrir y cerrar valen en combate (README.txt:6-9). Coherente con lo medido en la sesión de viabilidad (`Minimap:SetSize/SetZoom` valen en combate). **No hay evidencia en el código de que `ClearAllPoints/SetPoint` esté probado en combate**; el README admite «If the client blocks restoration in combat, use /reload» (README.txt:85-86). Es una pregunta abierta para la sonda F1 de QDT.

**Hooks:** ninguno. Declara no sustituir métodos ni instalar hooks permanentes (`:164-166`). En su lugar, **vigilancia por polling**: `OnUpdate` del panel cada 0,2 s compara tamaño, número de puntos, punto/relativo/offset y escala con lo esperado (`:164-209`) y, si difiere:
1. Si `nativeFactor ~= 1`: baja a 1, reaplica una vez y avisa (`:184-193`).
2. Si no: reaplica hasta 5 veces (`conflicts`), luego cierra con aviso (`:194-204`).
3. Cada tick reoculta los controles guardados (`:206-208`).

**Otras notas:** `panel.ignoreFramePositionManager = true` (`:19`, `:40`); el panel y el botón de teclas no capturan ratón (`:18`, `:272`); el panel solo pone texturas de cabecera/pie (opacas 0,92), nunca de fondo sobre el viewport, porque «the native minimap renderer does not always obey normal frame layering» (`:20-21`). Esto es un hallazgo útil: **el renderer nativo ignora el orden de capas**, así que un fondo opaco detrás/encima del mapa es arriesgado.

## 3. Iconos, botones y qué se ve

| Elemento | Tratamiento | Ref. |
|---|---|---|
| Hijos del Minimap tipo `Button` (cubre botones de LibDBIcon, tracking, correo, etc., cualquier Button hijo directo) | Se **ocultan** todos al abrir y se restauran con su `IsShown` previo; reocultados cada 0,2 s | `:72-78`, `:206-208` |
| `Minimap.ZoomIn`, `ZoomOut`, `ZoomHitArea` | ocultos | `:79-81` |
| `MelloUIServicesBar` (de MelloUI) | oculto | `:82` |
| Arte nativo: `MinimapBorder`, `MinimapBorderTop`, `MinimapNorthTag`, `MinimapCompassTexture`, `...Underlay`, `Minimap.Border` | ocultos (0.2.3: el aro quedaba pequeño sobre el jugador en ×4) | `:83-91`, README.txt:3-5 |
| `MinimapCluster.BorderTop`, `.DielFrame` | ocultos | `:92-96` |
| Marcadores de jugador/grupo/pines | **no se tocan**: los dibuja el renderer nativo, escalan con el mapa | `:74-75`, README.txt:52 |
| Tracking, blips, rotación, CVars (`rotateMinimap`, `minimapTrackingShow…`), `SetBlipTexture`, `SetArchBlobRingAlpha`… | **No toca nada.** No lee ni cambia CVars. | — |
| LibDBIcon | No lo nombra; lo cubre solo indirectamente por ser Buttons hijos del Minimap. Los botones de LibDBIcon son hijos de `Minimap`, así que quedan ocultos mientras dura la lente. | `:72-78` |
| Correo, cola LFG, reloj, calendario, tracking de Blizzard | Solo si son hijos `Button` directos de `Minimap`; en retail/Forever varios cuelgan de `MinimapCluster` (no se enumeran) y por tanto **no se ocultan ni se mueven** | `:72-78` (límite) |

Matiz: como la ventana mueve `Minimap` fuera de `MinimapCluster` visualmente (sin reparent), los hermanos del cluster quedan donde estaban, ahora tapados o sueltos. DungeonLens ignora el problema salvo por esos pocos `keep(...)`.

## 4. Otros addons de minimapa

Un único addon contemplado explícitamente: **MelloUI** (suite de UI del propio autor), y solo en esto:
- `refreshOwner()` llama `MelloUI:GetModule("MinimapPanel")` y sus `Relayout()`/`LayColumn()` bajo `pcall` (`:53-61`) tras restaurar y tras fin de combate.
- Oculta `MelloUIServicesBar` (`:82`) y menciona su derivación del contenedor desde `map:GetParent()` (`:103-105`).
- README sugiere probar con el módulo de minimapa de MelloUI desactivado (README.txt:31-32).

Para el resto (ElvUI, EllesmereUI, SexyMap, Chinchilla, etc.): **nada específico**. Estrategia genérica: no reparentar, restaurar todos los puntos, polling cada 0,2 s y rendirse a los 5 conflictos. README: «Other addons that move or skin the minimap may conflict; test initially with those disabled» (README.txt:82-83). No detecta máscaras, formas (cuadrado/redondo) ni skins; «retains the existing minimap shape» (README.txt:81-82).

## 5. Debilidades, huecos de UX e ideas para QDT

### Debilidades / bugs visibles

1. **Secuestra la tecla del mapa (M) en toda mazmorra**: `SetOverrideBindingClick` sobre `TOGGLEWORLDMAP` mientras `dungeon()` (`:275-284`). Es lo contrario de «atajo propio asignable»; hay que ir a `/dlens world` para abrir el mapa (`:311-313`). Además `for _, key in pairs({first, second})` con `first/second` posiblemente nil: `pairs` salta nils, pero si ambos son nil no avisa.
2. **Dependencia de polling `OnUpdate` 0,2 s** y de reaplicar `placeMap`; el propio README reconoce un bug de parpadeo en 0.2.0 (README.txt:11-13). Frágil y con coste constante mientras está abierta.
3. **Ventana modal con `UISpecialFrames`**: Escape cierra y además se restaura; interfiere con el flujo de cierre de otros paneles (Escape cierra la lente en vez del menú de juego).
4. **Estado no re-sincronizado:** si otro addon cambia el tamaño o el layout con la lente abierta, lo guardado (`saved`) queda obsoleto; restaura valores viejos y pisa los del otro addon (p. ej., cambio de tamaño de ElvUI mientras abierto).
5. **`saved.points` con `GetPoint(i)`** guarda referencias a frames relativos; si ese frame se destruye/ reconstruye (otro addon) `SetPoint` puede fallar en `restore` sin `pcall` (`:114-116`). No hay `pcall` en `restore` ni protección ante error parcial: un fallo a mitad deja el minimapa a medio restaurar y `saved` sin limpiar.
6. **Reapertura en el mismo frame sin ensayo del estado real tras `/reload`**: si el jugador hace `/reload` con la lente abierta, el UI recarga y el estado original se pierde de forma natural (bueno: `/reload` restaura, ya medido), pero nada lo documenta como garantía.
7. **`hideControls` no es completo**: solo hijos `Button` directos del Minimap. Otros hijos (frames no-Button, p. ej. contenedores de iconos de ElvUI/SexyMap) quedan visibles y escalados.
8. **Escala de render:** el efecto del modo «native» (×4) es experimental y puede ser desastroso con otros layouts; ahora cae a ×1 tras un reset ajeno, **pero el default es ×4**, la ruta más inestable, para un usuario que solo quiere ver más grande.
9. **Mensajes de chat en inglés, sin localización**; mensajes de diagnóstico mezclados con UX.
10. **Código muerto/confuso:** `saved.parent` solo informativo, `labelMode()` cadena «EXPERIMENT».
11. **Sin secret values / taint:** no usa `UnitGUID`/`UnitName`, así que no hay riesgo allí. Pero `C_Minimap.GetViewRadius` va en `pcall` (`:8`) sin comprobar `issecretvalue` (solo se hace `tostring`, y `tostring` de un secreto devuelve cadena secreta que se concatena; no explota, según la regla global).

### Huecos de UX (lo que no hay)

| Hueco | Observación |
|---|---|
| Tamaño/opacidad configurables | No existen (tamaño fijo 70 %/68 %/800 px) |
| Persistencia | Nada se guarda entre sesiones |
| Posición propia/movible | Siempre centrado en pantalla |
| Botón junto al minimapa | No hay; solo tecla o slash |
| Atajo configurable | Reutiliza la tecla del mapa; no aparece en Teclado › Atajos |
| Pasos de zoom | Siempre al máximo alejado; no hay «un paso más» |
| Sin ajustes de qué se ve | Tracking, blips, rotación no considerados |
| Sin pruebas ni tests | Un solo archivo; probado «solo conceptualmente» |
| Sin documentación de límites del Forever | Lo medido por QDT (sin posición del jugador) no se aborda |

### Ideas que valen la pena para QDT

- **Restauración total y parcial a prueba de fallos:** guardar anclajes + tamaño + escala + strata + nivel + zoom + hit-insets + visibilidad de controles, y restaurarlo todo bajo `pcall` por pieza. DungeonLens ya sabe lo que debe guardar (`:228-240`); QDT debe añadir seguridad por pieza.
- **No reparentar el `Minimap`** (aprendido por el autor con MelloUI, `:103-105`). Mantener el parent real y trabajar con anclajes/tamaño.
- **«Blink» de zoom para forzar el repintado** tras `SetSize` (`:147-157`): candidato a sonda F1 (¿también hace falta en Forever al cambiar de tamaño en sitio?).
- **El renderer nativo no obedece al layering** (`:20-21`): validar en F1 que `SetAlpha` y cualquier fondo propio de QDT se comportan; no poner fondo opaco sobre el viewport.
- **Ocultar el arte que no escala** (borde, brújula, norte, `cluster.BorderTop/DielFrame`, `:83-96`): la lista de nombres sirve como punto de partida; para QDT mejor **enumerar a demanda** y restaurar la visibilidad previa.
- **Cierre al salir de la instancia** con `PLAYER_ENTERING_WORLD` + `ZONE_CHANGED_NEW_AREA` + `IsInInstance` (`:285-291`) — coincide con el plan (F1 «arista de salir»).
- **`C_Minimap.GetViewRadius`** (`:6-12`): sonda útil para comprobar si agrandar cambia el área visible o solo el tamaño.
- **Idea de detección de conflicto:** si otro layout re-ancla el Minimap, avisar una vez y cerrar (sin bucle). Mejor que polling a 0,2 s: comparar solo en eventos (`UI_SCALE_CHANGED`, `DISPLAY_SIZE_CHANGED`) y una comprobación diferida tras el cierre.
- **`refreshOwner` con `pcall`** como patrón de cortesía con addons de minimapa (hook de «ya restauré, relayouta»), generalizado: un registro opcional de adaptadores por addon (ElvUI, EllesmereUI…) en vez de MelloUI fijo.

### Qué NO copiar

- **Ventana modal centrada con escala calculada** para el mapa: contradice el diseño de QDT (lente en sitio movible, recordado).
- **Secuestrar `TOGGLEWORLDMAP`** o cualquier tecla del juego; QDT usa `Bindings.xml` sin asignar.
- **Ocultar todos los `Button` hijos** (incluye LibDBIcon): decidir en QDT si la lente los oculta (diseño pendiente) en vez de hacerlo ciegamente, con tabla de excepciones.
- **Polling `OnUpdate` 0,2 s** y bucle de reintentos hasta 5; usar eventos y un único reintento diferido.
- **Modo «native ×4» por defecto**: la hipótesis de «más alcance» no se ha probado y el propio README no la afirma. QDT ya midió que es la misma zona más grande (viabilidad 2026-11-12); no perseguir la hipótesis.
- **Mensajes sin localizar y diagnóstico en chat** en producción.
- **Restaurar sin `pcall`**.

### Decisiones para el agente principal / owner

1. ¿La lente oculta los botones (LibDBIcon, tracking, correo…) mientras está activa, o los deja? DungeonLens los oculta todos; el plan M2 no lo dice. Para el diseño F0.
2. ¿Se oculta el arte del borde (borde, brújula, norte) al agrandar? DungeonLens lo hace por defecto porque los restos quedan pequeños y desalineados; se sugiere sondear en F1.
3. Compatibilidad con ElvUI/EllesmereUI/SexyMap: nadie lo resuelve genéricamente; decidir el alcance (¿solo «mejor esfuerzo» y aviso?).
4. Añadir a F1 las sondas: `ClearAllPoints/SetPoint` en combate, necesidad del «blink» de zoom, `GetViewRadius` antes/después, y comportamiento del renderer con `SetAlpha`.
