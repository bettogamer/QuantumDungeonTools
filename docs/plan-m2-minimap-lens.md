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
| **F0** | Diseño en el lienzo | ✅ OK del owner (2026-11-15, «continuamos con F1») | página «Minimap Lens» (lienzo v71): LensReposo, LensActiva, LensMover, LensAviso (A toast / B chat, punto 8 sin cerrar), AppLens |
| **F1** | Sondas de Forever (`/qdt check m2`) | 🔨 EN CURSO: sonda escrita y desplegada (2026-11-15), **esperando la sesión de pruebas del owner** | §F1 «Guion»: sin otro UI, con EllesmereUI y con ElvUI |
| **F2** | Núcleo de la lente | ⬜ PENDIENTE | `modules/MinimapLens/core/Lens.lua` (estado, límites de tamaño, snapshot y restauración) + `wow/Lens.lua` (aplicar/restaurar con `pcall`, contorno QDT, ocultar aro, `Refresh` de LibDBIcon) |
| **F3** | Convivencia con otros UI | ⬜ PENDIENTE | detectar el dueño, modo suave (`SetScale`, reaplicar tras ellos con guard, ceder si pisan y avisar una vez) |
| **F4** | Disparadores y ciclo de vida | ⬜ PENDIENTE | atajo (`Bindings.xml`, sin tecla por defecto), botón lupa (solo en instancia), `/qdt lens`, cierre al salir de la instancia, al abrir el Modo edición y al cerrar sesión |
| **F5** | Página del módulo + ajustes | ⬜ PENDIENTE | tamaño, opacidad, rastreo de recursos, «Mover marcos», aviso del atajo; quitar el «PRONTO» |

