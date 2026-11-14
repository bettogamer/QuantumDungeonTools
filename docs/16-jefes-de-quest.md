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
