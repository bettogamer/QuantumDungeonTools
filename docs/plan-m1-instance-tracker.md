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
| **F5** | Contador 10/hora, aviso 10/10, toast de fin de run | ✅ HECHA en código (2026-11-14: F5a contador + Detalle, F5b avisos, F5c toast); falta prueba in-game | nivel 4 (avisos) |
| **F4c** | % de trash + tiempo fuera de la mazmorra en el Detalle | ✅ HECHA en código (2026-11-14, lienzo v47); falta prueba in-game | punto 8c-8d: total de trash por mazmorra con los números de FDJ (citando la fuente); tiempo fuera en el modelo de la run **Hallazgo 2026-11-14:** FDJ NO trae totales de trash: los APRENDE por cuenta al completar runs (`RunLog.lua:498-503`, `max(seenN, kills)` → `runLogTrashTotal`), y el SavedVariables del owner no tiene ninguno. QDT tampoco cuenta kills de trash hoy. El tiempo fuera ya existe (`Run.pausedTotal`). **Decidido (owner, 2026-11-14):** (c) aprender como FDJ: contar `PARTY_KILL` anónimos menos los jefes detectados y guardar por mazmorra `max(total, kills)` al terminar una run limpia; el % sale desde que haya total, si no «N bichos». (d) fila «Fuera de la mazmorra m:ss» en RITMO del Detalle, solo si > 0. Diseño primero (artboard Detalle). |
| **F6** | Ventana principal (Historial + ajustes por línea) | ✅ HECHA (2026-11-14: F6a-F6e y Novedades, código + in-game; ver §F6 Subfases) | nivel 4 (Historial), líneas desactivables; decisiones del owner en §F6 |

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

**F5a hecha (2026-11-14):** `core/Hourly.lua` (puro): lista de cuenta `db.instanceTracker.hourly`
(aditiva, sin migración) de `{ at, instanceID, name, char, copy }`. Regla portada de NF (solo la
regla): cuenta al entrar en una copia nueva para nosotros (`CheckZone` → run nueva, o el primer
hechizo dice «otra copia»); `/qdt new`, `/reload` y la retomada no cuentan. La copia llega con el
primer hechizo (`Hourly.bindCopy`): si esa copia ya estaba contada en la hora, la entrada nueva se
quita. `T:HourSnapshot()` → `opts.instances` del Detalle (se lee solo al pasar el ratón);
`T:OnHourEntry(fn)` queda para el aviso de F5b. Specs: `Hourly_spec.lua`.

**F5b + F5c en código (2026-11-14):** `core/Alerts.lua` (puro: `hourNotice`, `toast`, `shareLine`,
`coins`, `chunks`) + `wow/Alerts.lua` (marcos, con el kit de `UI:Kit()`). Decisiones del owner
(2026-11-14): aviso 10/10 con **tres disparos** (entrada que llega a 10/10, `GROUP_JOINED` en
10/10, rechazo del juego: `TRANSFER_ABORT_TOO_MANY_INSTANCES`/`ERR_TOO_MANY_INSTANCES` por
`CHAT_MSG_SYSTEM` o `UI_ERROR_MESSAGE`); franja ámbar **al entrar en la 8.ª y la 9.ª**, 8 s; botón
**Historial oculto hasta F6**; «Compartir» = **una línea resumen** por INSTANCE_CHAT/RAID/PARTY
(sin texturas, menos ASCII, `QDT:` sin color, troceada a 255, `pcall`). Elecciones del agente
(✅ OK del owner in-game 2026-11-14, con las vistas previas animadas): el aviso y el toast van arriba al centro (`S.alertTop`, el lienzo no
fija sitio), apilados; el aviso dura 15 s y el toast 30 s (se paran con el ratón encima; clic en el
cuerpo = cerrar); el botón «Compartir» es crema con texto navy como el artboard (`Craft.Button` `secondary`,
tokens en `UI:Init`; corregido 2026-11-14 tras salir oro); del texto pequeño del aviso se quitó «Sale al entrar en el grupo o
al acercarte a una entrada» (sin posición en mazmorra no se puede detectar «acercarte»).
Specs: `Alerts_spec.lua`.

## F6 — Ventana Historial + ajustes

**Alcance:** `Craft.Window` Historial (artboard Historial) con filtros por mazmorra, dificultad y
personaje; récords marcados. Ajustes: cada línea del widget se puede desactivar, más autoShow y
Compacto. El historial sube de 20 a **100 runs** (owner, 2026-11-12); los récords se guardan aparte y no caducan.

