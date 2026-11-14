# 16 — Jefes de quest y opcionales (Naowh Forever, ForeverDungeonRoutes) — 2026-11-13

Origen: en Excavation Site: Wetlands (instance 2998, Normal) murió **Highland Horror** (encounter
3644) y el addon no lo marcó. El log pasivo muestra ENCOUNTER_START/END para Saltspine 3480,
Shadetooth 3481 y Relic Guardian 3482, y **nada** para 3644. En Normal el lockout no marca muertos.
Investigación de código (addon-scout) sobre `AddOns/NaowhForever*` y `AddOns/ForeverDungeonRoutes`
(datos de Forever 1.60.1.70862).

## Conclusión

- Naowh marca **un solo** jefe como `quest = true`: Highland Horror (npc 260808, enc 3644), que
  pide la quest **95646 "Horrors in the Highland"** (Alianza, nv 24, Rethiel the Greenwarden,
  Wetlands). `NaowhForever_DungeonJournal/Data/Dungeons/ExcavationSite.lua:14`,
  `Data/BossQuests.lua:27`. La quest de Horda de la mazmorra (95664 "Elder Knowledge") sale del
  loot de Relic Guardian y no tiene nada que ver con este jefe.
- El flag es **solo de presentación** (etiqueta QUEST, no lo numera): `DungeonJournal.lua:347-354`.
  Prioridad de etiquetas: RARE > OPTIONAL > QUEST > CHEST.
- **Nadie detecta su muerte**:
  - El InstanceTracker de Naowh (`NaowhForever_Utilities/InstanceTracker`, el del aviso «Left X»)
    no cuenta jefes.
  - `DungeonJournal/Kills.lua` solo cuenta con ENCOUNTER_END `success == 1`.
  - ForeverDungeonRoutes lo pone como parada `optional` (`DefaultRoutes.lua:392`: «drops a quest
    item», en el Lost Dig Site al oeste) y solo marca kills con ENCOUNTER_END/BOSS_KILL.
- Tip de Naowh (`Data/Tips.lua:62`): «Kite it into the campfire to set it on fire.»

## Opcionales con encounterID (Naowh `optional = true`)

En nuestra `DungeonData.lua` los diez son **jefes normales**, así que cuentan para «X/Y» y para
dar la run por terminada:

| instance | jefe | enc |
|---|---|---|
| 229 UBRS | Lord Valthalak | 3070 |
| 329 Stratholme | Postmaster Malown | 2798 |
| 289 Scholomance | Kormok | 3055 |
| 47 RFK | Roogug | 2773 |
| 230 BRD | Princess Moira Bronzebeard | 2789 |
| 2959 Dalaran | Mana Wraith | 3312 |
| 2959 Dalaran | Mana Devourer | 3300 |
| 2959 Dalaran | Arcanic Enigma | 3301 |
| 429 Dire Maul | Lord Hel'nurath | 2793 |
| 429 Dire Maul | Cho'Rush the Observer | 367 |

Los opcionales **sin** encounterID (Baelog/Eric/Olaf, Spawn of Hakkar, Dathrohan, Balzaphon,
Sever, Bossman Toof, Techbot, Isalien…) no están en nuestra tabla y no se pueden contar por
ENCOUNTER_END. Los `rare = true` con encounterID coinciden exactamente con los nuestros.

## Señales para detectar la muerte sin ENCOUNTER_END

Dentro de la mazmorra, el GUID, el nombre de la criatura y CLEU son secretos, así que quedan
descartados. Tampoco sirve el lockout, que en Normal no marca muertos.

1. **Objetivo de la quest 95646** (`QUEST_LOG_UPDATE` + `C_QuestLog.GetQuestObjectives(95646)`,
   campos `finished`/`numFulfilled`).
   - Es la mejor candidata.
   - Solo funciona si **el jugador** tiene la quest.
   - `IsQuestFlaggedCompleted` no sirve, porque se marca al entregar la quest, no al matar al jefe.
