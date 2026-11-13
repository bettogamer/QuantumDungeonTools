# 11 — Orden de jefes y rares (investigación, 2026-11-13)

**Problema:** la lista de `GetInstanceLockTimeRemainingEncounter(i)` mezcla jefes y rares y no viene
en el orden de la mazmorra (Ruins of Lordaeron, instanceID 2999: 7 entradas, una es el rare
Lordaeron Captain).

## Qué hace NaowhForever_DungeonJournal (NF)

- Datos **estáticos propios** generados por script (`Tools/build/journal.py`): un archivo por mazmorra en
  `AddOns\NaowhForever_DungeonJournal\Data\Dungeons\<Clave>.lua` (35 archivos, incluye Hyjal y Onyxia).
- Esquema por jefe: `npc`, `name`, `rare` (opcional), `trash` (opcional), `encounters = { id }`,
  `loot`… Mazmorra: `instance` (instanceID), `wings = { { bosses = {...} } }`.
- Mapeo: `GetInstanceInfo()` → `dungeon.instance`; `byEncounter[encounterID]` para
  `ENCOUNTER_START/END` (`Kills.lua:32-43`, `:273`).
- **No usa** ninguna API de Encounter Journal (0 coincidencias de `EJ_*`/`C_EncounterJournal`).
- Licencia: `NaowhForever\LICENSE.md:6-7` «all rights reserved» → **no copiar sus tablas**. Los
  IDs y nombres de encuentros son datos del juego y se pueden medir por nuestra cuenta.
- **Nombres en inglés en la tabla generada (`core/DungeonData.lua`): aprobado por el owner
  (2026-11-13).** Hacen falta porque el lockout solo da nombres; otros idiomas los cubre `learned`
  (`name → encounterID` aprendido de `ENCOUNTER_END`).

Ruins of Lordaeron según NF (orden de su tabla, no un campo de secuencia):

| # | Jefe | encounterID |
|---|------|-------------|
| 1 | Witherfang | 3353 (medido) |
| 2 | The Butcher (NF: «The Baron») | 3355 (medido) |
| 3 | Viktor the Vile | 3411 |
| 4 | The Abandoned | 3357 |
| 5 | Bjork | 3412 |
| 6 | Rath'mael | 3354 |
| — | Lordaeron Captain (**rare**) | 3408 |

El orden coincide con el orden real de muertes de la run del owner (2026-11-13).

## API del cliente

- En la api-db local de taintlint (12.0.7) no hay `EJ_GetEncounterInfoByIndex`/`EJ_SelectInstance`;
  `C_EncounterJournal` sí (14 funciones, p. ej. `IsEncounterComplete`). Sin medir en Forever:
  sonda in-game con `type()` + `pcall` antes de contar con ella.

## Decisión del owner (2026-11-13)

Los datos (instanceID, encounterIDs, orden, rare) son **datos de Blizzard** — NF los generó con un
script desde los datos del juego — así que QDT puede generar su propia tabla con un script en
`scripts/` que solo extraiga esos campos (sin código, textos, loot ni modelos de NF), anotando la
fuente en la cabecera del archivo generado.
**Rares (owner):** se QUEDAN en la lista, solo como información (marcados como rare, con su tiempo si
mueren), pero **no cuentan** en el X/Y de jefes ni para el fin de run: la run termina cuando mueren
todos los jefes no-rare. Fuente preferida si está disponible: las tablas DB2 de
Blizzard (Journal*/DungeonEncounter) del build de Forever; si no, los archivos de NF. Pendiente: hacerlo
en sesión nueva.

## Opciones para QDT

1. **Tabla propia en `core/`** por instanceID: orden + rares (por encounterID), medida por nosotros.
2. **Aprender el orden**: guardar el orden de muertes de la primera run completa de cada mazmorra.
3. Sonda de Encounter Journal (si existe en Forever, da orden del Journal, no de ruta).