**Decidido (owner, 2026-11-14):** (1) un solo historial de **100 runs por cuenta**; cada run nueva
guarda su personaje (campo aditivo `char`, sin migración; las viejas salen «—») y la ventana filtra
por **Personaje** (Todos por defecto), además de mazmorra y dificultad. (2) Una sola `Craft.Window`
con **pestañas Historial | Ajustes**. (3) Líneas desactivables: **lista de jefes, barra de tiempo,
barra de XP, fila de totales** (la cabecera con nombre y reloj queda siempre); más autoShow,
Compacto y botón de reset de la run (punto 8b). (4) Se abre con **`/qdt history`** (deja de
imprimir en el chat), el **botón «Historial» del toast** (se muestra ya) y un **icono del
minimapa** (vendorear LibDataBroker + LibDBIcon). Diseño primero: artboards Historial y Ajustes.

**Cambio de rumbo (owner, 2026-11-14):** IT es solo un módulo; F6 pasa a ser la **ventana principal
del addon** (patrón de la de Naowh Forever: barra lateral por módulos, página por módulo con pestañas,
ajustes en grupos plegables). Sustituye a la ventana de dos pestañas del punto (2). Lienzo v51,
página «Ventana principal»: artboards Inicio, Instance Tracker · Resumen, Instance Tracker ·
Historial + nota de arquitectura. ✅ **OK del owner (2026-11-14, lienzo v52)**, sin logo (no hay
icono del addon). **Modo edición** (mover widget y avisos): se necesita, no urge; copiar el de SMRT
cuando toque (el acceso «Mover marcos» de Inicio lo abrirá).

**Subfases (2026-11-14)**, una sesión cada una; API de Craft para todas: `docs/18-craft-api-f6.md`.