> Fuera de este hito por decisión previa: **flecha o posición del jugador** (no hay datos en
> instancia); **activación automática al entrar** (owner: solo manual); **clic en el icono de
> LibDBIcon** como disparador (no elegido); **rotación y blobs** del minimapa (no tienen getter
> para restaurarlos, doc 23); **segunda vista propia del mapa** (casi seguro
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
- Forma: **la lente es CUADRADA** (owner, 2026-11-15: «así vemos más terreno»). `SetMaskTexture`
  cuadrada mientras está activa (~27 % más área al mismo tamaño) y `GetMinimapShape()` →
  `"SQUARE"` para que LibDBIcon coloque los iconos en el borde cuadrado. Al apagarla: sin otro UI
  se restaura la máscara redonda de Blizzard (conocida: no hay getter). Con ElvUI o EllesmereUI,
  cuyo minimapa ya es cuadrado, la máscara no se toca.
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
- Máscara cuadrada en Forever: ¿el renderer pinta las esquinas (terreno y pines) o quedan
  vacías?, ¿qué textura de máscara usa Blizzard por defecto (para restaurarla)? y
  `GetMinimapShape` (¿la define alguien ya?, ¿la respeta LibDBIcon al hacer `Refresh`?).
- ¿Existen `SetBlipTexture`/`SetPlayerTexture` en Forever? (no documentadas).
- `Bindings.xml` + `BINDING_HEADER_*` en Teclado › Atajos › AddOns de Forever.
- Modo edición: ¿repone los anclajes de `MinimapContainer` con la lente activa?
- Restauración exacta: anclajes, tamaño, escala, zoom, alpha, posiciones de LibDBIcon y rastreo.

### Guion de la sesión de pruebas (owner)

Código: `modules/MinimapLens/wow/CheckM2.lua` + `Bindings.xml`. Vuelca a
`QuantumDungeonToolsDB._checkM2.runs[cfg]`, separado por configuración (la detecta sola:
`none`, `eui`, `elvui`). Lo lee el agente con `lua scripts/read-check-m2.lua [--log]`; el owner
solo responde las preguntas **visuales** (👁) de abajo. Mientras está armada, la sonda apunta
quién escribe en el minimapa: hooks de solo lectura más `debugstack`.

**Bloque A, fuera de mazmorra (~4 min por configuración, tres veces).** Configuraciones:
1. **sin otro UI** (EllesmereUIMinimap y ElvUI desactivados), 2. **solo EllesmereUIMinimap**,
3. **solo ElvUI**.
1. `/reload` con la configuración puesta.
2. `/qdt check m2`: ronda de ~36 s, sin tocar el minimapa. A los 8 s el mapa salta al centro
   de la pantalla; es parte de la prueba. Al terminar, el chat dice «Diferencias al restaurar:
   tamaño 0, escala 0. Errores: 0» si todo vuelve bien.
   👁 (solo sin otro UI) ¿las **esquinas** del mapa cuadrado pintan terreno y pines, o salen
   vacías? 👁 Hacia los 6 s el mapa baja un instante al 50 %: ¿se atenúa también el terreno?
3. `/qdt check m2 ab`: cuatro variantes de 3 s (A, B, C, D, las anuncia el chat).
   👁 ¿Cuál **parpadea** al crecer o al volver? ¿Cuál deja el **terreno viejo**
   (borroso o sin rellenar)?
4. `/qdt check m2 on`. Luego abrir y cerrar el **Modo edición**, hacer `/reload` (la lente
   vuelve a abrirse sola al segundo) y `/qdt check m2 off`.
   👁 (solo sin otro UI) Al apagar, ¿el borde **redondo** y el aro quedan como antes?
5. `/qdt check m2 combat` y pegarle a un bicho: la lente se abre y se cierra dentro del
   combate. El chat da «aplicar true, restaurar true» si funciona.
6. Solo la primera vez: Teclado › Atajos › AddOns. 👁 ¿Aparece «Quantum Dungeon Tools ›
   Minimap Lens (probe)»? Asignarle una tecla y pulsarla dos veces: abre y cierra la lente.

**Bloque B, en mazmorra (una vez, en la run agrupada; con la configuración que se juegue).**
`/qdt check m2 on` **antes** de entrar → entrar (pantalla de carga: lo que haga EllesmereUI
justo ahí) → un pull con la lente puesta → `/qdt check m2 off` dentro.

Al terminar, `/reload` (para que se escriba el volcado) y avisar. `/qdt check m2 reset` lo borra.

**Qué responde cada paso** (sondas de los docs 22 y 23): ronda → S1 (tamaño, zoom y radio de
visión a +0/1/2/5/10/30 s, auto-reset del zoom), S3 alpha, S4 `SetScale`, S8 restauración,
`GetMinimapShape` + `Refresh` de LibDBIcon (radio de cada icono contra medio ancho), máscara
cuadrada. `ab` → parpadeo y empujón de zoom. `on` + `/reload` → restauración tras recargar,
Modo edición y escrituras ajenas en PEW y al salir de combate (si alguien encoge la lente, la
sonda la reaplica una vez y anota `STOMPED`). `combat` → S10 (`SetSize`/`SetPoint`/`SetTracking`/
`SetCVar` en combate, `ADDON_ACTION_BLOCKED`). Estático → API (`SetBlipTexture`…), anclajes de
los botones de Blizzard, lista de rastreo y atajo. **Descartado de F1:** la prueba de
`SetParent` (S7 del doc 22), porque la lente no reparenta, y la segunda vista del mapa (S9).

**Gotchas in-game** (volcado `_checkM2`, Forever 1.60.1 build 70938):

*Configuración EllesmereUIMinimap (2026-11-15; pasos 1-4, falta el 5 de combate):*
1. **Repintado: agrandar sin tocar el zoom deja el terreno viejo.** La variante A (`SetSize` solo)
   pintó un cuadrante. Con un paso de zoom (B) o con el empujón (C) se repinta, sin parpadeo
   visible. `SetScale` (D) repinta solo. La lente siempre mueve el zoom al agrandar; con el paso
   del diseño basta.
2. **EUI reancla el Minimap en cada cambio de tamaño o escala** (`ClearAllPoints`/`SetPoint`
   desde el core «EllesmereUI», su sistema de anclajes): conserva la esquina superior derecha
   (CENTER 971,490 → 844,362 al doblar). **El `SetPoint` propio al centro lo deshizo en menos de
   2 s.** Con EUI, la lente no se puede mover libremente: crece desde la esquina de EUI.
3. **EUI no pisa la lente mientras se juega:** no hubo escrituras suyas durante la ronda ni
   con la lente puesta. Sí reaplica (`SetParent`/`SetScale(1)`/`SetSize(255)`/máscara/zoom) en
   tres ráfagas, de 2,3 a 4 s **después del PEW del `/reload`**. Pisó la lente que la sonda había
   reabierto a +1 s. Regla para F2: la lente **no sobrevive** a un `/reload` ni a una pantalla
   de carga (con EUI, reabrirla exigiría esperar a que EUI acabe).
4. **Iconos LibDBIcon con EUI:** EUI los esconde (`shown=false`, alpha 0, cajón propio). El
   `Refresh` de LibDBIcon los fuerza visibles en el borde (radio ~177 con mitad 127) y siguen
   visibles tras restaurar. **Con EUI no se tocan los iconos** (la sonda ya no lo hace).
5. **Restauración exacta:** `off` deja 1 diferencia, de subpíxel (971,47 → 971,5, reanclaje de
   EUI). El `/reload` con la lente puesta devuelve el tamaño original solo.
6. **Zoom:** el paso de zoom se mantuvo hasta +10 s, pero a +29 s estaba en 0 y **ningún setter
   enganchado lo escribió**. El temporizador de EUI solo se arma con zoom manual. Origen sin
   aclarar; se vuelve a mirar en «sin otro UI».
7. `C_Minimap.GetViewRadius` **no sirve como medida:** con el mismo tamaño y zoom 0 dio 150 y
   después 233. Se descarta.
8. API: **no existen** `SetBlipTexture`, `SetPlayerTexture` ni `SetPOIArrowTexture`/
   `SetStaticPOIArrowTexture`; sí `SetIconScale` y `SetArchBlobRingScalar`. EUI ya define
   `GetMinimapShape` = `SQUARE` y usa la máscara 130937. Rastreo: 25 tipos (en este personaje,
   «Find Minerals» 2580 activo).
10. **Combate (paso 5): sin bloqueos.** En `PLAYER_REGEN_DISABLED`, `InCombatLockdown()` todavía
   da `false`; la restauración a +3 s corrió **con lockdown `true`** (`SetSize`/`ClearAllPoints`/
   `SetPoint`/`SetZoom`/`SetAlpha`/`SetScale` y `Show` del aro) sin error ni `ADDON_ACTION_BLOCKED`.
   EUI solo reancla al salir de combate (+0,7 s tras `REGEN_ENABLED`), sin tocar el tamaño.
   `SetTracking`/`SetCVar` se probaron antes del lockdown: no cuentan (la sonda los pasa a +3 s).
9. Modo edición: **ningún** `EditMode.Enter`/`Exit` registrado (falta confirmar que se abrió el de Blizzard).


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

**Siguiente:** F1. El owner corre el guion de §F1 (bloque A en las tres configuraciones; el
bloque B en la run agrupada) y avisa. El agente lee el volcado con `scripts/read-check-m2.lua`,
rellena «Gotchas in-game» y cierra el punto 9 (límites). Si una sonda contradice el diseño,
se vuelve al artboard antes de F2. Punto 8 (toast o chat) sigue abierto para el owner.