2. **CHAT_MSG_SYSTEM / UI_INFO_MESSAGE** «Highland Horror slain: 1/1».
   - Sirve para corroborar.
   - Depende del idioma y de tener la quest.
   - Antes del `find`, comprobar con `issecretvalue`.
3. **Loot del ítem de quest.** Sirve para corroborar. No está identificado y solo lo ve quien lo saquea.

## Sin verificar in-game (Excavation Site)

- (a) ¿Llega BOSS_KILL al matar a Highland Horror? El log pasivo no registra BOSS_KILL.
- (b) ¿Cambian QUEST_LOG_UPDATE y los objetivos de 95646?
- (c) ¿Qué texto de sistema o de UI aparece al matarlo?
- (d) ¿Aparece aunque nadie del grupo tenga la quest?

## Decisión (owner, 2026-11-13)

- Highland Horror lleva `quest = true` y los 10 opcionales con encounterID llevan `optional = true`.
  Los dos flags los emite `scripts/gen-dungeons.lua` con la prioridad de NF.
- Se tratan igual que un rare:
  - salen en la lista, al final y atenuados;
  - se marcan si llega ENCOUNTER_END;
  - no cuentan para «X/Y», para el fin de la run ni para los splits del récord.
- La etiqueta tiene el mismo aspecto que la de RARE, con el texto QUEST u OPCIONAL/OPTIONAL.
- Pendiente: detectar la muerte de Highland Horror por el objetivo de la quest 95646, después de
  las pruebas (a)–(d) de arriba.
- Las runs ya guardadas conservan su clasificación anterior: un jefe ya colocado en la ruta no se
  reclasifica.

## ForeverDungeonJournal (FDJ, competencia) — 2026-11-13

Lectura parcial de `AddOns/ForeverDungeonJournal/Systems/RunLog.lua`, `Core/Journal.lua` y `Data/*` (addon-scout).

- Tiene **tracker de runs** (`Systems/RunLog.lua`):
  - registra kills de trash y de jefes con XP, rolls de Need, tiempo desde la primera kill hasta
    el último jefe, muertes y % de trash;
  - la run sigue siendo la misma si vuelves antes de 90 min (20 min si el jefe final ya murió),
    `:22-23`.
- **Misma decisión que la nuestra:** `AllBossesDown` (`:595`) excluye de la completitud a
  `rare`, `optional`, `spawnQuest` y `summonItem`.
  - Highland Horror figura como «questmob» `npcID 260808, quest 95646` (`Core/Journal.lua:467-476`).
- **Tampoco detecta la muerte de Highland Horror.** Sin ENCOUNTER_END, las vías posibles son:
  - `PARTY_KILL`: dentro de la mazmorra el objetivo llega secreto, así que solo da una kill
    anónima de grupo, sin nombre (`:2077-2089`);
  - `UNIT_DIED`: solo con GUID público (`:2090-2094`);
  - la línea de chat «X dies» (`:2126-2132`), aunque su propio comentario dice que Forever no la
    emite dentro de la mazmorra (`:2079-2081`);
  - un cadáver visto con GUID legible (`:1452-1454`).

  Las kills que llegan por varios canales se fusionan en una ventana de 3 s (`:1083-1184`). No usa
  C_QuestLog, QUEST_* ni el loot para identificar jefes.
- **Secret values:** usa `Plain(v)`, que devuelve nil si `issecretvalue(v)` (`:27-30`), y `pcall`
  en cada API de unidad. Cuando un valor sale secreto, degrada en lugar de descartar.
- **Ideas que podemos aprovechar:**
  - `db.bossEvents[id]` + `/dj bossids`: registro de qué jefes emiten ENCOUNTER_END en Forever.
    Serviría para encontrar otros casos como Highland Horror.
  - Usar `UnitIsBossMob` / `UnitClassification` + `UnitLevel` para reconocer jefes o rares
    cuando el nombre llega secreto. Solo dice que el jefe está vivo, no que haya muerto.
  - No tiene ping, ni marcas de banda, ni aviso al salir de la mazmorra.
- Conclusión: el objetivo de la quest 95646 (señal 1) sigue siendo la única vía que identifica a
  Highland Horror. `PARTY_KILL` anónimo + XP serviría como mucho de corroboración.