| Sub | Qué | Estado |
|-----|-----|--------|
| F6a | Modelo puro: `core/History.lua` (filtros mazmorra/dificultad/personaje, fila por run con fecha «Hoy/Ayer/10 nov», kind récord/atrasada/adelantada/sin terminar/primera, pie media/récord) + `core/Settings.lua` (defaults de las 8 opciones del grupo «Qué enseña», «N cambiados», Restablecer, resumen «3 de 4 líneas») + campo `run.char` («Name-Realm», aditivo) | ✅ código + specs |
| F6b | Ventana principal: `Craft.Window` headless (cabecera propia con «Recargar UI» y X), Sidebar 220 px (Inicio, MAZMORRAS › Instance Tracker, Minimap Lens «PRONTO», Ajustes generales, Novedades, versión), un frame por página con Show/Hide, página Inicio (AHORA, ABRIR, MÓDULOS). `/qdt` abre Inicio (la ayuda pasa a `/qdt help`). Exponer el `ctx` de tema de `UI.lua` | ✅ código (`wow/MainWindow.lua`, `View.now` + specs); ✅ vista in-game (owner, 2026-11-14, BugSack limpio). Desvíos: «PRONTO» del sidebar va en tooltip (Craft no tiene badge de fila → FR-152 de Craft); «Mover marcos» y el interruptor del módulo, visibles pero deshabilitados hasta F6c; la ventana tomaba tema y fuentes de `InstanceTrackerUI:Kit()` → ✅ subido a nivel addon (2026-11-14, previo a F6c): `core/Style.lua` (paleta, tonos, `WIN`, fuentes `win*`; el Style del módulo hereda con `Style.extend`) y `wow/Kit.lua` (contexto de tema, texto, borde, etiqueta; lo arranca Bootstrap antes que los módulos). La ventana ya no depende del módulo; ✅ in-game (owner, 2026-11-14: `check f2` 16/16 y ventana igual que antes) |
| F6c | IT › Resumen: interruptor del módulo (pide recargar), grupo plegable «Qué enseña» en 2 columnas con punto oro y pie Restablecer; el widget obedece las 4 líneas, `locked` y la marca; grupo RUN con «Reiniciar la run» (8b) | ✅ código (2026-11-14: `modules/InstanceTracker/wow/Page.lua`; puro `Settings.lines/isOn/needsReload` + `View.withLines`, specs; `check f2` gana «line bosses off» y «page it»); ✅ in-game (owner, 2026-11-14: `check f2` 19/19 y los 5 puntos del guion OK). Fix en la prueba: el contenido de `Craft.Tabs` no tenía rect (página en blanco) → paneles propios bajo la barra, FR-153 de Craft; `check f2` gana «page it painted». Craft v2.51.0 vendoreado (2026-11-14): FR-153 resuelto (vuelve `GetContentFrame`, apaño quitado) y FR-152 («PRONTO» como badge de la fila del sidebar); ✅ in-game 19/19. Elecciones del agente: grupo plegable propio con `Weave.tween` (Craft.Section no tiene hueco para el resumen y pone el chevron a la derecha); módulo apagado = no arrancan Tracker/widget/avisos/F1 y los `/qdt it…`, `new`, `auto`, `check` responden «está apagado»; aviso dorado «Se aplica al recargar la UI» junto al interruptor (el botón Recargar ya está arriba); «Reiniciar la run» pide un segundo clic en 4 s; las líneas apagadas valen en el modo completo (el compacto es su propia línea); interruptor de Inicio cableado y sincronizado con el de la página; pestaña Historial = «Muy pronto» hasta F6d. Desvío: el subrayado de la pestaña activa sale crema (Craft `line` usa `foreground`), el artboard lo pinta oro |
| F6d | IT › Historial: 3 Select de filtro + «Instancias última hora», tabla con scroll (filas fijas reutilizadas, 9 columnas, monedas), pie; `/qdt history` y botón «Historial» del toast abren aquí | ✅ código (2026-11-14: `modules/InstanceTracker/wow/HistoryTab.lua`; puro `History.columns/cells/footer` + specs; `UI.coinText` exportado; `check f2` gana «page history»); ✅ in-game (owner, 2026-11-14: `check f2` 20/20 con la ventana abierta, tabla como el artboard y el botón «Historial» del toast abre la pestaña; sin reportar aún: filtro sin coincidencias, scroll con muchas runs y la cuenta en el pie con la ventana estrecha). Elecciones del agente: filtros arrancan en Todas/Todos y no se guardan entre sesiones; fila de récord con lavado turquesa 8 % (`C.recordWash`); «adelantada» en turquesa, «primera» con «—»; oro 0 = «—»; sin runs → una línea muted («Aún no hay runs…» / «Ninguna run coincide…», no está en el artboard); «8/10» siempre oro (el artboard no pinta el 10/10); el botón «Historial» del toast es `outline` a la izquierda de «Compartir»; Inicio › «Historial de runs» abre esta pestaña; `/qdt history` ya no imprime en el chat. 1.ª prueba (owner, 2026-11-14): `check f2` 19/19 con la ventana cerrada («page history» 9 cols, 6/6) y la tabla igual que el artboard; con la ventana estrecha «Instancias última hora» pisaba el filtro Personaje → los selects encogen hasta un mínimo y, si no cabe, la cuenta baja al centro del pie (elección del agente, sin artboard) |
| F6e | Icono del minimapa (LibDataBroker-1.1 + LibDBIcon-1.0 + CallbackHandler-1.0 vendoreadas), clic = Inicio, mayús+clic = Historial; Ajustes generales con su interruptor | ✅ código (2026-11-14: `wow/Minimap.lua`, página «general» en `wow/MainWindow.lua`, `/qdt minimap`, `db.minimap` aditivo `{hide, minimapPos}`; `check f2` gana «minimap icon»). Diseño OK del owner (lienzo v58): patrón de SMRT (`docs/19-smrt-menu-minimapa.md`): tooltip propio (GameTooltip con nombre, Inter, panel navy, icono 48 px a la izquierda, título con `Brand.title()`), clic derecho = `Craft.Menu` (Instance Tracker, Historial de runs, Ajustes generales, Ocultar el icono); icono provisional de Blizzard `INV_Misc_PocketWatch_01`. ✅ in-game (owner, 2026-11-14): icono, tooltip, clics, menú y Ajustes generales OK. Fixes en la prueba: con EllesmereUIMinimap el botón vive en su desplegable (check f2 lo acepta, `9ff2436`); hover del menú en gris de Craft → lavado oro 8 % con un contexto de tema solo para menús (`Kit.menuCtx`, `bc65447`) |
| F6f | Vista previa del widget en «Qué enseña» (idea del owner, patrón de NF): pestañas de estado (En curso, Completada, Primera vez; `Craft.Tabs` default + `fill`) a la derecha y debajo el widget REAL prestado (`UI:Preview(host, state)`: re-parent centrado, recortado, sin arrastre/pings, datos de `Demo`, ajustes vivos); vuelve a su sitio en el OnHide del recuadro | ✅ código (2026-11-15: `Page.lua` `buildPreview`, `UI.lua` `UI:Preview`, tokens `preview*`; `check f2` gana «page preview»). Diseño OK del owner (lienzo v63, artboard «Resumen con vista previa»; v64: fondo del recuadro = `C.sidebar`, el «mundo» del lienzo no existe en el juego). 1.ª prueba (owner, 2026-11-15): pestañas en el gris de Craft → contexto de tema propio `Kit.tabsCtx` (`muted` = `C.track`) y artboard v65 con la pestaña activa como la pinta Craft (lavado blanco 4,5 % + borde 15 %, regla shadcn); el Detalle del hover salía vacío → en la vista previa el modo completo no toma el ratón (el compacto sí, para su lista). Elecciones del agente: Compacto no es pestaña (lo enseña su interruptor), sin pestaña Pausa (aplazada); con el módulo apagado el recuadro dice «está apagado». ⬜ in-game |

