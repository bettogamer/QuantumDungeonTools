# Plan M1 — Instance Tracker v1 (widget Craft + récords + datos de run)

> Hito M1 (AGENTS.md §10). Reconstruye el módulo Instance Tracker sobre Craft vendoreado con el
> diseño cerrado de la sesión 2 (récord personal, pausa/retomada por copia, oro/rep, 10/hora,
> tooltip, toast, aviso e Historial). Deja fuera Minimap Lens y el protocolo NIT. **Una sesión
> por fase.** **Este doc es el registro vivo de fases**: el estado real del hito vive AQUÍ.

## Contexto

La sesión 1 dejó un v0.1 con widgets nativos, **sin probar in-game** (doc 00 §6). En la sesión 2
se cerró el diseño (lienzo: https://claude.ai/artifact/QCFDYZLH1HU8Mj72a3VAXy, 8 artboards; leer
con `Artifact read` + `path: project/<Artboard>.dc.html`), se confirmó que Craft funciona en
Forever (Coffer) y el owner aceptó todas las mejoras, repartidas en 4 niveles (doc 00 §7).

Orden de las fases: primero **medir** (F1: lo que el diseño da por hecho y nadie ha visto en
Forever), después **la base** (F2 Craft + widget, F3 modelo), y por último **las capas** que
cuelgan de ellas (F4 tooltip/datos, F5 avisos, F6 Historial y ajustes). Así, si una medida de F1
sale mal, solo se replanifican las capas y no hay que tocar la base.

## Fases

| Fase | Feature | Estado | Nota |
|------|---------|--------|------|
| **F1** | Sondas de Forever (`/qdt check f1`) | 🔨 EN CURSO (código hecho, falta la prueba in-game) | solo medir lo que el diseño asume; el v0.1 nativo NO se prueba (owner, 2026-11-12) |
| **F2** | Vendoreo de Craft + widget nuevo | 🔨 EN CURSO (código hecho, falta `/qdt check f2` + prueba in-game + `ui-critic`) | niveles 1-2 del diseño: En curso, Completada, Compacto, Primera vez; aquí se pasa por fin el checklist de doc 00 §6 |
| **F3** | Modelo v2: récord, pausa/retomada, muertes | 🔨 EN CURSO (código hecho 2026-11-13, falta la prueba in-game) | `core/Records.lua` + `Run.deaths`/`Run.pb`; DB aditiva (`records`), sin migración |
| **F4** | Oro, reputación, ritmo + tooltip Detalle | ✅ HECHA en código (2026-11-13: F4a fila de totales, F4b tooltip Detalle); falta prueba in-game | nivel 3 (hover) |
| **F5** | Contador 10/hora, aviso 10/10, toast de fin de run | ⬜ PENDIENTE | nivel 4 (avisos) |
| **F6** | Ventana Historial + ajustes por línea | ⬜ PENDIENTE | nivel 4 (Historial), líneas desactivables |

> Fuera de este hito por decisión previa: **Minimap Lens** (módulo futuro, hito propio);
> **protocolo NIT** de NF (requiere LibSerialize/LibDeflate/AceComm); **flecha o posición del
> jugador en mazmorra** (imposible, AGENTS.md §5); **alts/durabilidad** de NF (descartados en el
> inventario §9).

---

## F1 — Sondas de Forever

**Decisiones del owner (2026-11-12):** no se prueba el v0.1 con widgets nativos: se va directo a
la UI con Craft. El checklist de doc 00 §6 (modelo y eventos) se pasa en la prueba de F2.

**Alcance:** un `/qdt check f1` que **mida** (y vuelque a `QuantumDungeonToolsDB._checkF1`) lo que F2-F5 dan por
hecho:
- `GetInstanceLockTimeRemainingEncounter(i)`: si `isKilled` cambia tras matar un jefe (el
  pendiente de la sesión 1) y qué es el 4.º booleano.
- Formato del GUID en Forever (`type-0-server-instanceID-zoneUID-id-spawn`): si el zoneUID existe
  y es estable entre `/reload`, y si es distinto tras resetear la instancia. Medirlo sobre
  `target`/`mouseover`, nunca midiendo nameplates (doc global: `GetCenter` lanza).
- Que existan las globales localizadas `GOLD_AMOUNT`, `SILVER_AMOUNT`, `COPPER_AMOUNT`,
  `FACTION_STANDING_INCREASED*` e `INSTANCE_RESET_*`, y los eventos `CHAT_MSG_MONEY` y
  `CHAT_MSG_COMBAT_FACTION_CHANGE`.
