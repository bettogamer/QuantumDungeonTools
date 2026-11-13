# 00 — Contexto de la sesión de origen (2026-11-12)

Este documento conserva todo lo hablado en la sesión en la que nació el addon: el problema, las
pruebas de viabilidad hechas in-game, los resultados, las decisiones y el alcance. **Léelo antes de
reabrir cualquier decisión.**

## 1. Identidad

| Qué | Valor |
|---|---|
| Nombre visible | **Quantum Dungeon Tools** (abreviatura **QDT**, al estilo de MRT) |
| Por qué "Quantum" | Es el nombre de la guild del usuario. Deja la puerta abierta a más addons de la guild con el mismo estilo |
| Por qué "Dungeon Tools" | El usuario lo prefiere a "Run Tools" ("no pega"). Riesgo asumido: se parece a *Mythic Dungeon Tools* (MDT) |
| Carpeta / `.toc` | `QuantumDungeonTools` |
| Comando | `/qdt` |
| SavedVariables | `QuantumDungeonToolsDB` (una sección por módulo) |
| Cliente | **WoW Forever** (1.60.x, `## Interface: 16001`; motor de 12.1.5 con secret values) |
| Nivel del estándar | **M** (motor propio, varias piezas, datos guardados) |
| Publicación | Sin decidir; de momento NO se prepara CurseForge |

Nombres que se descartaron: Wayfinder, Tally, DungeonCompass, Lantern, Chronicle, Bitácora,
RunLedger, Quantum Run Tools (QRT)…

## 2. El problema original

1. Dentro de una mazmorra solo el **minimapa** muestra dónde estás. En el mapa grande (**M**) no se
   ve tu posición.
2. Para saber qué jefes has matado hay que abrir el mapa y ver qué iconos están grises; no hay un
   recuento de cuántos quedan.

## 3. Pruebas de viabilidad (in-game, con `/run`)

### Problema 1 — posición en el mapa: **NO VIABLE**

| Dato | Fuera (Undercity) | Dentro ("Ruins of Lordaeron") |
|---|---|---|
| `C_Map.GetBestMapForUnit("player")` | 1458 | `nil` |
| `C_Map.GetPlayerMapPosition` | 0.66, 0.38 | sin mapa → no aplicable |
| `UnitPosition("player")` | 1632, 239, inst 0 | `nil, nil`, inst **2999** |
| `GetPlayerFacing()` | 2.04 | `nil` |
| `issecretvalue` sobre lo anterior | false | false (no es secret: es `nil`) |
| `GetSubZoneText()` / `GetMinimapZoneText()` | — | `""` / "Ruins of Lordaeron" |
| `WorldMapFrame:GetMapID()` con la M abierta mostrando la mazmorra | — | **947 (Azeroth)**, posición `nil` |
| Barrido `C_Map.GetMapInfo(1..3000)` buscando "Lordaer" | — | ningún mapa |

- `GetInstanceInfo()` dentro: `Ruins of Lordaeron`, tipo `party`, Normal, 5 jugadores, id 2999
  (mazmorra propia de WoW Forever).
- La M **sí** pinta el arte de la mazmorra con los 7 jefes numerados (grises al morir), pero el
  marco sigue en el mapa 947: ese dibujo no es un uiMap al que se le pueda pedir posición.
- En una segunda mazmorra el resultado fue también `nil` (respuesta del usuario algo ambigua).
- Conclusión: es la restricción intencionada de datos de posición en instancias. **Un addon no
  puede pintar tu flecha en el mapa grande ni colocar iconos relativos a ti.**

### Alternativa: minimapa grande — **VIABLE**

```
/run Minimap:ClearAllPoints() Minimap:SetPoint("CENTER",UIParent) Minimap:SetSize(600,600)
/run Minimap:SetZoom(0)            -- zoom 0 de 5 (el más alejado)
/run Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8X8")   -- cuadrado
```

- Funciona, también **en combate**; `/reload` lo deja todo como estaba.
- Enseña **la misma zona, más grande y con más detalle** (no más área).
- Iconos de jefe en el minimapa: **no se puede** (el minimapa va centrado en ti y tu posición es
  desconocida). Los jefes ya salen en la M.
- Nota: el `SetPoint("CENTER")` no lo movió al centro en la prueba (se quedó arriba a la
  derecha, seguramente lo recoloca el `MinimapCluster`); habrá que revisarlo al implementar.

### Problema 2 — jefes muertos/restantes: **VIABLE**

```
/run local _,_,t,c=GetInstanceLockTimeRemaining() print("total:",t,"muertos:",c) for i=1,(t or 0) do print(GetInstanceLockTimeRemainingEncounter(i)) end
```