**Guion F6c (in-game, sin mazmorra):** `/reload` → `/qdt check f2` (esperado 18/18) → `/qdt` →
Instance Tracker. (1) Pestañas Resumen | Historial; el kicker cambia a «Instance Tracker / Historial».
(2) Plegar/desplegar «Qué enseña»: anima, el chevron gira (abajo ↔ derecha). (3) `/qdt it demo live` y
apagar Lista de jefes, Barra de tiempo, Barra de XP y Fila de totales una a una: el widget pierde esa
línea al momento; sale el punto oro y el pie «N ajustes cambiados»; el resumen dice «X de 4 líneas».
«Restablecer el widget ›» lo devuelve todo y el pie dice «Todos los ajustes con su valor por defecto».
(4) Bloquear posición: el widget no se arrastra. (5) Marca: elegir Estrella; clic derecho en un jefe
vivo pone la estrella (esto sí necesita mazmorra: va a la run de prueba). (6) Apagar el módulo: aviso
dorado; el interruptor de Inicio también se apaga; Recargar UI → no sale el widget y `/qdt it` dice
«está apagado»; volver a encender + recargar.

**Guion F6d (in-game, sin mazmorra):** `/reload` → `/qdt check f2` con la ventana abierta (esperado 20/20; «page history»
dice «9 cols, N/N rows, N saved»). (1) `/qdt history` abre la ventana en Instance Tracker › Historial;
el kicker dice «Instance Tracker / Historial». (2) Barra: Mazmorra · Dificultad · Personaje en
Todas/Todas/Todos; a la derecha «Instancias última hora N/10» con el número en oro. (3) Tabla: 9
columnas (Fecha … Grupo) alineadas con su cabecera; la fecha en arena («Hoy 19:42» / «Ayer …» /
«10 nov …»); la run de récord con fondo turquesa suave y «récord»; atrasadas «+m:ss» en coral; sin
terminar «—» y «sin terminar» apagados; oro con iconos de moneda; las runs viejas sin personaje «—».
(4) Elegir una mazmorra: la tabla y el pie («N runs · media · récord») se recalculan; elegir un
personaje sin runs de esa mazmorra → «Ninguna run coincide con estos filtros.». (5) Con más runs de
las que caben: la rueda desplaza solo las filas (cabecera y pie quietos). (6) `/qdt it alert toast` → botón «Historial» a la izquierda de «Compartir en grupo» abre
aquí. (7) Inicio › «Historial de runs» › Abrir → también.

**Guion F6e (in-game, sin mazmorra):** `/reload` → `/qdt check f2` (esperado 21/21; «minimap icon» dice «<textura>, shown …, setting true, parent …»; con EllesmereUIMinimap el botón vive en su desplegable de botones y puede salir «shown false»: es correcto). (1) Icono reloj de bolsillo en el borde del minimapa con el aro dorado; se arrastra por el borde y la posición sobrevive a `/reload`. (2) Ratón encima: tooltip navy con el reloj de 48 px a su izquierda, «Quantum» en mar y «Dungeon Tools» en oro, 4 líneas (Clic · Mayús+clic · Clic derecho · Arrastrar), letra Inter. (3) Clic = abre/cierra en Inicio; mayús+clic = IT › Historial. (4) Clic derecho = menú con Instance Tracker, Historial de runs, separador, Ajustes generales, Ocultar el icono; cada uno hace lo suyo. (5) Ajustes generales: grupo MINIMAPA con «Icono del minimapa», ayuda, `/qdt minimap` y el interruptor; apagarlo oculta el icono y sale el punto oro; `/qdt minimap` lo vuelve a mostrar y el interruptor se enciende solo. (6) «Ocultar el icono» del menú: lo mismo.

Decididos (owner, 2026-11-14): **«Novedades» = notas CORTAS escritas a mano** en
`core/NewsData.lua`, una frase por cambio («Título (etiqueta): detalle»), en **español e inglés**
(si falta uno sale el otro); patrón de Naowh Forever. El **CHANGELOG sigue completo** (va a
CurseForge) y no se lee en el juego. **Al cerrar cada versión: entrada del CHANGELOG + sus líneas en
NewsData** (solo lo que nota un jugador; nada de libs ni autopruebas). Diseño OK del owner (lienzo
v61, artboard «Novedades»: una tarjeta plegable por versión, la más nueva abierta; filas título +
detalle). ✅ código (2026-11-14): `core/News.lua` (puro + specs, que también comprueban que NewsData
tenga las mismas notas en los dos idiomas), página en `wow/MainWindow.lua` (tarjetas con
`Weave.tween`); `check f2` gana «page news». Descartado el primer intento (generar la página desde
el CHANGELOG, `895ca62`): demasiado texto. **«Buscar ajustes» APLAZADO** (~9 opciones en 2 páginas
no lo justifican; se retoma con Minimap Lens u otro módulo; sin caja en la ventana hasta entonces).
Fila activa del sidebar (owner, 2026-11-14): el diseño se alinea con shadcn (FR-154 de Craft cerrado
sin adopción): solo el lavado, con el margen del grupo, sin barra oro; lienzo v62 (de paso, fuera la
caja «Buscar ajustes» de los artboards). Sin apaño en el código.

