# Plan M2 — Minimap Lens (minimapa grande a demanda)

> Hito M2 (AGENTS.md §1, «Futuro: Minimap Lens»). Segundo módulo de QDT: el jugador agranda el
> minimapa con un atajo, un botón o `/qdt lens`, y vuelve a su sitio al apagarlo o al salir de la
> mazmorra. Deja fuera cualquier flecha o icono relativo al jugador (imposible en Forever). Se
> desarrolla en `main` **oculto tras el «PRONTO»** del sidebar mientras dura la beta
> `0.1.0-beta.1` del Instance Tracker. **Una sesión por fase.** Este doc es el registro vivo.

## Contexto

M1 (Instance Tracker) está cerrado en código y en beta para la guild. Minimap Lens viene de la
idea original (doc 00 §4 «Módulos futuros»). La sesión de viabilidad (2026-11-12, regla global
de taint, caso «DENTRO de una mazmorra NO hay posición») dejó medido que `Minimap:SetSize` y
`SetZoom` funcionan, también en combate, y que `/reload` los restaura. La lente enseña la misma
zona más grande, no más área.

Investigación previa al diseño (2026-11-15, solo lectura de código, **nada medido in-game**):
- `docs/21-dungeonlens-inventario.md`: el competidor directo. Es un modal centrado que mete
  dentro el Minimap real, a tamaño fijo. Usa la tecla M como propia, oculta todos los botones a
  ciegas, hace polling y no trae ajustes. **Se copia:** no reparentar el Minimap y repintar el
  terreno con un empujón de zoom. **No se copia:** el modal, tomar la tecla M, ocultar a ciegas,
  el polling ni restaurar sin `pcall`.
- `docs/22-minimap-coexistencia.md`: el parpadeo con EllesmereUI/ElvUI. No es un bucle de hooks:
  gana el último que escribe. **EllesmereUI** reaplica tamaño, máscara y zoom en
  `PLAYER_ENTERING_WORLD` (justo al entrar en la mazmorra) y al salir de combate, y deshace
  cualquier `SetParent`. **ElvUI v16.01**, verificado en local (2026-11-15): NO reaplica en PEW
  ni al salir de combate (solo al cambiar sus opciones). Su «Reiniciar zoom» es opcional y viene
  apagado por defecto, aunque el asistente de instalación lo enciende a 5 s. El minimapa crece
  desde la esquina superior derecha de `ElvUI_MinimapHolder`, el global que delata a ElvUI.
  Ninguno de los dos ofrece un flag para prestar el minimapa.
- `docs/23-minimap-iconos-y-config.md`: en Forever el árbol es `MinimapCluster` > `MinimapContainer`
  > `Minimap`, con Modo edición. El aro (`MinimapBackdrop`) mide 215×226 fijo. Los botones de
  Blizzard (zona, rastreo, correo, calendario, cola, compartimento de addons) cuelgan del
  cluster, no del Minimap. Los de LibDBIcon son hijos del Minimap y **no se recolocan solos**
  (hay que llamar a `Refresh`). En la api-db de taintlint, `C_Minimap.*` no devuelve secretos
  ni es protegida.

Orden de las fases: **primero el diseño** (owner, 2026-11-15: «como siempre primero diseño, nada
de código mientras»). Con el OK del owner, **se mide** lo que el diseño da por hecho (F1). Si una
sonda falla, se vuelve al artboard afectado antes de seguir. Después vienen el núcleo y las capas.

## Fases

