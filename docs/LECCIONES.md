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

- **Síntoma:** con el lens maximizado, en cuevas y en Undercity solo se ven las marcas del
  minimapa (grupo, pings); el terreno no se pinta. Minimizado se ve bien.
- **Causa:** el motor no repinta el terreno de esas zonas (WMO; `IsIndoors()` da false en
  Undercity) cuando tamaño, posición, máscara y zoom cambian a la vez. Se descartaron uno a uno:
  tamaño (también 255), máscara, posición, alfa, rastreo y nuestros marcos hijos. Aplicar los
  mismos pasos a mano, en fotogramas separados, sí lo pinta.
- **Patrón correcto:** cuando el lens se asienta, y en cada `ZONE_CHANGED*` con el lens abierto,
  cambiar el zoom un nivel y volver al cabo de 0,2 s (`nudgeZoom`). Una vez pintado, el terreno
  aguanta los cambios de zoom.
- **Cómo se comprueba:** en Undercity, maximizar el lens: tras el salto de zoom se ve el mapa.
  Entrar en una cueva con el lens ya abierto: también se ve (verificado por el owner).
- **Origen:** M2, prueba del owner (2026-11-16).
- **⚠ REABIERTO (2026-11-16, noche): el patrón NO es fiable.** Misma tarde, el terreno volvió a
  faltar en Undercity con el lens abierto. Registro `_checkLens.nudge` (SavedVariables): el salto
  se lanza (`settled` y cada `ZONE_CHANGED_INDOORS`, zoom 1→2→1, `back = 1`) y aun así no pinta.
  Desplegada la versión verificada (`c8d9878`, sin los cambios de la lupa de ese día): **igual o
  peor** — tampoco se ve con el lens cerrado; el minimapa normal se arregla cambiando el zoom a
  mano, el lens **no** se arregla ni con la rueda. Descarta los commits de la lupa (`92ee2eb`,
  `5ae247c`, `10db497`) como causa. Hipótesis abiertas: estado del motor que se rompe una vez por
  sesión de juego (probar reiniciando el cliente, no `/reload`), tamaño del lens (el `on` medido
  tenía `size = 200`, lado 510), o la primera verificación fue suerte de tiempos.

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
