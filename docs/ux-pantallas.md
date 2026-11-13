# UI — <nombre de la pantalla>

<!-- Un archivo por pantalla (docs/design/ui-NN-<slug>.md) cuando hay varias; uno solo
     (docs/ux-pantallas.md) mientras el addon tenga una. Se lee ANTES de tocar la UI.

     ESTADO DEL DOCUMENTO — elegir uno y ponerlo en la primera línea:
       🟡 BORRADOR  — se está discutiendo. NO se implementa nada de aquí hasta cerrarlo.
       ✅ CERRADO   — las decisiones D-* son vinculantes; cambiarlas es una decisión nueva,
                      fechada, no un "mientras tanto lo hago así".
     Un borrador implementado a medias es la forma más cara de perder una tarde: la mitad del
     código sale de una versión del documento que ya no existe. -->

> 🟡 BORRADOR · <yyyy-mm-dd> · pantalla <abre con qué comando / desde dónde>

## Para qué existe esta pantalla

<Una frase. Si no se puede escribir en una, la pantalla hace dos cosas y son dos pantallas.
Tiene que poder contrastarse con la pregunta del norte (docs/NORTH-STAR.md).>

## Maqueta

```
┌────────────────────────────────────────────────┐
│ <ASCII de la pantalla. No hace falta que sea   │
│  bonito: hace falta que diga qué va arriba,    │
│  qué se lee primero y qué cabe en una fila.>   │
└────────────────────────────────────────────────┘
```

## Decisiones (`D-N`)

<!-- Numeradas y fechadas, porque el código y los informes de ui-critic las citan por número.
     Cada una: QUÉ se decidió, y POR QUÉ — el porqué es lo que evita re-litigarla en tres
     sesiones. Si el número sale del contrato de paridad o del oráculo, cítalo (doc 04 §Quién
     decide): un número que se VE en pantalla casi nunca hay que inventarlo. -->

| # | Decisión | Por qué | Fecha |
|---|----------|---------|-------|
| D-1 | <qué se hace> | <el motivo, o la fila del contrato de la que sale> | <yyyy-mm-dd> |
| D-2 | | | |

## Datos que pinta

<!-- De dónde sale cada cosa que se ve. Es lo que convierte "la fila de arriba" en algo
     implementable, y lo que permite escribir la prueba in-game con los valores YA calculados
     (doc 04 §Verificación in-game). -->

| Elemento | Fuente | Formato | Si no hay dato |
|----------|--------|---------|----------------|
| <texto/número> | <módulo o API> | <`Format.percent(x, 0)` → `58 %`> | <qué se pinta: "—", oculto, "??" si es secret value> |

## Huecos abiertos

<!-- Lo que NO está decidido, explícito. Un hueco descubierto al programar es una PREGUNTA, no
     permiso para rellenarlo (doc 04 §Quién decide): si se sigue para no bloquear, se anota
     aquí como SUPOSICIÓN, con la fecha, para que alguien pueda auditarla. -->

- **<hueco>** — <lo que falta por decidir>. ¿Lo sabe el oráculo, el contrato, o solo el owner?
- **SUPUESTO (<yyyy-mm-dd>)**: <lo que se asumió para no bloquear, y qué habría que confirmar.>

## Revisiones

<!-- Los informes de `ui-critic` sobre esta pantalla, que viven aparte para que este documento
     no se convierta en un diario. Aquí solo el enlace y qué salió de cada uno. -->

- `docs/ux-revision-<yyyy-mm-dd>.md` — <qué se cambió a raíz de ella; qué se descartó y por qué.>
