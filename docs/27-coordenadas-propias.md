# 27 — ¿Un sistema de coordenadas propio dentro de la mazmorra?

Estado: **investigación abierta** (2026-11-16). Sonda: `/qdt check pos`
([CheckPos.lua](../QuantumDungeonTools/wow/CheckPos.lua)), lector
[read-check-pos.lua](../scripts/read-check-pos.lua).

## El problema

En mundo abierto el cliente da posición (`UnitPosition`, `C_Map.GetPlayerMapPosition`). Dentro de una
mazmorra de Forever todo eso es **`nil`, no secreto** (medido, [doc 00 §3](00-contexto-sesion-origen.md)):
`UnitPosition` solo devuelve el instanceID, `GetPlayerFacing` da nil y la M pinta el arte con los
jefes, pero en el mapa 947. El **minimapa sí** pinta al grupo, aunque lo pinta el motor y un addon no
puede leer dónde pone cada punto. En retail la M enseña al grupo dentro de la mazmorra; en Forever no.

Pregunta: ¿se puede **reconstruir** una posición con otras señales?

## Lo que dice el api-db de Forever (taintlint `forever 1.60.1 (70755)`)

| API | Flag | Lectura |
|---|---|---|
| `Minimap:PingLocation(x, y)` | ninguno (args `AllowedWhenUntainted`) | un addon puede hacer ping |
| `Minimap:GetPingPosition()` | **ninguno** | candidato número 1: ¿devuelve números públicos? |
| `C_Minimap.GetViewRadius()` | ninguno | yardas del radio del minimapa: unidades del ping → yardas |
| `MINIMAP_PING` (unit, x, y) | **`SecretPayloads`** | los argumentos del evento llegan secretos |
| `UnitDistanceSquared` | ninguno | probablemente `nil` en instancia (restricción de posición, como retail) |
| `CheckInteractDistance` | ninguno | rangos fijos (unas 10 y 28 yd) |
| `C_Item.IsItemInRange` | ninguno | rangos por ítem (5…40 yd, lista Era de LibRangeCheck) |
| `UnitInRange` | `SecretReturns` | inútil para cálculos |
| `GetUnitSpeed` | `SecretWhenUnitStatsRestricted` | velocidad, puede que no en combate |

## Vías (de más a menos prometedora)

### A. El ping como baliza (odómetro)
Se hace `Minimap:PingLocation(0, 0)` justo donde estás. Si el ping se queda **fijo en el mundo** y
`GetPingPosition()` devuelve su desplazamiento **respecto a ti**, al caminar ese desplazamiento cambia.
Eso ya es una coordenada propia relativa al ping, en ejes del minimapa (norte arriba si no rota):
**posición y orientación sin `GetPlayerFacing`**.
- Duración: el aro se desvanece en ~5 s. Hay que medir si el valor sigue vivo después y, si no, si se
  puede **encadenar** (volver a hacer ping justo sobre el ping anterior para que el origen dure).
- Grupo: el ping de un compañero también mueve `GetPingPosition`. Eso da **su vector respecto a ti**
  directamente, aunque el payload del evento sea secreto.
- Coste: cada ping **se ve y se oye en el minimapa de todo el grupo**. Uno continuo no vale; uno por
  petición («¿dónde está el grupo?») o al entrar, quizá.
- Si los números salen secretos: probar el patrón sumidero (`SetPoint` con el secreto directo, como
  `StatusBar:SetValue`). Pintaría el punto sin leerlo, pero no deja acumular coordenadas.

### B. Trilateración con rangos (la malla del grupo)
Cada cliente con QDT mide su rango hasta cada compañero por tramos (`CheckInteractDistance`, ítems de
5/10/15/20/25/30/35/40 yd) y lo comparte por mensaje de addon. Con la matriz de distancias entre las 5
personas se saca la **forma** del grupo (MDS), pero **sin orientación ni origen** (puede estar girada o
en espejo). Es tosca (tramos de 5 yd) y en retail los ítems contra aliados se bloquean en combate.
Sirve para un radar relativo, no para pintar en la M.

### C. Hitos para anclar al arte de la M
Para pintar sobre el dibujo de la mazmorra hace falta un **origen y una escala por mazmorra**:
- origen = el punto de entrada (todos aparecen ahí al entrar);
- control = `ENCOUNTER_START` (estás junto al jefe N, cuyo pin de la M tiene posición conocida);
- calibración hecha a mano una vez por mazmorra (dos hitos dan escala y giro).
Necesita A (o algo equivalente) para moverse entre hitos.

### Descartadas
- **Navegación por estima** (velocidad × rumbo): sin `GetPlayerFacing` no hay rumbo.
- **Leer los puntos del minimapa / medir las placas**: el motor no lo expone y las placas son regiones
  restringidas (no se pueden medir).
- **Cámara**: no hay API de giro de cámara.

## La sonda: `/qdt check pos`

Se lanza una vez **en mundo abierto** (ahí `UnitPosition` sirve de verdad para comparar: unidades del
ping por yarda y ejes) y otra **dentro de una mazmorra**, en grupo, fuera de combate. Durante 30 s:
**caminar recto ~10 s, girar a la derecha ~90° y caminar ~10 s.** Se registra:
1. una foto inicial y otra final de las APIs de posición, la escala del minimapa y, para cada compañero,
   distancia, rangos e ítems;
