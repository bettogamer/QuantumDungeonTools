# 10 — NaowhForever Instance Tracker: inventario de funcionalidades para portar

> Fuente: lectura de terceros (READ-ONLY, **no copiar código**, solo estudiar). Fecha: 2026-11-12.
> Todas las referencias `archivo:línea` son de ficheros abiertos íntegros en esta investigación.

## 0. Hallazgo clave (leer primero)

**El Instance Tracker de Naowh NO es un tracker de jefes/splits/cronómetro de run tipo M+.**
Es un clon del addon *Nova Instance Tracker*: registra **visitas** a mazmorra/banda (tiempo dentro,
oro looteado, XP, muertes, reputación, grupo) y, sobre todo, cuenta el **límite horario de la cuenta
(10 instancias nuevas por hora)**. NO hay: lista de jefes, X/Y jefes, splits por jefe, récords/mejor
tiempo, forces %, ni uso de `ENCOUNTER_END`/`BOSS_KILL`/`GetInstanceLockTimeRemaining*`
(verificado: el `.lua` entero no los referencia). El "cronómetro" es un contador de tiempo de la visita.

Consecuencia para QDT: de Naowh solo se puede portar **XP por visita, tiempo de visita con
gestión de pausas, historial, muertes y la mecánica de "misma copia"**. Jefes + splits +
récords (el corazón del módulo QDT) hay que diseñarlos desde cero (ver doc 00 y el hallazgo
de `GetInstanceLockTimeRemainingEncounter` en el CLAUDE.md global).

## 1. Ubicación y ficheros