- Si en Forever existe el límite de 10 instancias/hora (mensaje `ERR_TOO_MANY_INSTANCES` o
  equivalente): de esto depende que F5 sea un contador real o solo informativo.
- `issecretvalue` sobre cada uno de los valores leídos (es el motor de 12.1.5).

**Entregado (v0.1.1):** `/qdt check f1`, sin tocar la UI.

**Prueba in-game:** solo `/qdt check f1` en una mazmorra, antes y después del primer jefe (y
tras un reset para el zoneUID). El agente lee `_checkF1` con un reductor; la UI nativa no se
firma.

**Hecho (2026-11-12, sin probar in-game):** `core/Guid.lua` (parser puro + spec),
`wow/CheckF1.lua` y el reductor `scripts/read-check-f1.lua`. La primera llamada a
`/qdt check f1` deja **armado un registro pasivo** (sobrevive a `/reload`; `/qdt check f1 off`
lo borra) que hace solo una foto al entrar en la instancia, al empezar cada encuentro y 4 s
después de cada muerte, y que apunta los zoneUID que ve en target/mouseover y las líneas de
dinero, reputación, sistema y error que mencionan instancias o resets.

**Hechos medidos (2026-11-12, Forever 1.60.1 build 70938, Ruins of Lordaeron Normal, solo,
9 fotos; `lua scripts/read-check-f1.lua`):**
- **GUID y nombre de criaturas: SECRETOS.** `UnitGUID` y `UnitName` de target y de mouseover
  dentro de la mazmorra (fuera de combate, también tras `/reload` y tras reset) → no hay
  zoneUID ni npcID. **F3 va al plan B** (ver punto abierto 6), salvo que funcione el castGUID.
- **Cómo lo hace Naowh Forever** (`NaowhForever_Utilities/InstanceTracker/InstanceTracker.lua`
  `:287-290`, `:895-912`, `:1454-1468`, `:1753-1765`): mismas fuentes que salieron secretas
  (target, mouseover, nameplates; si son secretas, `PlainGuid` las descarta en silencio) **más el
  castGUID de tus propios hechizos** (`UNIT_SPELLCAST_SENT/START/CHANNEL_START`,
  `Cast-3-server-instanceID-zoneUID-spellID-…`).
- ✅ **El castGUID propio llega PÚBLICO y SÍ identifica la copia** (medido en solitario, 2.ª
  tanda): `cast:sent` y `cast:start` 5/5 públicos, muestra `Cast-3-6831-2999-5-1026-…`; zoneUID
  **5** antes del reset y **6** después (el reset llegó entre medias por `CHAT_MSG_SYSTEM`).
  Target 0/2, mouseover 0/3 y nameplate 0/5 → secretos siempre. El zoneUID es un entero pequeño
  y correlativo. **F3 = plan A con castGUID** (`UNIT_SPELLCAST_SENT`/`_START`/`_CHANNEL_START`);
  hasta que el jugador lance algo, la copia es «desconocida» y se aplica el criterio del punto 6.
- **Sin identificador de copia:** `GetNumSavedInstances()` = 0 en Normal (no te guarda) →
  `GetSavedInstanceInfo` no sirve para distinguir copias.
- `GetInstanceLockTimeRemainingEncounter(i)` → **4 valores**: nombre, `nil` (sin textura),
  `isKilled`, 4.º booleano (`false` en todos los jefes vivos). Sin datos tras una muerte:
  pendiente de la run en grupo. `i = total+1` devuelve una fila vacía.
- **Fuera de instancia la API de lockout devuelve basura:** en «Eastern Kingdoms» da total 1 con un
  jefe «No Longer in Use». Leerla SOLO con `itype` party/raid (Tracker ya lo hace).
- **Reset:** `CHAT_MSG_SYSTEM` «Ruins of Lordaeron has been reset.» = `INSTANCE_RESET_SUCCESS`
  (`%s has been reset.`) → señal fiable de «copia nueva» para el líder. Al volver a entrar llegó
  además «Transfer Aborted: instance not found».
- **Dinero:** existen `YOU_LOOT_MONEY`, `LOOT_MONEY_SPLIT`(+`_MOD`/`_GUILD`), `GOLD/SILVER/
  COPPER_AMOUNT` y `*_AMOUNT_TEXTURE`. No se looteó nada: falta una línea real de `CHAT_MSG_MONEY`.
