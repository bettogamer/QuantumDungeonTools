# Lecciones — <NombreAddon>

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
| [<slug>](#slug) | <síntoma en pocas palabras> | <yyyy-mm-dd> |

---

## <slug>

- **Síntoma:** <lo que se ve, con el mensaje de error literal si lo hay.>
- **Causa:** <la causa raíz, no el síntoma; `archivo:línea` donde se descubrió.>
- **Patrón correcto:** <qué se hace ahora; código mínimo si ayuda.>
- **Cómo se comprueba:** <test, autoprueba `/<addon> check …` o grep que lo detecta.>
- **Origen:** <hito/fase, versión, commit.>

<!-- Divergencias CONSCIENTES del estándar (hallazgo de /check-conformance declarado deuda)
     también viven aquí, con motivo y con lo que se hace en su lugar. -->