| Fase | Feature | Estado | Nota |
|------|---------|--------|------|
| **F0** | Diseño en el lienzo | 🔨 EN CURSO: 5 artboards publicados (lienzo v71, 2026-11-15), **esperando el OK del owner** | página «Minimap Lens»: LensReposo, LensActiva, LensMover, LensAviso (A toast / B chat), AppLens (lleva el sidebar sin PRONTO); **sin código hasta el OK** |
| **F1** | Sondas de Forever (`/qdt check m2`) | ⬜ PENDIENTE | §F1: sin otro UI, con EllesmereUI y con ElvUI |
| **F2** | Núcleo de la lente | ⬜ PENDIENTE | `modules/MinimapLens/core/Lens.lua` (estado, límites de tamaño, snapshot y restauración) + `wow/Lens.lua` (aplicar/restaurar con `pcall`, contorno QDT, ocultar aro, `Refresh` de LibDBIcon) |
| **F3** | Convivencia con otros UI | ⬜ PENDIENTE | detectar el dueño, modo suave (`SetScale`, reaplicar tras ellos con guard, ceder si pisan y avisar una vez) |
| **F4** | Disparadores y ciclo de vida | ⬜ PENDIENTE | atajo (`Bindings.xml`, sin tecla por defecto), botón lupa (solo en instancia), `/qdt lens`, cierre al salir de la instancia, al abrir el Modo edición y al cerrar sesión |
| **F5** | Página del módulo + ajustes | ⬜ PENDIENTE | tamaño, opacidad, rastreo de recursos, «Mover marcos», aviso del atajo; quitar el «PRONTO» |

> Fuera de este hito por decisión previa: **flecha o posición del jugador** (no hay datos en
> instancia); **activación automática al entrar** (owner: solo manual); **clic en el icono de
> LibDBIcon** como disparador (no elegido); **rotación, máscara/forma y blobs** del minimapa (no
> tienen getter para restaurarlos, doc 23); **segunda vista propia del mapa** (casi seguro
> inviable, doc 22).

---

## F0 — Diseño

**Decisiones del owner (2026-11-15):**
- Módulo: Minimap Lens. Desarrollo en `main`, oculto tras el «PRONTO» hasta cerrar el hito.
- Activación **solo manual**; la lente nunca se agranda sola.
- Disparadores: **atajo de teclado** (sin tecla por defecto: se asigna en Teclado › Atajos ›
  AddOns), **botón lupa** junto al minimapa **visible solo en instancia** y **`/qdt lens`**.
- Posición **movible y recordada** (con «Mover marcos», igual que el widget). Al apagar, el
  minimapa vuelve a su esquina.
- Tamaño y opacidad **con deslizadores**; al activarla, el zoom sube **un paso**.
- **Al salir de la mazmorra la lente se cierra sola.**
- Botones: **los de Blizzard se quedan en su sitio** y **los iconos de addons (LibDBIcon) se
  reacomodan alrededor del mapa grande**; al apagar, vuelven.
- Borde: **se oculta el aro de Blizzard** y se dibuja un **contorno QDT** fino con la paleta B
  (como el HUD del widget).
- Rastreo: interruptor **«Ocultar hierbas y minas mientras la lente está activa», apagado por
  defecto**. Guarda lo que tenía el jugador y lo restaura al apagar la lente o al cerrar sesión.
- Otros UI (EllesmereUI, ElvUI): **soporte con modo suave**. Se detecta quién manda en el
  minimapa, se reaplica tras él sin pelear y, si aun así pisa, se avisa una vez. ElvUI v16.01
  ya está instalado en `_forever_` (owner, 2026-11-15; su `.toc` declara 16001).

**Artboards** (página nueva «Minimap Lens», paleta B, componentes shadcn de Craft, contornos y
transparencias del HUD; memorias de estilo):
1. **Reposo en mazmorra**: minimapa normal con el botón lupa pegado (apagado) y su tooltip
   (atajo asignado o «sin atajo»).
2. **Lente activa**: mapa grande en su sitio, contorno QDT, iconos de addons alrededor, botones de
   Blizzard en la esquina, lupa encendida, con la opacidad aplicada.
3. **Mover marcos**: el marco de la lente con su borde y su etiqueta, como el del widget.
4. **Aviso de convivencia**: el aviso único cuando otro UI pisa la lente (chat o toast, se decide
   en el lienzo).
5. **Página del módulo** en la ventana principal: interruptor del módulo, tamaño, opacidad,
   rastreo de recursos, aviso del atajo con un botón para abrir Atajos, «Probar» y el estado de
   convivencia («Minimapa de EllesmereUI detectado: modo suave»).