**Guion Novedades + barra (in-game, sin mazmorra)** — ✅ (owner, 2026-11-14: `check f2` 22/22 y los 7 puntos OK, inglés incluido): `/reload` → `/qdt check f2` (esperado 22/22;
«page news» dice «1 versions, 10/10 items»). (1) `/qdt` → la fila activa solo con el lavado oro, sin barra.
(2) Novedades: una tarjeta «En desarrollo · SIN PUBLICAR · 10 cambios» abierta, chevron oro hacia
abajo. (3) Filas: título en crema (y «/qdt» como etiqueta en «Ventana principal»), detalle en gris
pequeño, partido sin cortarse. (4) Clic en la cabecera: se pliega animada, chevron gris a la derecha;
otro clic la abre. Ratón encima: lavado oro. (5) Estrechar la ventana: el detalle se re-parte y el
scroll llega al final. (6) Con el cliente en inglés (o sin acceso: lo vemos en la próxima sesión) las
notas salen en inglés.

Abierto aún: «Pug ×4» del artboard — hoy
la columna Grupo pinta los nombres (sin reino) porque no hay forma fiable de distinguir un pug.

**Entregado (v1.0)** → release del hito.

## Pruebas in-game pendientes (se hacen TODAS juntas en una run)

Las mazmorras de Forever son largas: no se prueba cambio a cambio (owner, 2026-11-13). Cada
cambio de lógica de run añade aquí su caso; se tachan en la run de prueba.

- [ ] **Marca del ajuste (F6c)**: con «Marca al clic derecho» en Estrella, clic derecho en un jefe vivo
  de la lista → le pone la estrella (y otro clic se la quita).
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
- [ ] Fuera más de 90 min, o más de 20 min con la run ya completada (o con otra dificultad) → al volver, run nueva.
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
- [ ] **Instancias/hora (F5a)**: entrar en 2 mazmorras distintas → Detalle «INSTANCIAS EN LA ÚLTIMA
  HORA · 2/10», «Siguiente hueco en» ≈ 60 min menos lo pasado. Salir y volver a la MISMA copia (o
  `/reload` dentro) → sigue 2/10. Con un alt → la cuenta sigue sumando. Reset y volver a entrar → 3/10.
- [ ] **Avisos (F5b)**: ✅ vistas previas OK in-game (2026-11-14, animadas, sin contorno). Falta solo la run real. Sin mazmorra, `/qdt it alert cap` y `/qdt it alert near` → cotejar con el
  artboard Avisos (borde rojo / ámbar, icono triángulo, «12:40» en crema). En la run real: al
  entrar en la 8.ª instancia de la hora sale la franja; en la 10.ª, el rojo.
- [ ] **Toast (F5c)**: ✅ vista previa OK in-game (2026-11-14). Falta: Compartir en grupo y que salga solo al acabar una run real. `/qdt it alert toast` → «Run completada» + NUEVO RÉCORD, 29:51 y −1:49 en
  turquesa, Muertes 3 (rojo), XP +41,220, Oro con monedas, Rep. +875, botón «Compartir en grupo».
  En grupo: Compartir → en el chat del grupo «QDT: … 29:51 · nuevo récord -1:49 · 3 muertes · …».
  Solo: «no estás en grupo». Al matar el último jefe de una run real sale solo.
- [ ] **Trash (F4c)**: primera run limpia de una mazmorra → Detalle «Trash · N bichos» (sin %); al
  terminarla se aprende el total; la siguiente run de esa mazmorra → «N/T · P %». Cotejar a ojo que
  N ≈ bichos matados y que los jefes NO suman (la kill del jefe se fusiona con su ENCOUNTER_END en
  3 s). Verificar que `PARTY_KILL` llega en Forever también cuando el golpe final es de otro del grupo.
  `/qdt it demo live` → «Trash 34/52 · 65 %».
- [ ] **Tiempo fuera (F4c)**: morir, correr al cadáver y volver → Detalle «Fuera de la mazmorra m:ss»
  en atenuado; sin salir, la fila no aparece. Demo live → «3:12».