- **Reputación:** existen `FACTION_STANDING_INCREASED*` y además las variantes
  `*_ACCOUNT_WIDE` (hay que parsear las dos). **No existen** `GetFactionInfo`,
  `GetNumFactions` ni `GetWatchedFactionInfo` → API moderna `C_Reputation`.
- **Límite por hora:** no hay `ERR_TOO_MANY_INSTANCES`, pero sí
  `TRANSFER_ABORT_TOO_MANY_INSTANCES` («You have entered too many instances recently.») y
  `ERR_LFG_FARM_LIMIT`. El texto existe; que Forever lo aplique sigue sin verse (punto abierto 5).
- Los 17 eventos son válidos; `issecretvalue` real presente.

**Guion partido en dos (owner, 2026-11-12: en solitario no puede matar jefes):**
- **Ahora, en solitario:** pasos 1, 2 y 4 + oro/reputación de bichos normales + `/reload`.
- **En la próxima run en grupo:** jugar normal (el registro pasivo hace solo las fotos
  `auto:pull`/`auto:after-kill`) y `/reload` al acabar. Hasta entonces quedan abiertas las
  preguntas `isKilled` y 4.º booleano; F2 no depende de ellas y puede empezar.

**Guion (owner):**
1. Fuera: `/qdt check f1` (estático: globales, eventos, APIs). En el chat debe salir
   «registro pasivo ACTIVADO».
2. Entra en una mazmorra **sin hacer nada más**: la foto `auto:enter` sale sola. Haz target a
   un bicho cualquiera y `/qdt check f1 antes`.
3. Mata al primer jefe (las fotos `auto:pull` y `auto:after-kill` salen solas). Lootea oro y,
   si puedes, gana reputación. `/reload` y `/qdt check f1 tras-reload` con un bicho en target.
4. Sal, resetea la instancia (menú del retrato), vuelve a entrar, target a un bicho y
   `/qdt check f1 tras-reset`.
5. Si llegas al límite de instancias por hora, mejor: el mensaje se registra solo.
6. `/reload` (para que se escriba el archivo) y avísame. Lo leo con
   `lua scripts/read-check-f1.lua`.

## F2 — Vendoreo de Craft + widget nuevo

**Alcance:**
- Vendorear el build **Craft v2.47.0** (`craft/Craft/` @`ac2ebb3`, tag `v2.47.0`, build 49) en
  `QuantumDungeonTools/libs/Craft/`, **sin su `libs/`** y con `media/` completo (BettoGeo
  incluida). Craft `Reactive.lua` necesita **Weave** antes y la lib necesita **LibStub**: se
  vendorean desde las copias de Craft (`craft/Craft/libs/{LibStub,Weave}`) a `libs/`, con el
  orden de Coffer (LibStub → Weave → Craft). Tabla de versiones en `libs/README.md` y fila nueva en AGENTS.md
  §4 (hoy dice «ninguna / NO usar Craft»: **hay que cambiarlo en este mismo commit**, y el
  .luacheckrc debe excluir `libs/`).
- Usar un **contexto de tema propio** (Craft 2.30, FR-104) para no pisar el tema de Coffer ni de
  otros consumidores en el mismo cliente.