Resultado en Ruins of Lordaeron (Normal, sin jefes muertos):

```
total: 7 muertos: 0
Witherfang      nil false false
The Abandoned   nil false false
The Butcher     nil false false
Lordaeron Captain nil false false
Viktor the Vile nil false false
Bjork           nil false false
Rath'mael       nil false false
```

Firma observada: `bossName, texture(nil), isKilled, (4º bool, ¿isIneligible?)`.

**PENDIENTE**: repetir el comando después de matar un jefe y confirmar que `isKilled` pasa a
`true` y `muertos` sube. Si no cambiara en Normal, plan B: contar con el evento `ENCOUNTER_END`
(success = 1) cruzando por nombre/encounterID.

## 4. Alcance decidido

QDT es una **caja de herramientas por módulos** (carpetas dentro de un único addon, activables
desde `/qdt`; separar en addons LoadOnDemand solo si crece mucho).

### Módulo 1 — Instance Tracker ("todo lo que hay que saber de la mazmorra")

- **Jefes**: "Jefes 2/7", con la lista y cuáles faltan.
- **Cronómetro**: tiempo total de la run y el momento (split) de cada jefe.
- **Experiencia**: XP ganada durante la mazmorra.
- Más adelante, cualquier otro dato útil de la run.

### Módulos futuros

- **Minimap Lens**: minimapa grande en mazmorras (al entrar o con un botón), vuelve a su sitio
  al salir.
- Lo que pida la guild.

## 5. Avisos para el desarrollo

- WoW Forever = motor 12.1.5 → aplican todas las reglas de secret values del CLAUDE.md global
  (`issecretvalue` antes que cualquier test de verdad, `pcall` en APIs críticas).
- Las pruebas con `/run` corren con `ForceTaint_Strong` (más restrictivo que un addon): si algo
  funciona en `/run`, funciona en el addon.
- La línea de chat tiene límite de longitud: los comandos de prueba deben ser cortos o ir en macro.
- El hallazgo de "sin posición en mazmorras" está apuntado en el CLAUDE.md global para no
  repetirlo en otros proyectos.

## 6. Estado al cerrar la sesión (v0.1, sin probar in-game)

Implementado (sin commits; el usuario decide cuándo):

| Archivo | Qué hace |
|---|---|
| `core/Format.lua` | Puro: `duration` (mm:ss / h:mm:ss) y `thousands` (1,234) |
| `wow/Bootstrap.lua` | DB con defaults (`instanceTracker.autoShow`, `history`), versión, arranque de módulos |
| `modules/InstanceTracker/core/Run.lua` | Modelo puro de la run: jefes (lista del lockout + muertes por evento, split por jefe, `preKilled` si ya estaba muerto), fin automático al caer el último, detección de reset de instancia, XP (cruza subidas de nivel), persistencia |
| `modules/InstanceTracker/wow/Tracker.lua` | Eventos: entrar/salir de instancia, `UPDATE_INSTANCE_INFO`, `ENCOUNTER_END`/`BOSS_KILL`, `PLAYER_XP_UPDATE`. Guarda la run en `QuantumDungeonToolsDB` (sobrevive a `/reload`) y un historial de 20 runs |
| `modules/InstanceTracker/wow/UI.lua` | Ventana movible: nombre + dificultad, "Jefes 2/7 \| 12:34 \| XP +1,234" y la lista con el tiempo de cada jefe. Se abre sola en mazmorras |
| `Config.lua` | `/qdt it`, `/qdt new`, `/qdt history`, `/qdt auto`, `/qdt info` |

Decisiones de diseño tomadas en solitario (revisables):
- La run empieza al **entrar** en la instancia y el reloj usa `time()` (sobrevive a `/reload` y relog).
- Salir de la mazmorra (p. ej. a reparar) **no** corta la run: al volver a la misma instancia se retoma.
  Entrar en otra mazmorra cierra la anterior (va al historial si tenía algún jefe muerto).
- La XP solo cuenta mientras estás dentro.
- Un jefe ya muerto al empezar a seguir la run sale con `--` en vez de tiempo.
- Widgets nativos de Blizzard, sin Craft (Craft es de retail; compatibilidad con Forever sin verificar).

### Checklist de prueba in-game (pendiente)

1. Al entrar en una mazmorra se abre la ventana con nombre, dificultad y la lista de jefes (X/Y).
2. Al matar un jefe: pasa a gris con ✓ y su tiempo; el contador sube. **Confirma también que
   `isKilled` del lockout cambia** (era el pendiente de la sesión).
