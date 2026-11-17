# Lecciones — QuantumDungeonTools

> Bugs reales ya pagados y su patrón correcto. **Esta es la casa de las lecciones**: AGENTS.md
> solo lleva un puntero y las ≤10 reglas que muerden en cada sesión (doc 04 §AGENTS.md, «Techo y
> poda»). Un archivo propio puede crecer sin romper el techo de AGENTS.md; lo que no puede es
> convertirse en un diario.

<!-- Criterio de entrada: la lección REUSABLE (morderá otra vez en otro sitio). El gotcha de una
     fase concreta se queda en su plan de hito. Una lección = una entrada; si ya existe, se
     AMPLÍA con el nuevo caso, no se duplica. Taint/secret values de 12.0+: además se documentan
     en la regla global de ~/.claude/CLAUDE.md ("Casos conocidos"). -->

## Índice

| Ancla | Una línea | Fecha |
|-------|-----------|-------|
| [wow-tamano-fuente-caja-de-linea](#wow-tamano-fuente-caja-de-linea) | el texto sale ~7 % más grande que en el diseño | 2026-11-13 |
| [craft-tooltip-lines-posicionales](#craft-tooltip-lines-posicionales) | tooltip de Craft vacío (cuadro diminuto) | 2026-11-13 |
| [forever-dificultad-vacia-al-entrar](#forever-dificultad-vacia-al-entrar) | /reload dentro de la mazmorra pierde las kills | 2026-11-13 |
| [ellesmere-recoge-botones-del-minimapa](#ellesmere-recoge-botones-del-minimapa) | botón propio sobre el minimapa desaparece con EllesmereUI | 2026-11-16 |

---

## wow-tamano-fuente-caja-de-linea

- **Síntoma:** con los mismos px que el lienzo de diseño, el texto in-game sale más grande en
  proporción a barras y marcos (la fila de totales se salía por la izquierda de la barra).
- **Causa (confirmada in-game 2026-11-13: con ×0.932 reloj/barra = 0.32, igual que el artboard):** CSS dimensiona por el
  em (upem = 1000) y WoW ajusta la caja de línea (hhea ascender + |descender| = 740 + 192 = 932 en
  BettoGeo) a la altura pedida → glifos ×1000/932.
- **Patrón correcto:** los tamaños de fuente se quedan como en el diseño (owner: bajarlos «se
  sale del diseño») y la GEOMETRÍA crece en la misma proporción: `Style.GEO = 1000/932` multiplica
  todo `Style.SIZE` (ancho, alturas de barra, huecos). Encoger la fuente ×0.932 también cuadraba
  las proporciones, pero el owner lo rechazó. Otra fuente = recalcular con sus métricas
  (`head.unitsPerEm`, `hhea`).
- **Cómo se comprueba:** captura in-game junto al artboard: el reloj y las barras guardan la
  misma proporción.
- **Origen:** M1 F4b, revisión visual del owner contra el artboard Main.

## craft-tooltip-lines-posicionales

- **Síntoma:** al pasar el ratón sale un cuadro diminuto vacío (solo el borde y el padding).
- **Causa:** `Craft.Tooltip` lee el texto de cada línea por POSICIÓN (`spec[1]`, `spec[2]`,
  `libs/Craft/components/Tooltip.lua` `_layoutLines`); `{ left = ..., right = ... }` no pinta nada
  y no da error. Los colores sí van por clave (`leftColor`, `rightColor`, `separator`).
- **Patrón correcto:** `{ "Izquierda", "Derecha", leftColor = c1, rightColor = c2 }`.
- **Cómo se comprueba:** `grep -n "{ left =" QuantumDungeonTools/` no debe encontrar nada.
- **Origen:** M1 F4b (tooltip Detalle); el tooltip del modo compacto tenía el mismo fallo desde F2.

## texturas-dentro-de-fontstring-anclado

- **Síntoma:** una línea anclada a la derecha se sale ~11 px del borde del widget.
- **Causa:** con texturas inline (`|T...|t`, p. ej. espaciadores) en mitad del texto,
  `GetStringWidth` (y el ancho automático del FontString) sale corto; el ancla RIGHT se respeta
  pero el texto pintado desborda.
- **Patrón correcto:** separar en FontStrings sueltos encadenados con `chain` y un gap del token
  (`S.infoSep`); texturas inline solo donde ya se compensa la medida (monedas: tamaño fijo +
  espacio de cierre).
- **Cómo se comprueba:** captura in-game; el borde derecho de cada fila debe coincidir con el del reloj.
- **Origen:** M1, cotejo docs/15 (separador `·` de la línea de info), 2026-11-13.

## forever-dificultad-vacia-al-entrar

- **Síntoma:** tras un `/reload` dentro de la mazmorra la run vuelve a 0 y el reloj se reinicia; lo
  matado antes del reload desaparece (Deadmines, Normal).
- **Causa:** en el primer `PLAYER_ENTERING_WORLD` al entrar, `GetInstanceInfo` devolvió la
  dificultad VACÍA (`""`); tras el reload ya decía `"Normal"`, y `Run:canResume` exigía la misma
  dificultad → run nueva. Visto en la traza `QDT_RUN` del registro pasivo (`Deadmines||id=36` →
  `Deadmines|Normal|id=36`).
- **Patrón correcto:** un dato de `GetInstanceInfo` leído al entrar puede faltar: rellenarlo
  después (`Run:fillDifficulty` en `CheckZone`/`Refresh`, y recargar el récord, que va por
  dificultad) y no compararlo cuando falta en cualquiera de los dos lados.
- **Cómo se comprueba:** entrar, matar un jefe, `/reload`: la kill y el reloj siguen.
- **Origen:** M1, run del owner en Deadmines (2026-11-13).

## minimapa-grande-sin-terreno-bajo-tierra

- **Síntoma:** con el lens abierto, en cuevas y en Undercity solo se ven las marcas del minimapa
  (grupo, pings); el terreno no se pinta.
- **Causa:** la **opacidad**. Con el `Minimap` por debajo de alfa 1 el motor no pinta el terreno
  bajo tierra (WMO; `IsIndoors()` da false en Undercity). Al 100 % siempre funcionó; al 55 % o
  40 % nunca (owner, 2026-11-16). Una primera teoría (cambios de tamaño, zoom y máscara en el
  mismo fotograma) se «verificó» con la opacidad al 100 % y era falsa.
- **Patrón correcto:** el terreno de un nivel de zoom solo se carga si ese nivel se alcanza con
  el `Minimap` OPACO. Repintado (`flash` en `wow/Lens.lua`): alfa 1, salto de zoom a un nivel
  vecino y vuelta, y de nuevo la opacidad elegida. Un destello sin salto de zoom basta solo si el
  nivel ya se cargó antes al 100 % (sin «zoom extra»); con «zoom extra» no (owner, 2026-11-17).
  Se lanza al asentarse el lens, en `ZONE_CHANGED*`/`MINIMAP_UPDATE_ZOOM` y tras cada `SetZoom`
  ajeno (rueda, EllesmereUI; los propios se ignoran con `writing`). Al cerrar, el minimapa
  normal da el mismo salto (`nudgeRestored`). El salto de zoom se nota (parpadea aun volviendo
  en el siguiente fotograma), así que solo se usa tras un `SetZoom` ajeno; al abrir y en cambios
  de zona basta el destello, porque el owner QUITÓ «zoom extra al activarla» (2026-11-17).
- **Límite conocido:** entrar bajo tierra **con el lens ya abierto** y opacidad < 100 % lo deja
  en blanco, y **no hay señal para detectarlo**: en la puerta de Undercity no llega ningún
  `ZONE_CHANGED*` ni cambian `IsIndoors`/`IsOutdoors`, `GetSubZoneText`, `GetZoneText`,
  `GetRealZoneText`, `GetMinimapZoneText`, `C_Map.GetBestMapForUnit` ni la instancia de
  `UnitPosition` (sonda a 2 Hz, medido). Repetir el salto con alfa 1 en `ZONE_CHANGED_INDOORS`
  tampoco pinta; solo reabrir el lens. Decisión del owner: la pista del slider de opacidad avisa
  («reábrela»). No reintentar sondas de zona para esto.
- **Siguiente paso (pendiente, sesión nueva):** encontrar QUÉ señal marca el cambio de mapa
  del minimapa (exterior ↔ bajo tierra) en la puerta de Undercity, para lanzar `flash` ahí y
  quitar el aviso del slider. Ya descartado (sonda a 2 Hz): `IsIndoors`/`IsOutdoors`, textos de
  zona/subzona/minimapa, `C_Map.GetBestMapForUnit`, instancia de `UnitPosition`; no llega
  `ZONE_CHANGED*`. Enganchado sin datos aún: `MINIMAP_UPDATE_ZOOM` (registro `_checkLens.nudge`,
  campo `why`; requiere `/reload` tras la prueba). Ideas por probar: frame con `RegisterAllEvents`
  durante el cruce (volcar nombres a SavedVariables con un reductor, no leer a mano), y
  `Minimap:GetZoom()` (el minimapa guarda zoom interior/exterior aparte). **Sonda lista
  (2026-11-17):** `/qdt check door` (`wow/CheckDoor.lua`) graba todos los eventos y, por
  fotograma, zoom/niveles/radio de vista/CVars de zoom/ping; reductor
  `scripts/read-check-door.lua` (eventos que solo salen cerca de un cambio o de un `mark`).
- **Origen:** M2, pruebas del owner (2026-11-16).

## ellesmere-recoge-botones-del-minimapa

- **Síntoma:** la lupa del lens (un `Button` hijo del `Minimap`) desaparece bajo EllesmereUI.
- **Causa:** `EUI_Minimap_Buttons.lua` `GatherMinimapButtons` recoge todo hijo directo del
  `Minimap` que sea `Button`, con nombre que no acabe en dígitos y ancho ≥ 20, y lo esconde
  (`Hide` + `SetAlpha(0)` + hook a `Show`). Re-escanea en cada `ADDON_LOADED`. No hay lista de
  exclusión pública.
- **Patrón correcto:** un botón propio sobre el minimapa NO es hijo del `Minimap`: padre
  `UIParent`, anclado con `SetPoint` al `Minimap`, su strata y nivel + 10, y ocultarlo/mostrarlo
  con hooks `OnHide`/`OnShow` del `Minimap` (`MinimapLens/wow/Triggers.lua`).
- **Origen:** M2, prueba del owner (2026-11-16).

<!-- Divergencias CONSCIENTES del estándar (hallazgo de /check-conformance declarado deuda)
     también viven aquí, con motivo y con lo que se hace en su lugar. -->