6. **Sidebar**: la fila «Minimap Lens» sin «PRONTO» (solo al cerrar el hito).

Las animaciones de entrada y salida de la lente van con `Weave.tween` sobre la **opacidad**,
**nunca sobre el tamaño fotograma a fotograma** (doc 22: el renderer repinta el terreno y
parpadea).

## F1 — Sondas (tras el OK de F0)

Se corren en tres configuraciones: **sin otro UI**, **solo EllesmereUIMinimap** y **solo ElvUI**.
Detalle y método en doc 22 §sondas (S1-S11) y doc 23 §6 (S1-S9). Se agrupan en una sola sesión
de pruebas (memoria «pruebas in-game agrupadas»). Lo esencial:
- `ClearAllPoints`/`SetPoint`/`SetSize` del Minimap **en combate** y restaurar en combate.
- Quién escribe en el Minimap tras activar la lente: contador con `debugstack` y re-escrituras
  en `PLAYER_ENTERING_WORLD` diferido y en `PLAYER_REGEN_ENABLED`.
- Parpadeo A/B con y sin empujón de zoom propio, y `SetScale` frente a `SetSize`.
- Si el zoom de la lente se revierte solo a los +5/+10/+30 s (ElvUI, auto-reset de EUI).
- `SetAlpha` del Minimap: ¿atenúa el terreno renderizado, los pines y los iconos hijos?
- `C_Minimap.GetViewRadius` antes y después (¿se ve más área o solo más grande?).
- ¿Existen `SetBlipTexture`/`SetPlayerTexture` en Forever? (no documentadas).
- `Bindings.xml` + `BINDING_HEADER_*` en Teclado › Atajos › AddOns de Forever.
- Modo edición: ¿repone los anclajes de `MinimapContainer` con la lente activa?
- Restauración exacta: anclajes, tamaño, escala, zoom, alpha, posiciones de LibDBIcon y rastreo.

**Gotchas in-game:** _(se rellena en F1)_

## Puntos abiertos

| # | Punto | Quién decide | Recomendación | Estado |
|---|-------|--------------|---------------|--------|
| 1 | ¿El botón lupa se ve siempre o solo dentro de una instancia? | **owner** | solo en instancia | ✅ solo en instancia (2026-11-15) |
| 2 | ¿Atajo por defecto o sin asignar? | **owner** | sin asignar | ✅ sin asignar (2026-11-15) |
| 3 | ¿La lente también sube el zoom? | **owner** | un paso más | ✅ un paso más (2026-11-15) |
| 4 | Botones con la lente activa | **owner** | Blizzard quietos, LibDBIcon alrededor | ✅ así (2026-11-15) |
| 5 | Aro decorativo | **owner** | ocultar + contorno QDT | ✅ así (2026-11-15) |
| 6 | Ocultar rastreo de recursos | **owner** | opción apagada por defecto | ✅ así (2026-11-15) |
| 7 | Soporte de EllesmereUI/ElvUI | **owner** | modo suave + aviso único | ✅ así (2026-11-15) |
| 8 | Aviso de convivencia: ¿chat o toast? | **owner** | toast como el de fin de run | ⬜ (en el lienzo) |
| 9 | Valores por defecto y límites de tamaño y opacidad | agente (tras F1) | ~2× el original, opacidad 100 % | ⬜ |
| 10 | Revisar FarmMode/MountMapMove (guardan y restauran el ancla) | agente | `addon-scout` antes de F2 si F1 da sorpresas | ⬜ |

## Checklist de cierre del hito

Igual que la plantilla (`docs/PLAN-HITO_TEMPLATE.md`): CI con tests, demo + `deploy-local` antes de
la prueba, conformidad, poda de AGENTS.md (estado → M2), `ui-critic`, entrada en CHANGELOG +
NewsData y `Siguiente:` escrito aquí.

**Siguiente:** F0. Leer el lienzo (memoria `referencia-diseno-instance-tracker`), crear la página
«Minimap Lens» con los 6 artboards de §F0, publicarla y esperar el OK del owner.
