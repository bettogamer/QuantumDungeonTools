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
| [craft-tooltip-lines-posicionales](#craft-tooltip-lines-posicionales) | tooltip de Craft vacío (cuadro diminuto) | 2026-11-13 |

---

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