3. El cronómetro avanza y se pone verde y se congela al matar el último jefe.
4. La XP sube al matar bichos y al subir de nivel dentro.
5. `/reload` dentro: la run sigue igual (tiempos incluidos).
6. `/qdt history` tras terminar: aparece la run.
7. Arrastrar la ventana y hacer `/reload`: conserva la posición. La X la oculta hasta el próximo cambio de zona.
8. Sin errores Lua (BugSack instalado).

Despliegue: `powershell -File scripts/deploy-local.ps1` (apunta a `_forever_`).

## 7. Sesión 2 (2026-11-12): diseño del widget

- **Craft SÍ funciona en WoW Forever** (lo usa Coffer) → la UI del módulo se hace con Craft vendoreado, no con widgets nativos.
- Diseño del widget (inspirado en el layout de WarpDeplete, estética Craft Lyra): https://claude.ai/artifact/QCFDYZLH1HU8Mj72a3VAXy
  — artboards: En curso, Completada, Compacto, Primera vez.
- Referencia de tiempo = **récord personal (PB)** por mazmorra+dificultad (no hay límite de llave en Forever).
  Sin PB: etiqueta "PRIMERA VEZ", sin deltas, la barra de tiempo pasa a ser de jefes por segmentos.
- NaowhForever InstanceTracker NO trackea jefes (es un clon de Nova Instance Tracker): inventario en
  `docs/10-naowh-instancetracker-inventario.md`. Jefes/splits/récords son diseño propio.
- **Decisiones del owner:** portar de NF **oro y reputación por run** (sí), **contador 10 instancias/hora** (sí),
  **retomar la run en la misma copia como NF** (zoneUID del GUID) (sí).
- **Owner acepta TODAS las mejoras** (pausa, aviso 10/10, ritmo XP/oro por hora + runs para subir, récord con este grupo, indicador retomada, toast fin de run, historial con filtros). Reparto en 4 niveles:
  1 SIEMPRE (widget): reloj, récord+delta, jefes, muertes, barra, estados pausa/retomada.
  2 CONTEXTUAL (widget): "Instancias X/10" desde 7/10; barra XP solo si no es nivel máximo.
  3 HOVER (tooltip): ritmo, reputación por facción, récord con este grupo, huecos de instancia.
  4 FUERA: toast fin de run (+ compartir en grupo), aviso 10/10 antes de entrar, ventana Historial.
  Cada línea del widget desactivable en ajustes. Artboards: Pausa, Detalle, Avisos, Historial.
- Estética final (v3, tras feedback "parece que ha perdido vida" con la arena desaturada): paleta sacada del **logo de WoW Forever**: **oro metálico #F2B84B** = progreso (jefes muertos, barra tiempo), **turquesa #3FD0D4** = por delante/récord/XP (XP base #1F8A8F), **rojo #FF5A4E** = por detrás/muertes/10-10, **crema #F8EEDB** = texto (letras FOREVER), secundario teal-gris #93B4B2, pista barra #0F2A2C, panel #081A1B. Fuente **BettoGeo** (la trae Craft) para TODO, cifras en Bold con tabular-nums (sin mono); texto con contorno oscuro (OUTLINE en WoW). Reloj en turquesa si vas por delante. Barra de tiempo 14 px. Oro SIEMPRE con iconos de moneda, nunca "g/s/c": reusar el patrón de Coffer `MoneyDisplay.lua` (`GetCoinTextureString` + tamaño de icono explícito). Tags = solo borde. **El widget NO tiene fondo (transparente sobre el juego)**: legibilidad solo por contorno+sombra; los paneles con fondo son solo tooltip, toast y ventana Historial. Referencia del owner: su WarpDeplete de retail (saturado, cifras gruesas, contorno).
- **DISEÑO CERRADO (2026-11-12).** Las fuentes del lienzo viven en el artifact (los `.dc.html` del scratchpad de la sesión 2 se pierden): para revisarlas, `Artifact read` con `path` `project/<Artboard>.dc.html`.
- **Siguiente (sesión 3): escribir el plan del hito** (plantilla `docs/PLAN-HITO_TEMPLATE.md`) para reconstruir el módulo con Craft vendoreado (nota: el v0.1 actual usa widgets nativos → migrar), PB por mazmorra+dificultad, pausa/reanudación por zoneUID (como NF), oro/rep, contador 10/hora, tooltip, toast, aviso, ventana Historial. Pendiente heredado: verificar in-game que `isKilled` del lockout cambia al matar un jefe (§3).