- [ ] **encounterID (punto 8e)**: **sin run dedicada: solo cuando toque esa mazmorra.** Ya medido en las runs del 2026-11-13: Deadmines emite los IDs nuevos 2741-2747 (no los clásicos 161-167 de FDJ) y Excavation Site 3480-3482; Miner Johnson no salió. Anotar qué ID llega en `ENCOUNTER_END` en Gnomeregan, Thaurissan, Thalnos, Lorgus Jett y Rend (el de NF o el alternativo de FDJ), y si los jefes de Dire Maul (Pusillin, Tsu'zee, Hel'nurath), Miner Johnson, Skul, Stonespine y Atal'alarion emiten alguno.

## Siguiente (handoff 2026-11-13, sesión F4b)

> **Sesión F5 (2026-11-14, cierre):** F5 hecha en código (`9b6e7a4`, `e35bb2a`) y desplegada.
> ✅ Vistas previas OK in-game (owner, 2026-11-14) tras dos ajustes: sin contorno en textos sobre fondo y
> todo componente animado (Weave.tween, memoria `feedback-componentes-animados`). Panel hover del compacto
> también animado (motionFast/motionSlide del tema). Toast rediseñado con ui-critic (docs/17) y lienzo
> v46: «Oro Forever» (botón oro, NUEVO RÉCORD oro relleno), delta 16 px + «vs récord», columnas
> 1/1/1.5/1, ritmo 4/14/14; BettoGeo mínimo Medium en todo (lienzo incluido); artboard «Ping» = solo B
> sin tooltip. Falta solo ver el toast nuevo in-game (`/qdt it alert toast`). Después: **F4c**
> (% de trash con los totales de FDJ + tiempo fuera) y luego **F6**. Nada a medias.

> **Sesión FDJ (2026-11-13, cierre):** inventario de ForeverDungeonJournal y cotejo de encounterID en
> `docs/16` §Inventario y §Cotejo; punto abierto 8 decidido: (a) retomar 90/20 min y (e) IDs alternativos
> de FDJ en el generador, ambos ✅ en código; (b) reset de la run como botón en los ajustes, en F6; (c)+(d)
> en la fase nueva **F4c** (tras F5). Nada a medias. Sin desplegar a AddOns (va con la run de pruebas).

Estado: F4 hecha en código y alineada con el lienzo (v35). Decisiones de diseño de hoy: sin etiqueta de
instancias en el widget (solo tooltip + aviso 10/10), fila de totales a la DERECHA con 20 px entre oro y
reputación (opción B), lista de jefes con `bossTop` 4, monedas 2/5 px, tooltip en BettoGeo Medium, fuente al
tamaño del diseño y geometría ×1000/932. Regla: diseño antes que código; colores solo de la paleta B.

Pendiente, en este orden:
1. **Limpieza del lienzo** (pedido del owner): en «Paleta» dejar SOLO la propuesta B elegida (quitar A y C
   y el selector); revisar «Primary del tema Craft» (dejar solo la elegida: oro con texto navy); borrar el
   artboard de comparación «Fila de totales: A / B / C» (ya decidido B); repasar que todos los artboards
   usan la paleta B (hecho en v31) y que las notas del lienzo no mencionan cosas quitadas. Diseño solo.
   ✅ Hecho (lienzo v36): Paleta solo B (sin selector ni etiqueta de instancias), Primary solo «Oro Forever»
   (artboard 560×640), «Totales» borrado, nota n1 corregida (totales a la derecha, 20 px).
   **Después, cotejo diseño ↔ código** (pedido del owner): cada artboard del widget (En curso, Completada,
   Primera vez, Compacto, Pausa, Detalle) contra `Style.lua` (HEX, SIZE, FONT) y `UI.lua`/`View.lua`:
   colores, tamaños de fuente, márgenes, orden y alineación de filas, textos/Locale. Lista de diferencias →
   el owner decide cuál manda en cada una; ninguna se arregla sin su OK. Recordar que el código escala la
   geometría ×1000/932 a propósito (no es diferencia). Delegable a un subagente que escriba la tabla en docs/.
2. Recortes con «…» de nombres de jefe/raro y de la mazmorra en la cabecera (ui-critic, docs/14 §2 y §5) y
   tokens para los márgenes de 2 px sueltos de UI.lua (§4). Código, sin cambio visual.
   ✅ Hecho: `fitText` en UI.lua (corta solo el nombre, nunca tiempo/delta/tag) + `S.xpTop`/`S.totalsTop`.
   Los gaps 8 (filas de jefe) y 10 (fila del reloj) siguen literales: tokenizarlos los escalaría ×1000/932
   (8→9, 10→11) = cambio visual; decidir en el cotejo. Pendiente prueba in-game con nombre largo.