### Inventario (2026-11-13)

Ruta: `F:\Games\World of Warcraft\_forever_\Interface\AddOns\ForeverDungeonJournal` (493 archivos, ~85 k líneas).
Es sobre todo un **diario de mazmorra** (jefes, loot, quests, mapas); el tracker de runs es un módulo más.

**1. Metadatos** (`ForeverDungeonJournal.toc`)
- `## Interface: 16001`, título «DungeonJournal», versión 2.0.5, autor Exehn (`:1-5`).
- SavedVariables `ForeverDungeonJournalDB` + por personaje `ForeverDungeonJournalCharacterDB` (`:10-11`); sin dependencias.
- AddonCompartment (click/enter/leave) y `Bindings.xml` con 2 atajos: abrir diario y abrir el objeto bajo el ratón.
- Orden de carga: Bootstrap/Fonts → Localization (8 `Locale_*`, 9 `Content_*` + NewDungeons) → Data/* → Verified → UI/*Data →
  Systems (MapMarkers, LootFilter, Favourites, RunLog, RunLogUI…) → `Core/Journal.lua` (`:62`) → resto de Systems → LibDeflate → CharacterSnapshot/Export/ProgressTransfer.
- Docs propios útiles: `ARCHITECTURE.md`, `README.txt` (changelog), `SCARLET-TRACKER-FIX.md`, `TRACKER-WING-FIX.md`.

**2. Módulos** (líneas)
| Archivo | Qué hace | Tamaño |
|---|---|---|
| `Core/Journal.lua` | ventana del diario, páginas por mazmorra, slash `/dj`, minimapa (`:11987`) | 12,6 k |
| `Data/Dungeons.lua` | `FDJ.DB`: mazmorras, quests, jefes, loot | 10 k |
| `Systems/MapMarkers.lua` | pines en el mapa, ruta superpuesta, flecha de waypoint (`ForeverDungeonJournalArrow`, `:3750`) | 4 k |
| `Data/QuestUpdates.lua` / `QuestChains` / `QuestMaps` / `QuestRewards` | parches de quests, cadenas de prerrequisitos, coordenadas de los NPC, XP | 3,8 k / 2 k / — |
| `Systems/RunLogUI.lua` | ventana «Character Logs» (`:1254`), tracker en vivo (`:2272`), botones seguros de objetivo jefe/rare (`:2789`, `:2860`) | 3,5 k |
| `Systems/QuestText.lua` | texto de quests (QUEST_DETAIL), menú del saco de dormir | 3,2 k |
| `Systems/RPGMode.lua` | «modo RPG»: mazmorras bloqueadas hasta matar al jefe final | 2,9 k |
| `Systems/RunLog.lua` | grabador de runs (kills, XP, Need, muertes) | 2,3 k |
| `Systems/LootFilter.lua` | filtro de loot (recetas, clase, stats) | 2,1 k |
| `Systems/SettingsPanel.lua` / `OptionsPanel` | opciones | 1,4 k / 0,1 k |
| `Data/DungeonRoutes.lua` | ruta de viaje con polilínea por facción (2 rutas) | 1,1 k |
| `Favourites`, `LFGButton`, `ProgressTransfer`, `OnyxiaAttunement`, `WorldMapOverlay` | favoritos de loot; ojo LFG; exportar/importar progreso; cadena de Onyxia; mapa de mazmorra sobre la M | 0,9 k / 0,9 k / 0,6 k / 0,5 k / 0,4 k |
| `Data/RunLogEncounters.lua`, `RunLogWings.lua`, `Bosses.lua` | encounterID→jefe, firmas de ala, niveles de jefe | — |
| Otros | `BossSummon`, `ScarletWing`, `ItemSource`, `ClientNames`, `PortraitPool`/`BakedPortraits`, `VersionCheck`, `BugReport`, `CharacterExport/Snapshot` | ≤0,35 k c/u |
| `Libs/LibDeflate` | compresión (código de progreso) | librería |

**3. De cara al usuario**
- Un solo slash, `/dj` (`Core/Journal.lua:12205`): sin args abre el diario; `lang`, `options|settings|config`,
  `tracker`, `reset`, `bossids [texto]`, `log|runs`, `itemtip`, `mode`, `worldmap`, `scale N`, `minimap`, `wing …`
  y ~60 atajos de nombre de mazmorra (`/dj rfc`, `/dj brd`, `:12330-12402`).
- Ventanas: diario, Character Logs (hasta 150 runs, `RunLog.lua:19`; QDT guarda 20), tracker en vivo con menú propio,
  filtro de loot, favoritos, ajustes, selector de modo, aviso de desbloqueo (toast), exportación de personaje.
- Botones: minimapa, ojo LFG en la cabecera de cada mazmorra (abre el LFG de Forever, `LFGButton.lua:1-40`),
  botón en el mapa mundial para alternar mapa de mazmorra / mundo (`WorldMapOverlay.lua:293`), flecha de waypoint.
- Tracker: Reabrir con `/dj tracker`; botón de reset (`FDJ.ResetTrackedRun`, `RunLogUI.lua:2006`) para cerrar la run al resetear.
- 10 idiomas de interfaz y contenido traducido (`Localization/`, datos de traducción: no leídos).

**4. Datos**
- `FDJ.DB` = **35 mazmorras** (clave = nombre inglés), ~**346 quests**, jefes con `loot` (`Data/Dungeons.lua:5`).
  - Mazmorra: `level, location, description, icon, quests{}, bosses{}`. Quest: `id, name, faction, level, requires, objective, pickup, turnin, rewards, rewardItems{{itemID,nombre,calidad}}, rewardChoice, liveXPFallback, noteItem/noteItemMap` (`:12-70`).
  - Jefe: `name, npcID?, aliases{}, customIcon?, loot{{itemID,nombre,slot,calidad}}` (`:94-123`); flags que usa el tracker: `rare`, `optional`, `spawnQuest`, `summonItem`.
- `RUNLOG_ENCOUNTERS`: **252** `[encounterID] = { mazmorra, jefe }`, con varios IDs por jefe (IDs nuevos de Forever); fuente declarada: `DungeonEncounter.db2` build 1.60.1.70862, DBM y LittleWigs (`RunLogEncounters.lua:1-14`).
- `BOSS_LEVELS[mazmorra][jefe] = "nivel"`; `QUEST_START_MAPS[questID] = {mapID,x,y,label,targetName,detail}`;
  `QUEST_PREREQ_CHAINS[questID] = {{id,name}}`; `RunLogWingTrash[mazmorra][npcID] = nombre` (Dire Maul, Scarlet…).
- `DungeonRoutes`: 2 rutas (p. ej. Ruins of Lordaeron, Alianza) con `mapRoute.points{mapID,x,y,corner}` (`:9-45`).

**5. Eventos y secret values**
- RunLog escucha `PLAYER_ENTERING_WORLD/LEAVING_WORLD`, `ZONE_CHANGED(_NEW_AREA)`, `PLAYER_XP_UPDATE`, `PLAYER_DEAD`, `PARTY_KILL`,
  `UNIT_DIED`, `ENCOUNTER_END`, `CHAT_MSG_COMBAT_XP_GAIN/HOSTILE_DEATH/LOOT/SYSTEM`, `START_LOOT_ROLL`, `GROUP_ROSTER_UPDATE` (`RunLog.lua:1975-1980`, `:2261`).
  Cabecera: «WoW Forever closes COMBAT_LOG_EVENT_* to addons» (`:11-15`).
- Identifica la copia de la instancia con el **zoneUID del GUID de criaturas** (`:63`); no usa `UNIT_SPELLCAST_SENT`/castGUID
  (cero coincidencias en RunLog.lua) → en Forever, con GUID secreto dentro, es una ruta menos fiable que la nuestra (F1).
- `issecretvalue` solo en 15 archivos (35 usos; el grueso en `MapMarkers`, 12): casi siempre el patrón `Plain(v)` (también `RPGMode.lua:23-26`). Ningún caso nuevo de taint más allá de lo ya anotado arriba.
- Otros: `QUEST_*` (diario, texto, pines), `LFG_LIST_ACTIVE_ENTRY_UPDATE` + `ADDON_ACTION_BLOCKED/FORBIDDEN` (LFG), `LOOT_OPENED`/`BOSS_KILL` (RPG), `GET_ITEM_INFO_RECEIVED`; botones `SecureActionButtonTemplate` para marcar/apuntar jefes y rares.
- Ahora mismo no usa C_QuestLog para jefes, ni posición del jugador (Forever no la da dentro).

**6. Comparativa con QDT**
- **FDJ sí, QDT no:** diario de loot/quests/mapas de 35 mazmorras; 10 idiomas; filtro de loot y favoritos; waypoint y rutas de viaje;
  LFG; modo RPG; export/import; logs de 150 runs con % de trash, rolls de Need, tiempo fuera, XP por mob; botón de minimapa y atajos.
- **QDT sí, FDJ no:** HUD con cronómetro y split por jefe sobre Craft/Weave; ping y marca de banda con clic derecho (ya anotado);
  aviso al salir de la mazmorra; lógica específica de jefes de quest; identificación por castGUID (F1) y `/qdt check`; tests, luacheck, taintlint.
- **Ideas reutilizables (como hechos, no copiar código):**
  - Tabla encounterID→jefe de Forever (252, build 70862): fuente a contrastar contra los `ENCOUNTER_END` observados antes de poblar la nuestra.
  - Reglas de reanudación de run: 90 min abierta / 20 min tras el jefe final (`RunLog.lua:22-23`) y «reset» manual de la run como botón.
  - Contar trash total por mazmorra y mostrar % (`runLogTrashTotal`, `:57`); tiempo fuera de la mazmorra (corpse run).
  - Botones seguros `SecureActionButtonTemplate` para fijar objetivo de un jefe (`RunLogUI.lua:2860`): solo fuera de combate.
  - Idiomas: nosotros mantenemos EN + esMX; las 10 localizaciones de FDJ son un listado de nombres de jefe por idioma, no un modelo.

### Cotejo encounterID QDT ↔ FDJ (2026-11-13)

Comparado a mano, mazmorra a mazmorra, `DungeonData.lua` (`modules/InstanceTracker/core/`) contra `Data/RunLogEncounters.lua` de FDJ
(`[id] = {mazmorra, jefe}`, build 70862). Un jefe «coincide» si al menos un ID de QDT está en FDJ para ese mismo jefe.

**1. Resumen:** 226 jefes en QDT (`DungeonData.lua:11-302`, 31 mazmorras/alas).
- **189 coinciden** (incluye Sunken Temple por IDs viejos y Upper Blackrock Spire con nombre distinto, ver abajo).
- **8 difieren** de ID (tabla). **29 solo en QDT** (sin ID en FDJ). FDJ tiene además **11 jefes/IDs que QDT no tiene**.

**2. Discrepancias (ID distinto o nombre contradictorio)**
| Mazmorra | Jefe | ID QDT | ID(s) FDJ | Nota |
|---|---|---|---|---|
| Blackrock Depths | Emperor Dagran Thaurissan | 2790 (`:53`) | 245 (`:68`) | FDJ no tiene 2790 |
| Blackfathom Deeps | Lorgus Jett | 2913, 2764 (`:22`) | 222 (`:25`) | ninguno de los dos de QDT está en FDJ |
| Gnomeregan | Grubbis | 2768 | 379 | **los 5 jefes** difieren: QDT 2768-2772 vs FDJ 378-382 |
| Gnomeregan | Viscous Fallout | 2769 | 378 | (`DungeonData.lua:112-116`, FDJ `:101-105`) |
| Gnomeregan | Electrocutioner 6000 | 2770 | 380 | |
| Gnomeregan | Crowd Pummeler 9-60 | 2771 | 381 | |
| Gnomeregan | Mekgineer Thermaplugg | 2772 | 382 | |
| Scarlet Monastery: Graveyard | Bloodmage Thalnos | 2779 (`:195`) | 445 (`:181`) | FDJ no tiene 2779 |
| Upper Blackrock Spire | Warchief Rend Blackhand | 3063 (`:278`) | 278 (`:275`); 3063 = «Gyth» (`:279`) | mismo ID, jefe distinto: ¿Gyth y Rend comparten encuentro? |

**3. Sin ID en el otro lado**
- **Solo QDT (29).** Casi todos son opcionales/rares/quest, que FDJ trata como jefes sin evento (`optional`/`rare`/`spawnQuest`):
  Moira 2789; Dalaran Mana Wraith 3312 y Arcanic Enigma 3301; Miner Johnson 3676; Dire Maul Pusillin 2792, Tsu'zee 2794, Hel'nurath 2793;
  **Highland Horror 3644**; Hall of Thanes Magmatus 3495; Ruins The Butcher 3355; Stratholme Skul 2799 y Stonespine 2800; Uldaman
  Obsidian Sentinel 1887; Atal'alarion (Sunken Temple, 3582/2814).
  **Candidatos a «sin ENCOUNTER_END» como Highland Horror:** los 3 de Dire Maul (2792-2794), Miner Johnson, Skul, Stonespine, Lyn/Lordaeron Captain
  (esos sí están en FDJ). Que FDJ no tenga el ID no prueba que no se emita: su tabla sale del db2 + DBM/LittleWigs, no de observación.
- **Mazmorras enteras solo en QDT:** Scholomance (14 jefes, 2801-2813 y Kormok 3055) y Onyxia (1084): FDJ no las cubre.
- **Solo FDJ:** BRD Ring of Law 230 y The Seven 243 (`:53`, `:66`); Drowned City Deathless Marrow 3478 (`:255`); Stratholme Malor the Zealous 476
  (`:217`); Uldaman The Lost Dwarves 548 (`:266`); UBRS Solakar Flamewreath 277 (`:274`); Shaper's Terrace Titanosaur 3498, Thunderhoof 3500,
  Venomridge 3501, Direhorn Matriarch 3507, Vitrix 3600 (`:203-211`).
  Los de Shaper's Terrace parecen rares/opcionales que QDT no lista; no tienen flag en FDJ.

**4. IDs alternativos de FDJ que QDT no escucha** (QDT usa solo los 27xx/3xxx; el db2 trae además los clásicos)
- Un ID viejo por jefe: BFD 219-222,224-226; Ragefire 430-433; Razorfen Downs 434-437; Razorfen Kraul 439-441,443,883; Shadowfang 464-471;
  Deadmines 161-167. En estos QDT ya cubre los 27xx; si el cliente emitiera el viejo, no contaría.
- Sunken Temple: FDJ agrupa por pares («Dreamscythe & Weaver» 486/487, «Morphaz & Hazzas» 490/491); QDT sí escucha 486-493 pero
  no hay confirmación de que 3583-3589 existan en FDJ.
- UBRS: 276-280 (legacy) además de 3062-3070.

**5. Recomendación (no aplicado; `DungeonData.lua` es generado por `scripts/gen-dungeons.lua`)**
1. Gnomeregan: añadir `378-382` como IDs alternativos a los 27xx (idem BRD Thaurissan `245`, Thalnos `445`, Lorgus `222`). Un ID extra no
   rompe nada si FDJ dice que son únicos (`RunLogEncounters.lua:10-11`).
2. Añadir los viejos de §4 como ids secundarios en el generador, solo donde QDT tiene un único ID.
3. Revisar en el generador de dónde sale Gnomeregan 27xx y Lorgus 2913/2764 (¿Naowh o medido?) antes de tocarlos.
4. **Confirmar in-game** con `/dj bossids` o nuestro log de ENCOUNTER_END: Gnomeregan (cuál ID llega), Thaurissan, Thalnos, Lorgus, Rend/Gyth (3063),
   y qué jefes opcionales/rares de §3 emiten evento (Dire Maul 2792-2794, Miner Johnson, Skul/Stonespine, Atal'alarion).