- Reescribir `wow/UI.lua`: widget **transparente**, sin fondo, con contorno y sombra; paleta Forever
  (oro #F2B84B, turquesa #3FD0D4, rojo #FF5A4E, crema #F8EEDB, secundario #93B4B2, pista
  #0F2A2C); BettoGeo Bold con cifras tabulares; barra de tiempo de 14 px. Estados: En curso,
  Completada, Compacto, Primera vez (sin récord: barra de jefes por segmentos). Nivel 2
  contextual: «Instancias X/10» a partir de 7/10 (hueco hasta F5) y barra de XP oculta al nivel
  máximo.
- Los colores y tamaños se declaran como tokens en un único archivo; nada de hex sueltos por la
  UI.

**Entregado (v0.2):** libs vendoreadas, `UI.lua` sobre Craft, `.toc` con el bloque de libs.
Antes de cerrar la fase, pasarla por `ui-critic` con capturas contra los artboards.

**Hecho (2026-11-12, sin probar in-game):**
- `libs/` = LibStub (minor 2) + Weave v0.10.0 + Craft v2.47.0 (build 49, @`ac2ebb3`), copiadas de
  `craft/Craft/` sin sus `libs/`; `media/` completo. Tabla en `libs/README.md`.
- `core/Style.lua` (único archivo con colores y tamaños, deriva de `core/Brand.lua`),
  `core/View.lua` (run + récord + XP → lo que se pinta, con tonos semánticos; 20 specs en
  `View_spec.lua`), `core/Demo.lua` (los números de los artboards), `Format.clock`/`delta`.
- `wow/UI.lua` reescrito: contexto de tema `QuantumDungeonTools` (BettoGeo + OUTLINE + paleta),
  FontStrings con `ctx:applyFont` + sombra, bordes con `Craft.Theme.AnchorBorder`, tooltip del
  compacto con `Craft.Tooltip` (líneas dobles). Solo la cabecera (o el panel compacto) coge el
  ratón; el resto deja pasar los clics.
- `Tracker:XPSnapshot()` (descanso, nivel máximo con `GetMaxLevelForPlayerExpansion` →
  `GetMaxPlayerLevel`, `IsXPUserDisabled`; nada medido aún en Forever: lo mide `check f2`).
- Ya preparado para F3/F5: la vista acepta `pb`, `deaths` e `instances` (hoy `nil` → ocultos).
  Con datos reales, F2 solo puede enseñar **Primera vez** (o Completada sin récord); los estados
  con récord se ven con `/qdt it demo live|done`.
- Smoke sin cliente (scratchpad, mock de Craft): los cuatro estados se construyen, check f2 16/16.
- **Decisiones del agente (revisables):** «−» ASCII en los deltas (BettoGeo puede no traer
  U+2212); peso 600 del diseño → BettoGeo Medium; sin X de cerrar (clic derecho en la cabecera);
  una run terminada sin récord pinta el reloj en oro y no promete récord si tenía jefes `preKilled`.

**Guion F2 (owner):** el agente ya hizo el deploy.
1. `/reload`. En el chat: «Quantum Dungeon Tools vdev cargado». Sin errores en `/sack`.
2. `/qdt check f2` → debe decir `16/16 ok`. Si sale alguna `FALLA`, cópiamela (o `/reload` y la
   leo con `lua scripts/read-check-f2.lua`).
3. `/qdt it demo live`, `done`, `first` y `compact`: una captura de cada una (para `ui-critic`
   contra los artboards Main, Completada, PrimeraVez y Compacto). Comprueba a ojo: texto con
   contorno y sin fondo; reloj **16:22** turquesa con **/ 31:40**; «Jefes 3/7 · vs. récord
   **-0:17**»; barra dorada a la mitad con 7 marcas (3 doradas); XP «+18,450 XP en la run» y
   «Nv 54 · 62% · descanso 18%»; «Instancias 8/10 · libre en 12:40»; Witherfang **[3:58] -0:12**
   (delta turquesa), The Abandoned **[8:41] +0:20** (rojo). `done`: **29:51** turquesa, 31:40
   tachado, «NUEVO RÉCORD -1:49». `first`: «PRIMERA VEZ» y 7 segmentos (3 dorados). `compact`:
   una línea con panel; al pasar el ratón, la lista de jefes. ¿Se ven bien las tildes y el «·»?
4. Arrastra el widget por la cabecera, `/reload`, `/qdt it demo live`: conserva la posición. Clic
   derecho en la cabecera lo oculta. `/qdt it demo off`.
5. Entra en una mazmorra: el widget sale solo en estado **Primera vez** con la lista de jefes
   (checklist de doc 00 §6: puntos 1, 3-5 y 8 en solitario; 2, 6 y 7 —matar jefes— en la próxima
   run en grupo). `/reload` dentro: la run sigue igual.

## F3 — Modelo v2: récord, pausa/retomada, muertes

**Alcance (todo en `core/` puro + tests):**
- **Récord personal (PB)** por mazmorra+dificultad: tiempo total y split por jefe. Delta en vivo
  contra el split del PB (turquesa si vas por delante, rojo si vas por detrás). Una run solo cuenta
  como récord si es completa y sin jefes `preKilled`.
- **Pausa/retomada por copia** (como NF): la run se identifica por `zoneUID`. Al salir, el reloj
  se pausa; al volver a la misma copia se retoma (indicador «retomada»); con otra copia empieza
  una run nueva. Modelo `Elapsed` con huecos (`skipped/seen`) del inventario §9. Si F1 dice que el
  zoneUID no es fiable, el plan B es el criterio actual (nombre + dificultad + instanceID).
- **Muertes** por run (`PLAYER_DEAD`, solo dentro).
- **Schema `QuantumDungeonToolsDB` v2** (`records`, run con `zoneUID`/pausas/muertes). No hay
  ningún tag publicado: la migración se escribe solo si para entonces ya existe uno (AGENTS.md §5).

**Entregado (v0.3):** `Run.lua` ampliado + `Records.lua` puro, specs nuevas, widget con delta.

**Hecho (2026-11-13):** `core/Records.lua` (clave `instanceID|dificultad`, solo runs terminadas y
limpias, gana la más rápida, `get` devuelve copia). Cada run guarda al empezar el récord contra el
que corre (`run.pb`), así «Completada» sigue mostrando el delta contra el récord viejo; al terminar,
`Tracker._notify` llama a `Records.consider` y marca `run.newRecord` (va al historial, F6). Muertes:
`PLAYER_DEAD` dentro de la instancia → `Run:addDeath()` (no cuenta en pausa ni con la run cerrada).
Pausa/retomada y reset ya estaban (`8738836`, `f8ee478`). Specs: `Records_spec.lua`.

## F4 — Oro, reputación, ritmo + tooltip Detalle

**Alcance:** oro looteado por run (`CHAT_MSG_MONEY`, que se parsea con las globales que mide F1;
siempre con iconos de moneda mediante el patrón `MoneyDisplay` de Coffer), reputación por facción,
ritmo de XP/h y oro/h y «runs para subir de nivel», récord con este grupo (firma del grupo como
`GroupsDiffer` de NF) y huecos de instancia. Todo esto va en un `Craft.Tooltip` al pasar el ratón
por encima (artboard Detalle). Los números entran al snapshot saneados con `scrubNum`.

**Entregado (v0.4).**

**F4a hecha (2026-11-13):** `core/ChatParse.lua` convierte las globales del cliente en patrones
(`%s`, `%d`, `%.1f`, posicionales `%1$s`): `money` (YOU_LOOT_MONEY / LOOT_MONEY_SPLIT y sus
variantes `_GUILD`, monedas en texto o con icono) y `rep` (FACTION_STANDING_INCREASED/_DECREASED,
con `_BONUS`/`_ACCOUNT_WIDE`; las `_GENERIC` sin cantidad se ignoran). `Run.copper`/`Run.rep`
suman con la run viva, también tras el último jefe (su botín llega después), no en pausa ni con la
run cerrada. Línea secreta → `degraded`. Widget: fila de totales «+oro  +350 Facción  [Instancias]»
(la facción que más sube; el resto, al tooltip). Specs: `ChatParse_spec.lua`.
**F4b hecha (2026-11-13):** `core/Detail.lua` (puro) arma las secciones del artboard Detalle:
RITMO (XP/h y oro/h sobre el tiempo de la run, desde 60 s; «Para nivel N ~K runs» con la media de
XP de las últimas 5 runs terminadas de esa mazmorra, o la propia run si ya terminó), REPUTACIÓN
(todas las facciones), RÉCORDS (personal + «Con este grupo (N)»: la mejor run limpia del historial
con la misma firma de grupo) e INSTANCIAS (solo si llega `opts.instances.slots`, lo da F5). La firma
del grupo (`Detail.groupKey`: nombres de `party1..4` ordenados) se guarda en `run.group` al empezar
y en cada `GROUP_ROSTER_UPDATE` mientras la run está viva. UI: `Craft.Tooltip` a la izquierda del
widget completo, solo sobre el bloque de arriba (cabecera → fila de totales; la lista de jefes no, owner: en combate el cursor la barre); esa zona solo captura el hover (`SetMouseMotionEnabled`, sin clics) y la cabecera
también lo muestra. Historial y grupo se leen solo al pasar el ratón. Specs: `Detail_spec.lua`.

## F5 — Contador 10/hora, aviso 10/10, toast de fin de run

**Alcance:** contador de instancias por hora a nivel de cuenta (todos los personajes, ventana
deslizante de 3600 s, sin contar dos veces la misma copia), sección INSTANCIAS del tooltip Detalle (la etiqueta del widget se quitó: owner 2026-11-13, robaba la fila de totales), aviso al
entrar en una instancia nueva estando a 10/10 (artboard Avisos) y toast al terminar la run con
botón para compartirla en el grupo (troceado a 255 caracteres y enviado con `pcall`, como `SendLine` de NF).

**Entregado (v0.5).**

## F6 — Ventana Historial + ajustes

**Alcance:** `Craft.Window` Historial (artboard Historial) con filtros por mazmorra, dificultad y
personaje; récords marcados. Ajustes: cada línea del widget se puede desactivar, más autoShow y
Compacto. El historial sube de 20 a **100 runs** (owner, 2026-11-12); los récords se guardan aparte y no caducan.

**Entregado (v1.0)** → release del hito.

## Pruebas in-game pendientes (se hacen TODAS juntas en una run)

Las mazmorras de Forever son largas: no se prueba cambio a cambio (owner, 2026-11-13). Cada
cambio de lógica de run añade aquí su caso; se tachan en la run de prueba.

- [ ] **Copia de la mazmorra (`3461ce9`)**: entrar solo y matar adds → salir → unirse a un grupo
  → entrar en la copia del líder. Al primer hechizo el widget empieza run nueva (reloj a 0); la
  run de solo adds no va al historial; la kill del primer jefe se queda.
- [ ] Misma copia: salir y volver a entrar sin cambiar de grupo → al primer hechizo la run sigue.
- [ ] Invitado estando dentro y llevado a la copia del líder sin salir de la mazmorra.
- [ ] **Reset (`CHAT_MSG_SYSTEM` «X has been reset.»)**: matar algo → salir → «Reset all
  instances» → el widget cierra la run al momento (sin esperar a entrar). Volver a entrar → run
  nueva con el reloj a 0. Probarlo también como miembro no líder (¿le llega el mensaje?; si no,
  lo cubre el castGUID al primer hechizo).
- [ ] **Pausa del reloj**: dentro de una run, salir de la mazmorra unos minutos → al volver el
  reloj sigue donde estaba (no suma el tiempo fuera). Desloguear dentro y volver a entrar → igual.
- [ ] Fuera más de 30 min (o con otra dificultad) → al volver, run nueva.
- [ ] **Récord (F3)**: terminar una run limpia (entrando con la mazmorra sin tocar) → la siguiente
  run de esa mazmorra y dificultad muestra «/ tiempo», marcas de split en la barra y delta por jefe.
  Una run con jefes ya muertos al entrar NO se guarda como récord.
- [ ] **Oro y reputación (F4a)**: lootear dinero (solo y en grupo, reparto) y ganar reputación
  dentro → fila de totales con iconos de moneda y «+N Facción». Comprobar que la línea real de
  `CHAT_MSG_MONEY` casa con `YOU_LOOT_MONEY`/`LOOT_MONEY_SPLIT` de Forever (el registro de F1 la captura).
- [ ] **Tooltip Detalle (F4b)**: `/qdt it demo live` y pasar el ratón → 4 secciones como el
  artboard (XP/h 67,637, oro/h con iconos, «Con este grupo (2) 28:05» en turquesa, huecos 12:40 /
  21:15). Comprobar que el widget NO bloquea clics al mundo debajo y que la cabecera sigue
  arrastrándose. En grupo real: tras terminar una run, la siguiente con el mismo grupo enseña la fila.
- [ ] **Muertes (F3)**: morir dentro → «1 muerte» en rojo junto al reloj; morir fuera no suma.
- [ ] Run completada: salir y volver a entrar (o `/reload` dentro) → sigue mostrándose Completada
  con su tiempo, no una run vacía.

## Siguiente (handoff 2026-11-13, sesión F4b)

Estado: F4 hecha en código y alineada con el lienzo (v35). Decisiones de diseño de hoy: sin etiqueta de
instancias en el widget (solo tooltip + aviso 10/10), fila de totales a la DERECHA con 20 px entre oro y
reputación (opción B), lista de jefes con `bossTop` 4, monedas 2/5 px, tooltip en BettoGeo Medium, fuente al
tamaño del diseño y geometría ×1000/932. Regla: diseño antes que código; colores solo de la paleta B.

Pendiente, en este orden:
1. **Limpieza del lienzo** (pedido del owner): en «Paleta» dejar SOLO la propuesta B elegida (quitar A y C
   y el selector); revisar «Primary del tema Craft» (dejar solo la elegida: oro con texto navy); borrar el
   artboard de comparación «Fila de totales: A / B / C» (ya decidido B); repasar que todos los artboards
   usan la paleta B (hecho en v31) y que las notas del lienzo no mencionan cosas quitadas. Diseño solo.
   **Después, cotejo diseño ↔ código** (pedido del owner): cada artboard del widget (En curso, Completada,
   Primera vez, Compacto, Pausa, Detalle) contra `Style.lua` (HEX, SIZE, FONT) y `UI.lua`/`View.lua`:
   colores, tamaños de fuente, márgenes, orden y alineación de filas, textos/Locale. Lista de diferencias →
   el owner decide cuál manda en cada una; ninguna se arregla sin su OK. Recordar que el código escala la
   geometría ×1000/932 a propósito (no es diferencia). Delegable a un subagente que escriba la tabla en docs/.
2. Recortes con «…» de nombres de jefe/raro y de la mazmorra en la cabecera (ui-critic, docs/14 §2 y §5) y
   tokens para los márgenes de 2 px sueltos de UI.lua (§4). Código, sin cambio visual.
3. F5 (abajo).

## Puntos abiertos

| # | Punto | Quién decide | Recomendación | Estado |
|---|-------|--------------|---------------|--------|
| 1 | ¿Probar el v0.1 nativo (F1) antes de reescribir la UI, o saltar directo a F2? | **owner** | Probarlo: el modelo y los eventos no cambian con la UI, y medir `isKilled`/zoneUID ahora evita rehacer F3 | ✅ **No** (2026-11-12): directo a Craft; el checklist del v0.1 pasa a F2 |
| 2 | Rama de trabajo: trunk-based o `dev` (AGENTS.md §8 PENDIENTE) | **owner** | trunk-based en `main` (proyecto de una persona) + primer commit del v0.1 antes de F2 | ✅ **trunk-based en `main`** (2026-11-12) |
| 3 | Tope del historial (20 hoy, 80 en NF) | **owner** | 100 runs + récords aparte (los récords no caducan) | ✅ **100** (2026-11-12) |
| 4 | Resolución del reloj: `time()` (1 s, sobrevive a relog) o `GetTime()` (preciso, se reinicia) | agente | `time()` como ancla persistida + `GetTime()` solo para pintar fracciones; los splits se guardan en segundos enteros | ⬜ |
| 6 | Pausa/retomada: la copia sale del castGUID (✅ medido); ¿qué hacer mientras aún no hay ningún hechizo lanzado en la copia? | **owner** | Respaldo hasta el primer hechizo: retomar si se cumple TODO: misma instanceID+dificultad, sin mensaje de reset entre medias, fuera < 30 min y el lockout no tiene menos muertos que la run (si los tiene, es una copia nueva). Si no, run nueva. `/qdt new` sigue como salida manual | ✅ **Lo propuesto** (owner, 2026-11-12). Implementado 2026-11-13 (`Run:pause/resume/canResume`, reset por `CHAT_MSG_SYSTEM`); el chequeo del lockout con menos muertos sigue en `lockoutWasReset` |
| 7 | Idea del owner (2026-11-13): clic en el nombre de un jefe → ping (sistema de pings de WoW: «atacar» + localizarlo) | **owner** (alcance) | Viable solo como botón seguro con macro `/target <nombre>` + `/ping attack` + `/targetlasttarget` (owner: así no pierdes tu objetivo; ojo, sin objetivo previo puede seleccionar uno antiguo; un ping necesita unidad: sin posición en mazmorra no se puede pingear a distancia); solo funciona si el jefe está a la vista, y las filas seguras no se crean en combate. Forever SÍ tiene pings (owner los usa siempre, 2026-11-13); falta solo comprobar `/ping` en macro. | ⬜ |
| 5 | Si F1 dice que no existe el límite 10/hora en Forever | **owner** | quitar el contador del widget y dejar solo la cuenta informativa en el tooltip | ⬜ |

## Checklist de cierre del hito

- [ ] CI en verde y corriendo los tests (el job `test` cubre `tests/**`).
- [ ] Deploy + `/qdt check <fase>` en verde antes de cada prueba in-game.
- [ ] `/check-conformance` corrido.
- [ ] Poda de AGENTS.md (≤150 líneas, estado con fecha, Craft/Weave/LibStub en §4).
- [ ] Memoria podada.
- [ ] UI revisada por `ui-critic` (F2, F4, F6).
- [ ] `Siguiente:` escrito aquí antes de proponer cortar sesión.
- [ ] Release v1.0 con el ritual de doc 04.

**Siguiente (2026-11-13, noche):** (1) **hecho: tabla de mazmorras integrada.** `Run` recibe
`deps.resolve(instanceID, name)` (Tracker → `Dungeons.find` + `db.instanceTracker.learned`, que
`ENCOUNTER_END` rellena con `name → encounterID`); la lista va por la ruta (desconocidos detrás, rares
al final, `order`/`rare` persistidos; una run guardada antes se clasifica al cargar);
`total()`/`killedCount()`/fin de run sin rares; la vista quita los rares de segmentos y marcas.
Fila rare en `UI.lua` (owner, 2026-11-13, revisando el lienzo): **«RARO [6:10] Nombre»** (etiqueta
DELANTE del tiempo, así «[tiempo] nombre» se lee como en los jefes), 13 px, atenuada viva y **dorada
muerta** (no crema: crema = jefe pendiente). Tooltip del compacto: «Nombre  RARO». Lienzo
actualizado a esta fila (v23: Main, Completada, Primera vez).
Probado in-game con las demos live/done/first/compact (2026-11-13): cuadra con el lienzo; falta ver el tooltip del compacto y una run real.
**Tags sobre `Craft.Badge`** (FR-140, Craft 2.48.0, 2026-11-13): `newTag`/`setTag` de `UI.lua` crean
un Badge `outline` con fuente/padding/colores propios; la línea base sale de `GetBaselineOffset`.
**Falta prueba in-game:** alto de los tags (el Badge usa la línea CSS, puede salir +1 px), tags sin
la sombra 1,-1 del resto del HUD, RARE subido a 10 px (owner, 2026-11-13). Demos first/done/compact vistas in-game: tags alineados. Componentes de Craft para el resto: doc 12.
**Aceptado (owner, 2026-11-13):** los tags tienen ~2-4 px más de hueco a la derecha. Medido in-game
(«Normal»: caja 61.94 = 5.73 + texto 49.32 + 6.88, igual tras `/reload`, no es la carga async del
font): ~1 px del redondeo a píxel del Badge y el resto el avance tras la última letra que
`GetStringWidth` incluye. Sin FR ni parche local.
Nombres en inglés en la tabla:
aprobado por el owner (doc 11).
(2) próxima run del owner en una mazmorra que da XP (más larga):
el registro pasivo de check f1 sigue armado (600 líneas) → leer con un reductor y verificar el
muestreo de XP (`SampleXP`); (3) reset de instancia por el mensaje «X has been reset.»; (4) punto 7
(ping). Después: `ui-critic` con capturas → cerrar F2 → F3.
**Antes:** F2 en sesión nueva (AGENTS.md + este plan). F1 queda abierta solo por lo que
pide grupo u oro real, y el registro pasivo lo captura solo: una línea de `CHAT_MSG_MONEY` y otra
de reputación, `isKilled` y el 4.º booleano tras matar un jefe, y si se aplica el límite por hora.
Tras una run en grupo: `lua scripts/read-check-f1.lua` y anotar aquí. (2026-11-12: el registro pasivo
se amplió para una run entera sin `/reload`: 600 líneas, traza `QDT_RUN` del modelo del Tracker en
cada cambio, entrada/salida, combate, muerte/resurrección; XP/roster/UPDATE_INSTANCE_INFO solo cuentan.
Leer con un reductor, no el volcado entero.)
**Medido 2026-11-13 (Ruins of Lordaeron, Normal, grupo):** `ENCOUNTER_END` SÍ llega
(`id, name, diff=1, size=5, success=1, table`); el lockout **NO** marca `isKilled` ni sube `killed`
tras matar (after-kill 0/7, 4.º booleano false). Bug: `lockoutWasReset` comparaba con los muertos por
evento → cada muerte reiniciaba la run 1 s después. Arreglado: compara con `lockKilled` (máximo que
reportó el propio lockout). El reset en Normal tendrá que salir del mensaje «X has been reset.» (F3).
Resto de la run (con el arreglo): Viktor/Abandoned/Bjork/Rath'mael marcados con split; morir +
fantasma + volver mantiene la run. **La run nunca termina**: el rare Lordaeron Captain cuenta como
jefe (6/7 reales muertos) → filtrar rares (doc 11) también para el fin de run. Solo 1
`PLAYER_XP_UPDATE` en toda la run (+144 tras Rath'mael); el muestreo de XP (Tracker `SampleXP`) se
desplegó sin `/reload` antes de acabar: **sin medir**. Encounter IDs medidos: 3353 Witherfang,
3355 The Butcher, 3411 Viktor, 3357 Abandoned, 3412 Bjork, 3354 Rath'mael. Punto 5: owner (el 6 ya está decidido).