2b. **Cotejo resuelto por el owner** (docs/15, 2026-11-13): manda el DISEÑO en Main, Compacto (incluida la
   posición del panel), Detalle y las menores; RARO a 10 px en el lienzo (v37); PRIMERA VEZ en semibold
   (= el fichero Medium: el lienzo pinta 100–600 con un solo fichero y no hay BettoGeo SemiBold, así que
   las «cifras en negrita» del diseño ya coinciden con el código).
   ✅ Hecho en código: bossTop 10, monedas 10, tachado 1 px, PRIMERA VEZ medium, `·` de la info con
   10 px a cada lado (texturas espaciadoras), compacto con gap 10 entre piezas, muertes del panel en
   muted, `—` para jefe sin hora, etiquetas del Detalle en sand y sin líneas entre secciones, delta con
   `−` (U+2212, BettoGeo lo trae).
   Pendiente (siguiente sesión, en este orden):
   a. **Pausa: APLAZADA** (owner, 2026-11-13): el diseño vale, pero no está claro que se use en la
      práctica; se analiza cuando el plan llegue a esa parte. No programar antes.
   b. ✅ **Panel propio del compacto** (2026-11-13) en lugar de Craft.Tooltip: 260 px, a la derecha bajo
      la barra a 10 px, fondo sólido panel, padding 10×12, gap 6, jefes 12 px, cabecera/pie/raros 11 px,
      badge RARO con borde, separadores hairline, pie «Récord 31:40 · hace N días» (`v.ref.age`).
      Pendiente de prueba in-game.
   c. ✅ Completada: «· N nivel(es)» (`Run.levels`, sumado en `T:SampleXP` al subir de nivel).
   d. Detalle: medidas del panel (300 px, padding 12, gap 10/4, títulos 11) → **FR-150 a Craft**
      (`craft/docs/requests/FR-150-tooltip-medidas-por-config.md`). ✅ Craft 2.49.0 vendoreado y opciones
      aplicadas en `attachDetail` (2026-11-13); pendiente de prueba in-game.
      Re-vendorear cuando salga. `≈` NO está en BettoGeo: se queda `~` (owner OK). La línea
      «Pasa el ratón para ver el detalle» es nota del lienzo (owner): NO va en el widget.
   e. El letter-spacing del diseño no se puede hacer con FontStrings: queda fuera.
3. F5 (abajo).

## Puntos abiertos

