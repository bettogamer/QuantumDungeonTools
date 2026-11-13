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

<!-- Divergencias CONSCIENTES del estándar (hallazgo de /check-conformance declarado deuda)
     también viven aquí, con motivo y con lo que se hace en su lugar. -->