2. `GetPingPosition` cada 0,25 s, junto con `UnitPosition`, `GetPlayerFacing` y `GetUnitSpeed`;
3. cada `MINIMAP_PING` (si es secreto o no, y si es tuyo o de otro);
4. a los 15 s, un ping encadenado sobre el ping anterior y la prueba del sumidero si salió secreto.

Lectura: `/reload` y luego `lua scripts/read-check-pos.lua`.

## Árbol de decisión

| Resultado dentro | Consecuencia |
|---|---|
| `GetPingPosition` público, cambia al andar y sigue vivo pasados 5 s | **Vía A viable**: prototipo de coordenada propia. Siguiente paso: escala con `GetViewRadius`, compartir con el grupo, calibrar una mazmorra |
| Público pero se congela o vuelve a 0 al apagarse el aro | A solo vale con pings encadenados. Medir el coste (spam visible, posible límite del servidor) |
| Secreto, pero `SetPoint` lo acepta | Punto efímero sobre el minimapa o la M, sin coordenadas acumuladas |
| `nil` / 0 / error | A muerta. Queda B (radar relativo tosco) si los rangos de ítem responden |
| Todo `nil` | No viable: se cierra con nota en el CLAUDE.md global |

## Resultados

### Tanda 1 — mundo abierto, Tarren Mill (2026-11-16), con `UnitPosition` como verdad
- **`MINIMAP_PING` NO existe en el cliente** (`Attempt to register unknown event`), aunque el api-db
  lo lista. Sin evento: los pings de otros solo se ven leyendo `GetPingPosition` (sondeo).
- **`GetPingPosition()` es público** y cambia mientras te mueves (96 valores distintos en 30 s).
- **Semántica medida** (encaja en los dos tramos, antes y después del giro):
  `GetPingPosition()` = posición **del ping respecto a ti**, ejes del minimapa (x = este, y = norte),
  en **fracción del diámetro del minimapa**: `k = 1 / (2 · C_Minimap.GetViewRadius())` por yarda
  (0,00214 teórico frente a 0,00217 medido; `viewRadius` = 233,3 yd con zoom 0 al aire libre).
  Con `UnitPosition` = (norte, oeste): `ΔpingX = +k·Δoeste`, `ΔpingY = −k·Δnorte`.
  ⇒ **tu posición respecto al origen, en yardas = (−px, −py) · 2 · viewRadius** (este, norte).
- **El ping sigue vivo ≥ 15 s** (el aro se apaga a los ~5 s; la lectura sigue siguiéndote).
- `PingLocation(0.144, 0.054)` (con las unidades de `GetPingPosition`) puso el ping nuevo **sobre
  el jugador**: sus argumentos van en otra unidad. Hipótesis: píxeles del minimapa desde el centro
  → la tanda 2 encadena con `(px·ancho, py·alto)`.
- El rumbo se puede **deducir del movimiento** (dos lecturas seguidas), sin `GetPlayerFacing`.

### Tanda 2 — dentro, Ruins of Lordaeron (party, Normal, 2999), solo, desde la entrada (2026-11-16)
- **`GetPingPosition()` = 0,0 fijo** en las 120 lecturas (30 s corriendo: `GetUnitSpeed` = 8,05).
  No es secreto ni `nil`: es **0 público**, igual que la restricción de posición de `UnitPosition`.
  ⇒ **Vía A muerta dentro.** El encadenado tampoco se pudo probar (pidió ping en 0,0).
- `PingLocation` no lanza error; `viewRadius` = 233,3 yd e `IsIndoors` = false también dentro.
- `GetUnitSpeed("player")` es **público** dentro y fuera de combate: da la distancia recorrida, pero
  sin rumbo no da posición.

Repetida con el encadenado en píxeles (tanda 3): también 0,0 antes y después.

### Tanda 4 — sistema de pings de 10.1 (`C_Ping`), dentro, solo (2026-11-16)
- `C_Ping` existe y `IsPingSystemEnabled()` = true; `C_Ping.SendMacroPing({type=Warning,
  targetToken="player"})` no lanza error desde el addon.
- **0 marcos nuevos** visibles para el addon a los 2 s y a los 6 s (`EnumerateFrames`): el marco del
  ping lo gestiona `C_PingSecure` y no se ve desde el addon (prohibido o creado antes).
- `GetPingPosition()` sigue en 0,0: este sistema no comparte nada con el ping del minimapa.
- Por diseño solo trabaja con unidades y con clics en pantalla: ninguna API devuelve coordenadas.
  ⇒ **descartado**.

### Lo que queda
- **Solo:** ninguna señal da posición ni rumbo → **no viable** un sistema de coordenadas propio.
- **En grupo (vía B, sin medir):** malla de rangos entre clientes con QDT → radar relativo tosco
  (tramos de unas 5 yd, sin orientación), no posiciones sobre la M. Requiere `/qdt check pos` con
  `party1` cerca para saber si `CheckInteractDistance` e `IsItemInRange` responden dentro.