| # | Punto | Quién decide | Recomendación | Estado |
|---|-------|--------------|---------------|--------|
| 1 | ¿Probar el v0.1 nativo (F1) antes de reescribir la UI, o saltar directo a F2? | **owner** | Probarlo: el modelo y los eventos no cambian con la UI, y medir `isKilled`/zoneUID ahora evita rehacer F3 | ✅ **No** (2026-11-12): directo a Craft; el checklist del v0.1 pasa a F2 |
| 2 | Rama de trabajo: trunk-based o `dev` (AGENTS.md §8 PENDIENTE) | **owner** | trunk-based en `main` (proyecto de una persona) + primer commit del v0.1 antes de F2 | ✅ **trunk-based en `main`** (2026-11-12) |
| 3 | Tope del historial (20 hoy, 80 en NF) | **owner** | 100 runs + récords aparte (los récords no caducan) | ✅ **100** (2026-11-12) |
| 4 | Resolución del reloj: `time()` (1 s, sobrevive a relog) o `GetTime()` (preciso, se reinicia) | agente | `time()` como ancla persistida + `GetTime()` solo para pintar fracciones; los splits se guardan en segundos enteros | ⬜ |
| 6 | Pausa/retomada: la copia sale del castGUID (✅ medido); ¿qué hacer mientras aún no hay ningún hechizo lanzado en la copia? | **owner** | Respaldo hasta el primer hechizo: retomar si se cumple TODO: misma instanceID+dificultad, sin mensaje de reset entre medias, fuera < 30 min y el lockout no tiene menos muertos que la run (si los tiene, es una copia nueva). Si no, run nueva. `/qdt new` sigue como salida manual | ✅ **Lo propuesto** (owner, 2026-11-12). Implementado 2026-11-13 (`Run:pause/resume/canResume`, reset por `CHAT_MSG_SYSTEM`); el chequeo del lockout con menos muertos sigue en `lockoutWasReset` |
| 7 | Idea del owner (2026-11-13): clic en el nombre de un jefe → ping (sistema de pings de WoW: «atacar» + localizarlo) | **owner** (alcance) | Viable solo como botón seguro con macro `/target <nombre>` + `/ping attack` + `/targetlasttarget` (owner: así no pierdes tu objetivo; ojo, sin objetivo previo puede seleccionar uno antiguo; un ping necesita unidad: sin posición en mazmorra no se puede pingear a distancia); solo funciona si el jefe está a la vista, y las filas seguras no se crean en combate. Forever SÍ tiene pings (owner los usa siempre, 2026-11-13); ✅ **`/ping [@target] attack` funciona en macro** (owner, in-game 2026-11-13: ping sobre el jefe y recupera el objetivo). ✅ **Diseño cerrado** (owner, 2026-11-13, artboard «Ping» variante **B**): al pasar el ratón por un jefe/rare VIVO, mira turquesa (Lucide crosshair, `C.turquoise`) a la izquierda del nombre + cursor **espada** (`SetCursor("Interface\Cursor\Attack")`, `ResetCursor()` al salir) + tooltip pequeño «nombre / Clic: ping de ataque»; muertos sin respuesta. Implementación: `SecureActionButtonTemplate` `type=macro` con `macrotext` `/target <nombre>`·`/ping [@target] attack`·`/targetlasttarget`, parentado a UIParent y posicionado por coordenadas SOLO fuera de combate (si no, las filas quedan implícitamente protegidas y su `SetPoint` en combate da ADDON_ACTION_BLOCKED); en combate no tocar atributos ni anclas, reencolar en `PLAYER_REGEN_ENABLED`. Comprobar que la mira existe en el atlas de Craft. | ✅ **Código** (2026-11-13): `crosshair` está en el atlas de Craft 2.49; `View.pingMacro` + `alive` por fila (tests), botones en `UI.lua` §Boss ping (pool sobre UIParent, `UI:SyncPings` tras cada render, al soltar el arrastre y en `PLAYER_REGEN_ENABLED`). Solo en el modo completo (el compacto no tiene filas). Límites conocidos: en combate los botones no siguen a la fila si esta se mueve, y un jefe que muere en combate sigue pingeable por clic (sin mira ni cursor) hasta salir; si `/target` no encuentra al jefe, el ping cae sobre el objetivo que ya tenías — **confirmado in-game** (owner, 2026-11-13: «pinea a cualquiera»). Macro corregida: `/cleartarget` · `/targetexact <nombre>` · `/ping [@target,exists,harm,nodead] attack` · `/targetlasttarget`. Por probar: que fuera de vista no pingea nada y que recupera el objetivo (con y sin jefe a la vista). **Cambio del owner (2026-11-13):** fuera el tooltip del hover (estorbaba; quedan mira + cursor); **clic derecho = marca de banda** configurable (`/qdt it mark <1-8|nombre>`, por defecto calavera; `/tm` alterna: si el jefe ya la lleva, se la quita). ⬜ prueba in-game |
| 5 | Si F1 dice que no existe el límite 10/hora en Forever | **owner** | quitar el contador del widget y dejar solo la cuenta informativa en el tooltip | ⬜ |
| 8 | Ideas sacadas del inventario de ForeverDungeonJournal (`docs/16-jefes-de-quest.md` §Inventario, 2026-11-13): **(a)** conservar la run si se vuelve antes de 90 min (20 min si el jefe final ya murió) en vez del límite de 30 min del punto 6; **(b)** botón de reset manual de la run en el widget (hoy solo existe `/qdt new`); **(c)** % de trash: necesita el total de bichos de cada mazmorra (FDJ trae `runLogTrashTotal`); **(d)** tiempo fuera de la mazmorra (vueltas al cadáver) en el Detalle; **(e)** contrastar nuestros `ENCOUNTER_END` observados con su tabla encounterID→jefe de 252 entradas (`Data/RunLogEncounters.lua`, sacada de la build 1.60.1.70862, DBM y LittleWigs). Sus botones de objetivo de jefe ya los cubre el punto 7. | **owner** (alcance: qué entra en M1 y qué va a un hito posterior) | (e) ya, como tarea de datos (sin código, con subagente); (a) dentro de F3, porque solo cambia las constantes de la regla de retomada; (b) dentro de F6, junto a los ajustes; (c) y (d) a un hito posterior: (c) necesita datos que no tenemos y (d) amplía el modelo de la run | ✅ **Decidido (owner, 2026-11-13):** (e) sí — ✅ cotejo hecho (`docs/16` §Cotejo: 189/226 coinciden, 8 difieren, 29 solo en QDT; ✅ IDs alternativos de FDJ añadidos vía `scripts/gen-dungeons.lua` (2.º argumento): 46 ids; confirmaciones in-game pendientes); (a) sí, en F3 (90 min / 20 min tras el jefe final; sustituye al «< 30 min» del punto 6) — ✅ código (`Run:canResume(info, window, finishedWindow)` + `RESUME_WINDOW*` en `wow/Tracker.lua`, spec en `Run_spec.lua`); (b) sí, como botón en la ventana de ajustes (F6), no en el widget; (c) sí, usando el total de trash que trae FDJ (solo los números, sin copiar código; citar la fuente), en **F4c**; (d) sí, tiempo fuera de la mazmorra en el modelo de la run + Detalle, en **F4c**. ⬜ código |

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