Raíz: `F:\Games\World of Warcraft\_forever_\Interface\AddOns\NaowhForever_Utilities\InstanceTracker\`
(addon host `NaowhForever_Utilities`, incluido desde `Utilities.xml`; el addon principal es
`NaowhForever`; `OLD_ADDON = NaowhForever_InstanceTracker` es la copia antigua standalone,
`InstanceTracker.lua:45-46`; si está activa, el módulo se desactiva: `:58-60`).

| Fichero | Contenido |
|---|---|
| `InstanceTracker.xml:3-6` | orden de carga: lógica, Pages, Window, SettingsPage |
| `InstanceTracker.lua` (1832 líneas) | ajustes, visitas, cuenta horaria, protocolo Nova NIT, panel cronómetro, eventos |
| `UI/Pages.lua` | páginas "This Hour" e "History" |
| `UI/Window.lua` | ventana propia 860x640 con 2 pestañas (`Window.lua:6,15-18`) |
| `UI/SettingsPage.lua` | página de ajustes en tarjetas |
| `README.md` | decisiones de diseño (útil, explica el porqué) |
| Fuera del módulo | `NaowhForever/Shared/UI/Tracker.lua:298` (`Parts.TrackerPanel`, el marco del cronómetro), `Core/Options/Modules.lua:53-59` (registro; slash `command="instance"`), `Core/Features.lua:275` (`enabled=false` por defecto) |

Dependencias de framework propio de Naowh (NO portables, hay que rehacer con widgets Blizzard):
`ns.UI.ModuleSettings`, `ns.Shared.CharacterData`, `ns.Shared.Parts.*`, `ns.Font`, `ns.Color`, `ns.L`,
`ns.Print`, `UI.AttachMover` (modo desbloqueo HUD).

## 2. Funcionalidades visibles al usuario

### 2.1 Cronómetro de visita ("Run Timer", panel HUD)
- Marco `TrackerPanel` (titulo = nombre instancia + dificultad, `InstanceTracker.lua:1544`). 3 líneas
  (`NewBody`, `:1517-1527`): tiempo (fuente 16, línea 20px) · `oro   XP` (fuente 12) · `Account this hour: N of 10   mm:ss` (`:1529-1538`).
- Tick cada 1 s con `C_Timer.NewTicker` (`:1597`); `Tick` solo repinta tiempo y línea horaria (`:1558-1566`).
- Visible solo con `showFrame` on, run abierta y no cerrada con la X (`FrameWanted`, `:1470-1477`;
  `dismissedAt` por `open.entered`). En modo desbloqueo se muestra siempre y es movible
  (`:1472,1817-1824`). Posición por defecto TOP/TOP 0,-180 (`:40,1578`); se guarda en ajuste `pos` (`:1488-1490`).
- Clic en el título abre la ventana; engranaje abre ajustes (`:1570-1576`).
- Fuera de instancia (con modo desbloqueo): título "Instance", `0:00`, `0 XP` (`:1548-1550`).
- **Cálculo del tiempo** `Elapsed` (`:200-208`): `now - entered - skipped`, más el hueco abierto
  (`seen`). `skipped` = tiempo fuera (logout, reload, fantasma/cementerio fuera de la instancia).
  Usa `time()` (reloj de pared), no `GetTime()`: sobrevive a logout. Formato `m:ss` / `h:mm:ss` (`FormatDuration`, `:190-198`).

### 2.2 XP ganada en la visita
- `NoteXP` (`:307-325`): en cada `PLAYER_XP_UPDATE`/`PLAYER_LEVEL_UP` (`:1768-1779`) suma delta de
  `UnitXP("player")` contra `open.lastXP`; si baja (subida de nivel) suma `lastMax - lastXP + xp`.
  Baseline al abrir/reanudar (`NoteXP(true)`, `:1394,1421`). Descarta si `UnitXP/UnitXPMax` son secretos o no-número.
- Se muestra en HUD, historial, y resumen de salida. Extra: `leaveRunsToLevel` estima "unas N más hasta
  el siguiente nivel" = `ceil((lastMax-lastXP)/xp)` (`:474-478`); `leaveAverage` = XP media de visitas
  previas a esa instancia (`:453-465`); `leaveRunsLevel` = nº de visitas a este nivel (`:466-473`).

### 2.3 Oro looteado
- `CHAT_MSG_MONEY` → `LootedCopper` (`:230-244`): parsea el texto con patrones derivados de las globales
  localizadas `GOLD_AMOUNT/SILVER_AMOUNT/COPPER_AMOUNT` (`:226-228`). Se muestra con
  `C_CurrencyInfo.GetCoinTextureString` o texto plano `Ng Ns Nc` (`:210-224`). No cuenta reparaciones ni ventas (`Pages.lua:200`).

### 2.4 Muertes
- `PLAYER_DEAD` → `open.deaths += 1` (`:1741-1743`). Sale en historial (muted, solo si >0, `Pages.lua:120-123`) y resumen.

### 2.5 Reputación
- `CHAT_MSG_COMBAT_FACTION_CHANGE` + patrón de `FACTION_STANDING_INCREASED` (`NoteRep`, `:336-349`);
  acumula por facción en `open.rep[faction]`. Mostrado en historial bajo la visita (`Pages.lua:127-137`).
  **Frágil**: depende del texto del global en Forever (verificar in-game).

### 2.6 Historial
- Pestaña "History" (`Pages.lua:191-235`): fila "In progress" de la run abierta + últimas visitas
  (`PAGE_RUNS=40` mostradas, `MAX_RUNS=80` guardadas por personaje, `:30,1604,640-642`).
  Línea: `mm/dd HH:MM  <nombre clase-color>  <instancia (dificultad)>  <duración>  <oro>  <xp> XP  [N deaths]`
  (`RunLine`, `Pages.lua:112-125`). Botón "Clear History" con confirmación (`:202-207`).
  Con `trackAlts` mezcla runs de todos los personajes ordenadas por salida (`:1649-1667`).
- Se guarda una visita solo si "vale la pena": >=1 s, o loot/xp/muertes/rep (`CloseRun`, `:667-668`).
- **Continuar visita**: volver a la misma copia (mismo grupo, <1 h, sin reset) reanuda la visita
  anterior sin contar el tiempo fuera (`TakeSameCopy` `:1295-1330`, `TakeCountBack` `:1246-1293`,
  `CanResume` `:880-885`, `GroupsDiffer` `:856-878`).

### 2.7 Límite horario de cuenta (10/hora) — pestaña "This Hour"
- `HOURLY_CAP=10`, `HOUR=3600` (`:31-32`). Lista `hour[]` por personaje; la cuenta suma todos los
  personajes (`AccountHour`, `:744-768`; `HourSnapshot` cacheado, `:781-796`). Línea
  "Account this hour: N of 10  next frees in mm:ss", coloreada WARN/CAP cuando quedan <= `hourlyWarn`
  (`Pages.lua:149-156`). Aviso por chat al acercarse/llegar al tope (`WarnHour`, `:798-820`), con
  `C_Timer.After` programado al vencimiento de la entrada más antigua (`ScheduleExpiry`, `:826-842`).
- Lista de entradas con "frees in" (`Pages.lua:157-167`) + sección "CHARACTERS": nivel, reino, XP/XPmax,
  XP en descanso, % durabilidad (`:169-188`; `DurabilityPct` `InstanceTracker.lua:131-145`).
- Entrar en una copia ya contada (login/reload, o misma copia) no suma (`CountsEntry`, `:851-854`; `NoteInstanceEntry`, `:913-933`).
- **Relevancia QDT: baja** (la mecánica de 10/hora existía en retail y no está confirmada en Forever;
  decisión del owner si se porta).

### 2.8 Resumen al salir ("When You Leave")
- `AnnounceLeave` (`:550-562`): frase `Left <Instancia (dif)>. <hechos>.` con hechos opcionales: tiempo, XP, oro,
  muertes, reputación, XP media, runs en este nivel, runs hasta siguiente nivel (`LeaveFacts`, `:435-480`).
- Destino: tu chat o grupo (PARTY/INSTANCE_CHAT/RAID solo con `leavePrintRaid`), troceado a 255 chars
  (`:433,527-548,506-525`, `SendLine` con `pcall` `:499-504`). Opciones "Skip if nothing happened", "Include raids".

### 2.9 Reset de instancia / protocolo Nova (NIT)
- Detecta mensajes `CHAT_MSG_SYSTEM` de reset (patrones de `INSTANCE_RESET_*`, `:1091-1120`), y siendo líder
  lo publica en chat de grupo y por addon-message prefijo `NIT` con LibSerialize+LibDeflate (`:935-1079,1129-1163`);
  recibe los de otros (`OnNovaReset`, `:1209-1220`). **No relevante para QDT** (interop con otro addon; requiere libs).

### 2.10 Chat al entrar
- `enterChat`: "Entered X." + "Last visit: dur, looted oro" (`AnnounceEnter`, `:367-375`) / "Resumed X." (`:362-365`).

## 3. Máquina de estados

| Estado | Condición | Efecto |
|---|---|---|
| Fuera | `IsInInstance` no party/raid (`CurrentInstance` `:246-256`) | cierra run (anuncia salida) salvo fantasma/muerto o secreto (`KeepsVisit` `:887-889`, `SyncZone` `:1429-1446`) |
| Dentro/en curso | party o raid | `BeginRun` (`:1354-1427`): continúa si `SamePlace` (nombre+dificultad+mapID, `:265-269`), reanuda copia previa, o abre nueva |
| Fantasma/muerto fuera | `UnitIsDeadOrGhost` | visita abierta; `seen` marca el inicio del hueco (`:1436`); `PLAYER_ALIVE/UNGHOST` cierra si ya fuera (`:1744-1749`) |
| Cerrada | salir | guarda en `runs[]` (máx. 80) |
| Login/reload | `PLAYER_ENTERING_WORLD(login,reload)` | `announce=false`; `PLAYER_LOGOUT` marca `seen` (`:1726-1732`) |

Detección de "misma copia" (relevante si se quiere distinguir resets): GUID de criatura/objeto/cast
`type-0-server-instanceID-zoneUID-id-spawn`; el `zoneUID` identifica la copia (`CopyParts` `:902-910`),
leído de target/mouseover/nameplates/casts (`ReadZone` `:1454-1468`, eventos `ZONE_EVENTS` `:287-290`,
que se desregistran al leerla `:1714-1718`). Usa nameplates: en 12.1.5 `GetCenter` lanza, pero aquí solo se lee `plate.namePlateUnitToken`/`UnitGUID` (sin medir).

## 4. Opciones / config (`InstanceTrackerSettings`, `:7-27`; UI `SettingsPage.lua`)

Todas por defecto off salvo `leaveWhere="self"`, `hourlyWarn=1`: `enabled` (módulo, también off por defecto `Features.lua:275`),
`showFrame` (cronómetro), `enterChat`, `resetChat`, `leaveChat`, `leaveWhere` (self/group), `leaveTime/XP/Gold/Deaths/Rep/Average/RunsLevel/RunsToLevel/Activity/Raids`,
`leavePrintRaid`, `trackAlts`, `hourlyWarn` (1-5, `SettingsPage.lua:68`), `pos` (posición). Tarjetas: This Hour, Run Timer, Chat on Enter, Track Alts, When You Leave, When You Reset (`SettingsPage.lua:64-118`).
**Comandos**: ninguno propio en el módulo; el registro genérico (`Modules.lua:53-56`) crea un slash `command="instance"` bajo `/naowh`, `/nao`, `/nf` (`Commands.lua:125-127,186-191`) que alterna la ventana (`ToggleInstanceTrackerWindow`, `Window.lua:100-102`). No se ha abierto `Commands.lua` completo; confirmar sintaxis exacta antes de citarla.

## 5. UI (layout)

- **Ventana** 860x640, pestañas "This Hour"/"History" (ancho 260), scroll "slim", nota en footer "N of 10 on this account" (`Window.lua:6-87`). Filas de 20 px, fuente 12 (`Pages.lua:6-8`); colores `T.fg`, "muted" para secundarios, WARN/CAP (rojo) para el tope (`InstanceTracker.lua:48-49`). Redibujo diferido con `C_Timer.After(0)` (`Window.lua:55-59`).
- **Panel cronómetro**: ver 2.1. Total `BODY_H = 20+2+16+1+16` (`:42`).
- No hay barras, ni colores por split: es texto puro.

## 6. Datos guardados

Cuenta (SavedVariables de Naowh vía `ns.AccountSettings()[ "instanceTrackerChars" ]`, `:66,75-79`), clave = `UnitGUID` del jugador (`Player-...`, `:67,81-88`):

- Fila de personaje: `name, realm ("Reino-Facción"), class, level, xp, xpMax, rested, durability, seen` (`:147-179`).
- `open` (visita en curso): `name, class, level, instance, mapID, kind (party/raid), difficulty, entered, skipped, seen, loot, xp, deaths, rep{faccion=n}, group{{name}}, copy (zoneUID), lastXP, lastMax, reentry` (`:1405-1409`, `:1383-1391`).
- `runs[]` (más reciente primero, tope 80): `name, class, instance, mapID, kind, difficulty, entered, left, level, loot, xp, deaths, rep, group` (+ `skipped/copy/reentry` transitorios) (`:671-678`).
- `hour[]`: `{at, name, map}` (`:928`); `live{[mapID:dif]={name,at,copy}}` copias vivas (`:690-695,926`); `hourNoted` ("cap"/"close").
- Ajustes del módulo en `instanceTracker` (el blob antiguo por nombre se ignora, README:21-22).
- Para QDT: el esquema propio (20 runs, per-char o per-cuenta) es más simple; ver doc 00 §6.

## 7. Secret values / pcall (patrón del addon)

Helper `Secret(v)` = `issecretvalue and issecretvalue(v)` (`:62-64`), aplicado ANTES de cualquier test sobre:
`UnitGUID` (`:70-71`), `GetRealmName/UnitFactionGroup` (`:98-101`), nombres (`:106`), `GetInventoryItemDurability` (`:138`), `UnitLevel/UnitClass/UnitXP/UnitXPMax/GetXPExhaustion` (`:127,151-159,311`), `IsInInstance/GetInstanceInfo` (devuelve estado "secret" y no cambia de zona, `:248-251,1432`), `UnitIsDeadOrGhost` (nil = mantener visita, `:261`), `IsInGroup/IsInRaid`, `UnitIsUnit`, textos de chat (`:231,338`), `InChatMessagingLockdown` (secreto = bloqueado, `:493-497`), `IsAddOnLoaded` (`:1140`), args de `CHAT_MSG_ADDON` (`:1210-1211`), GUIDs (`PlainGuid` añade `canaccessvalue`, `:895-900`). `pcall` solo en envíos (`SendChatMessage` `:501`, `SendAddonMessage` `:1132`). Política general: ante secreto, **conservar el estado previo** en vez de actuar.
Es coherente con la regla global de ORDEN (`issecretvalue` primero) y es un buen modelo a imitar.

## 8. Riesgos y dependencias de retail / Forever

1. **No hay jefes ni splits** (§0): el port real es mínimo; el resto es diseño nuevo.
2. **Cuenta de 10/hora**: mecánica retail (límite de instancias/hora); no verificada en Forever. Omitir salvo decisión.
3. Nombres: en Forever `UnitName` = nombre corto y `UnitFullName` el completo; hay que quitar el `-Reino` (README:23-25; `BareName` `:105-110`).
4. Parsing de textos del chat (`GOLD_AMOUNT`, `FACTION_STANDING_INCREASED`, `INSTANCE_RESET_*`): dependen de globales localizadas; comprobar que existen en Forever.
5. `C_ChatInfo.InChatMessagingLockdown`, `Enum.SendChatMessageResult`, `canaccessvalue`, `C_AddOns.*`: APIs 12.x; comprobar existencia (el código ya guarda algunas con `and`).
6. "Misma copia" por zoneUID: el formato de GUID de Forever no está verificado aquí (README lo describe, no confirma Forever). Nota global QDT: dentro de mazmorras no hay posición/uiMap, pero esto usa solo GUIDs: probablemente válido.
7. Protocolo NIT: requiere LibSerialize/LibDeflate/AceComm; fuera de alcance.
8. Sin eventos de jefe: para jefes QDT debe usar `ENCOUNTER_END`/`BOSS_KILL`/`GetInstanceLockTimeRemainingEncounter` (ya decidido en AGENTS.md §1), no Naowh.
9. Timer con `time()` (segundos enteros, sobrevive a reload) vs `GetTime()`: para splits precisos QDT debería decidir; Naowh solo tiene resolución de 1 s.

## 9. Candidatos a portar (propuesta, sin decidir)

Alto valor: modelo `Elapsed` con `skipped/seen` (cronómetro que sobrevive a reload/cementerio); `NoteXP` con salto de nivel; guardas de secret (`Secret`, `WholeNumber`); `FormatDuration`; criterio "vale la pena guardar"; tope de runs; resumen de salida configurable.
Opcional: continuar visita en la misma copia (`zoneUID`), muertes, oro, reputación.
Descartar: cuenta horaria, NIT, personajes/alts, durabilidad, framework `ns.*`.
