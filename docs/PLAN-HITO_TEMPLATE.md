# Plan <M-N> — <nombre del hito>

> Hito <M-N> (AGENTS.md §plan de hitos<!-- nivel M+ -->; ADR-<NNNN><!-- -->). <Una frase de qué
> cierra y qué deja explícitamente fuera.> **Una sesión por fase** (disciplina de tokens, ver
> AddonTemplate/docs/04-proceso.md). **Este doc es el registro vivo de fases** — el estado real
> del hito vive AQUÍ, no en AGENTS.md.

<!-- QUÉ ES ESTE ARCHIVO (lección Coffer, 2026-07)
     El plan de hito es el único sitio donde el estado en curso se escribe con detalle. Nació
     porque el blockquote "Estado del proyecto" de AGENTS.md creció a 87 líneas Y ASÍ Y TODO
     se quedó desactualizado (decía "F3 pendiente de verificar, 126/227" cuando el hito ya
     estaba cerrado en 188/227, cuatro versiones después). El detalle no cabe en AGENTS.md:
     ponlo aquí y deja allí una línea con un puntero.
     Vive en docs/plan-<hito>.md — uno por hito, no se borra al cerrarlo (es el histórico
     de por qué se decidió cada cosa). Nivel M+; en nivel S el hito cabe en el CHANGELOG. -->

## Contexto

<De dónde viene el hito: qué cerró el anterior, qué queda medido (si hay contrato de paridad o
checklist, el contador N/TOTAL), y por qué estas fases y no otras. 1-2 párrafos.>

## Fases

| Fase | Feature | Estado | Nota |
|------|---------|--------|------|
| **F1** | <feature> | 🔨 EN CURSO | <alcance de la fase> |
| **F2** | <feature> | ⬜ PENDIENTE | |
| **F3** | <feature> | ⬜ PENDIENTE | |

<!-- Estados (usar estos, son el vocabulario del estándar):
     ⬜ PENDIENTE · 🔨 CÓDIGO LISTO (pendiente de verificación in-game) ·
     ✅ VERIFICADA in-game (fecha + versión) · ❌ DESCARTADA (con motivo)
     "CÓDIGO LISTO" y "VERIFICADA" son estados DISTINTOS a propósito: hasta que el owner no lo
     prueba en el cliente, no está hecho. Si hay contrato de paridad, la fila verificada anota
     el delta del contador (p. ej. "114 → 128/227"). -->

> Fuera de este hito por decisión previa: <lo que NO entra y por qué — API muerta, diferido tras
> feature flag, hito propio…>. Anotarlo aquí evita re-litigarlo cada sesión.

---

## F1 — <nombre de la fase>

**Decisiones del owner (<yyyy-mm-dd>):**
- <Decisión de producto que el agente NO puede tomar solo, tal como se acordó.>

**Alcance:** <qué entra, qué no.>

**Entregado (v<X.Y>):** <módulos nuevos/tocados, en una lista corta.>

**Prueba in-game (v<X.Y>, desplegada el <yyyy-mm-dd>):** <el guion, en bloques independientes.
Va AQUÍ y no en el chat, que se pierde con la sesión. Reglas en doc 04 §Verificación in-game:
los valores esperados YA calculados y pasados por el mismo formateador que usa la UI ("58 %",
no "el porcentaje"); un bloque por cosa que se firma por separado; y lo que reordena la vista,
al final.>

| Bloque | Qué mira el owner | Valor esperado | Firma |
|--------|-------------------|----------------|-------|
| B1 | <pantalla en reposo: qué campos, uno por uno> | <valores> | ⬜ |
| B2 | <lo que cruza con el personaje> | <valores> | ⬜ |
| B3 | <lo que reordena la vista — siempre el último> | <valores> | ⬜ |

**Gotchas in-game:** <lo que solo se descubre probando: orden de carga, strata, APIs que
devuelven otra cosa de lo documentado, secret values. Esto es lo más valioso del archivo —
si además es una lección reusable, súbela a AGENTS.md §lecciones o a la regla global de taint.>

## Puntos abiertos

| # | Punto | Quién decide | Recomendación | Estado |
|---|-------|--------------|---------------|--------|
| 1 | <punto> | **owner** / agente | <recomendación> | ⬜ |

<!-- Los «del owner» se le PREGUNTAN todos, con recomendación; el agente nunca los cierra por su
     cuenta (SMRT: la D27 cerrada sin él hubo que revocarla). Los «del agente» se deciden y se
     anotan fechados. -->

## Checklist de cierre del hito

- [ ] **CI en verde Y corriendo los tests**: el job `test` existe en `ci.yml` y su glob cubre
      todas las carpetas de specs (Coffer: 47 archivos de tests que ningún CI ejecutaba).
- [ ] **Demo + `deploy-local` hechos ANTES de pedir la prueba in-game** (si hay lib, la demo
      lleva la fila/botón repro de cada cambio; autoprueba `/<addon> check <fase>` verde).
- [ ] `/check-conformance` corrido y sus hallazgos arreglados o declarados deuda.
- [ ] **Poda de AGENTS.md**: `wc -l` ≤ techo, línea de estado reescrita con fecha de hoy,
      lecciones nuevas movidas a `docs/LECCIONES.md`, versiones de libs vendoreadas al día.
- [ ] Memoria del agente podada (reglas sí, historial de FR/releases no).
- [ ] Si toca UI: pasó por `ui-critic` antes de cerrar y sus informes quedan «resuelto en <commit>».
- [ ] **`Siguiente: <qué + ruta>` escrito AQUÍ** antes de proponer cortar sesión.
- [ ] Si hay release: ritual de doc 04 §Release (schema contra el último tag, tag anotado).

<!-- Repetir el bloque por fase. Al cerrar el hito, añadir arriba del todo: -->

<!--
> ## ✅ <M-N> CERRADO (<yyyy-mm-dd>, v<X.Y>) — <delta medido, p. ej. "99 → 188/227">
>
> <Una frase de qué se logró.> <Si queda trabajo sin hacer, cada resto va asignado a un cubo
> con dueño y motivo — no "pendiente de decidir".>
>
> **Trabajo futuro elegible:** <lo que quedó vivo para hitos siguientes.>
-->
