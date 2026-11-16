# 26 — Siguiente módulo (M3): investigación de candidatos

> Sesión 2026-11-16, tras cerrar M2. Estado: **investigación cerrada, decisión del owner
> pendiente** (§6). Nada de esto está en código.

## 1. Punto de partida

El doc 00 §4 deja como «módulos futuros» solo Minimap Lens (hecho en M2) y «lo que pida la
guild». Restricciones medidas que filtran cualquier idea (AGENTS.md §5, CLAUDE.md global):

- Sin posición del jugador dentro de mazmorras (`GetBestMapForUnit`/`UnitPosition`/`GetPlayerFacing` = nil).
- Motor 12.1.5: auras y datos de unidades ajenas pueden ser secretos en combate; chat y
  mensajes de addon con `SecretInChatMessagingLockdown`.

## 2. Primera ronda de candidatos (antes de mirar Naowh)

| # | Módulo | Idea | Riesgo |
|---|---|---|---|
| A | Loot Log | botín por run en el historial del IT + resumen de sesión (oro/h, XP/h) | medio: ¿`CHAT_MSG_LOOT` secreto en encuentro? |
| B | Dungeon Prep | durabilidad, bolsas, consumibles, buffs propios antes de entrar | bajo |
| C | Lockout Planner | runs/hora y IDs por alt, a nivel de cuenta | bajo |
| D | Party Sync | reloj/splits/récord compartidos por mensaje de addon | alto (bloqueo de chat en instancia) |

Descartados de entrada: planificador de pulls/rutas y notas posicionales (no hay posición), guías
por jefe (coste de contenido).

## 3. Qué tiene NaowhForever (v1.2.34, instalación local `_forever_\Interface\AddOns`)

15 addons; la mayoría de mundo abierto. El doc 10 inventarió la 1.1.50 (solo su InstanceTracker).

| Addon | Contenido |
|---|---|
| `NaowhForever` | ventana común de módulos |
| `_BiS` | listas BiS, pesos de estadísticas, Gear Score, panel de personaje e inspección |
| `_Combat` | barra de consumibles, swing timer, amenaza, PvP, debuffs de banda, maná druida, bendiciones, sets |
| `_Discovery` (+`Data`, LoD) | libros, saco de dormir, quests y rares por zona |
| `_DungeonJournal` | jefes, botín y quests por mazmorra; `Looted.lua` (qué saqueaste, dónde, con quién), `Kills.lua` (cada jefe: cuándo, cuánto, con quién), `Team.lua`, compartir quests, buscador de botín **por ranura de equipo**, intendentes y reputación |
| `_Market` (+`AuctionData`, LoD) | panel de subasta, banco, farmeo, precios |
| `_Professions` | recetas, reactivos, recetas no aprendidas **con su procedencia**, vendedores, desencantar, cola |
| `_QoL` | Loot (feed + oro/h, durabilidad, espacio de bolsas, reponer/reparar, recordatorios de equipo, cofres), XP (barra, **Group XP por mensaje de addon**), Questing (historial de jugadores, progreso de quests…), Travel, Interface (mapas, waypoints…), Combat (CoTank, alerta de combate, skin del medidor de daño…), Top Bar |
| `_Training` | qué entrenar, ruta al 60, talentos |
| `_Utilities` | InstanceTracker (clon de Nova), Journeys, macros, **Group Inspect** y **Group Finder** (ambos por mensajes de addon), barras de acción, recordatorio de tracking |

**Solapes con §2:** A ≈ `Looted` + `LootFeed`; B ≈ `Durability` + `Restock` + `BagSpace` +
`GearReminders`; C ≈ su InstanceTracker. **Descartados por duplicar a Naowh** (la guild lo usa).

**Dato útil:** Group XP, Group Inspect y Group Finder prueban que los mensajes de addon funcionan
en grupo en Forever (al menos fuera de encuentro) → D baja de riesgo.

## 4. Huecos que Naowh no cubre (dungeon)

1. **Récords de la guild**: ranking por mazmorra+dificultad (mejor tiempo, quién, grupo) por el
   canal de addon GUILD, enviado fuera de instancia. Solo tiene sentido en un addon de guild.
2. **Party Sync**: reloj/splits del grupo, récord de grupo, toast de fin con los tiempos de todos.
3. **Análisis de runs**: comparar dos runs split a split, dónde se pierde tiempo, evolución del
   récord. Amplía el historial del IT sin APIs nuevas.
4. **Muertes/wipes por run**: dudoso; si no hay log de combate para addons (como retail 12.0),
   contar por eventos de unidad. Requiere spike.

Recomendación de la sesión: 1+2 juntos («Quantum Board»); 3 como alternativa pequeña sin riesgo.

## 5. Petición de la guild (2026-11-16)

Un miembro pidió **«un addon que te diga dónde conseguir todo»**: bolsas, abalorios, juguetes,
recetas, qué quest da una bolsa, consumibles útiles. Referencia que citó: GearQuest Forever.

**GearQuest Forever** (CurseForge `gearquest-forever`, v1.2.0, 2026-11-15, ~3,2 M descargas, All
Rights Reserved, autor weber8210): solo **equipo** BiS por clase/spec/nivel 1-60; «cacerías» de
piezas con aviso al conseguirlas, pines en el mapa, puntuación 0-100 en el tooltip, pestaña de
búsqueda, specs con pesos propios. Base de datos propia y cerrada, actualizada semanalmente.

**Hueco:** nadie unifica la procedencia de lo **no-equipo**. Naowh lo tiene repartido (recetas en
Professions, botín por jefe en el Journal, quests en Discovery) y su buscador solo filtra por
ranura de equipo.

**Riesgos (el coste está en los datos, no en el código):**

- Las **recompensas de quest NO están en las tablas del juego** (lo dice el README del
  DungeonJournal de Naowh): hay que sacarlas de Wowhead Forever u otros. Naowh pidió permiso a
  wowsrc y ForeverChanges. Copiar datos de Naowh/GearQuest: prohibido (licencias y AGENTS.md §5).
- Vendedores, recetas y drops de mazmorra: wago.tools (DB2) + Wowhead.
- Requiere pipeline propio de datos y un addon de datos LoadOnDemand (como `*_DiscoveryData`).
- In-game es simple: línea de procedencia en el tooltip, ventana de búsqueda por categoría,
  lista de «busco esto». Secret values casi irrelevantes (fuera de combate).

## 6. Decisiones del owner pendientes

| # | Decisión | Propuesta del agente |
|---|---|---|
| 1 | ¿Qué módulo es M3: buscador de procedencias (§5) o Quantum Board (§4)? | el de §5: lo pidió la guild |
| 2 | §5: ¿módulo de QDT o addon aparte? (no es de mazmorra) | módulo de QDT + addon de datos LoD |
| 3 | §5: alcance del primer corte | **bolsas y juguetes** (lo pedido, pocos objetos, procedencias variadas; valida el pipeline). Luego recetas y consumibles; abalorios → GearQuest |
| 4 | §5: fuentes de datos | pedir permiso a Wowhead Forever / wowsrc / ForeverChanges, o solo tablas del juego vía wago (sin recompensas de quest) |

## 7. Siguiente paso (sesión nueva)

Spike de datos antes del plan de hito: script que saque las bolsas de Forever de wago + Wowhead
y mida cuántas quedan **sin procedencia**. Con ese número se decide el alcance y se escribe
`docs/plan-m3-<nombre>.md` desde `docs/PLAN-HITO_TEMPLATE.md`.
