# Plan M2 — Minimap Lens (minimapa grande a demanda)

> Hito M2 (AGENTS.md §1, «Futuro: Minimap Lens»). Segundo módulo de QDT: el jugador agranda el
> minimapa con un atajo, un botón o `/qdt lens`, y vuelve a su sitio al apagarlo o al salir de la
> mazmorra. Deja fuera cualquier flecha o icono relativo al jugador (imposible en Forever). Se
> desarrolla en `main` **oculto tras el «PRONTO»** del sidebar mientras dura la beta
> `0.1.0-beta.1` del Instance Tracker. **Una sesión por fase.** Este doc es el registro vivo.

## Contexto

M1 (Instance Tracker) está cerrado en código y en beta para la guild. Minimap Lens viene de la
idea original (doc 00 §4 «Módulos futuros»), y la sesión de viabilidad (2026-11-12, regla global
de taint, caso «DENTRO de una mazmorra NO hay posición») ya midió lo esencial:
`Minimap:SetSize`/`SetZoom` **funcionan, también en combate**, y `/reload` los restaura. La zona
que se ve es la misma, solo más grande, no más área. No hay posición del jugador: `C_Map` y
`UnitPosition` devuelven nil.

Orden de las fases: **primero el diseño** (owner, 2026-11-15: «como siempre primero diseño, nada
de código mientras»), luego **medir** lo que el diseño dé por hecho, y solo después el código.

## Fases

| Fase | Feature | Estado | Nota |
|------|---------|--------|------|
| **F0** | Diseño en el lienzo | 🔨 EN CURSO | artboards nuevos en el lienzo de QDT; **sin código hasta el OK del owner** |
| **F1** | Sondas de Forever (`/qdt check m2`) | ⬜ PENDIENTE | ver §F1 |
| **F2** | Núcleo de la lente | ⬜ PENDIENTE | `modules/MinimapLens/core/Lens.lua` (estado, tamaño con límites, guardar y restaurar el sitio) + `wow/Lens.lua` |
| **F3** | Disparadores | ⬜ PENDIENTE | atajo (`Bindings.xml`), botón lupa junto al minimapa, `/qdt lens` y cierre automático al salir de la instancia |
| **F4** | Página del módulo + ajustes | ⬜ PENDIENTE | tamaño y opacidad con deslizadores, «Mover marcos» y quitar el «PRONTO» del sidebar |

> Fuera de este hito por decisión previa: **flecha o posición del jugador** (no hay datos en
> instancia); **activación automática al entrar** (owner, 2026-11-15: solo manual); **clic en el
> icono de LibDBIcon** como disparador (no elegido).

---

## F0 — Diseño

**Decisiones del owner (2026-11-15):**
- Módulo: Minimap Lens. Desarrollo en `main`, oculto tras el «PRONTO» hasta cerrar el hito.
- Activación **solo manual**: nunca se agranda sola.
- Disparadores: **atajo de teclado**, **botón junto al minimapa** y **`/qdt lens`**.
- Posición: **movible y recuerda el sitio** (con «Mover marcos», igual que el widget); al apagar,
  el minimapa vuelve a su esquina original.
- Tamaño: **deslizador en ajustes**, más otro de opacidad, con valores por defecto razonables.
- Al salir de la mazmorra, **la lente se cierra sola** y el minimapa vuelve a su sitio.

**Artboards a dibujar** (página nueva «Minimap Lens» del lienzo, con la paleta B y los
componentes shadcn de Craft; ver memoria de estilo):
1. **Reposo**: minimapa normal con el botón lupa pegado (estado apagado).
2. **Lente activa**: minimapa grande en su sitio elegido, con el botón en estado encendido y la
   opacidad aplicada.
3. **Mover marcos**: el marco de la lente con su borde y etiqueta, como el del widget.
4. **Página del módulo** en la ventana principal: interruptor del módulo, tamaño, opacidad, aviso
   «Asigna el atajo en Teclado › Atajos › AddOns» y botón «Probar».
5. **Sidebar**: la fila «Minimap Lens» sin «PRONTO» (solo al cerrar el hito).

## F1 — Sondas (a concretar tras F0)

Lo que el diseño dará por hecho y hay que ver en Forever antes de codificar:
- Si `Minimap:ClearAllPoints`/`SetPoint` a otro sitio aguanta en combate y no lo recoloca el
  layout de `MinimapCluster` (¿Modo edición en Forever?).
- Si `Minimap:SetAlpha` atenúa también los pines y las texturas del borde.
- Si `Bindings.xml` + `BINDING_HEADER_*` aparecen en Teclado › Atajos › AddOns en Forever.
- La restauración exacta: anclajes, tamaño, zoom y escala originales, también con otros addons de
  minimapa cargados.
- La arista de «salir de la instancia» (`PLAYER_ENTERING_WORLD` + `IsInInstance`).

## Puntos abiertos

| # | Punto | Quién decide | Recomendación | Estado |
|---|-------|--------------|---------------|--------|
| 1 | ¿El botón lupa se ve siempre o solo dentro de una instancia? | **owner** | solo en instancia (fuera no aporta) | ✅ solo en instancia (owner, 2026-11-15) |
| 2 | ¿Atajo por defecto o sin asignar? | **owner** | sin asignar (evita choques); la página del módulo lo indica | ✅ sin asignar (owner, 2026-11-15) |
| 3 | ¿La lente también sube el zoom del minimapa? | **owner** | sí, un paso más de zoom (se ve más detalle de la sala) | ✅ sí, un paso más (owner, 2026-11-15) |
| 4 | Valores por defecto y límites de tamaño y opacidad | agente (tras F1) | ~2× el tamaño original, opacidad 100 % | ⬜ |

## Checklist de cierre del hito

Igual que la plantilla (`docs/PLAN-HITO_TEMPLATE.md`): CI con tests, demo + `deploy-local` antes de
la prueba, conformidad, poda de AGENTS.md (estado → M2), `ui-critic`, entrada en CHANGELOG +
NewsData, y `Siguiente:` escrito aquí.
