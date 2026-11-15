# 22 - Minimap Lens: coexistencia con EllesmereUI y ElvUI (parpadeos)

Investigacion de solo lectura (2026-11-15). EUI = EllesmereUIMinimap local (`F:\Games\World of Warcraft\_forever_\Interface\AddOns\EllesmereUIMinimap\`, abreviado `EUI_*`). ElvUI = v16.01 local (`F:\Games\World of Warcraft\_forever_\Interface\AddOns\ElvUI\Game\Shared\Modules\Maps\Minimap.lua`, abreviado `Minimap.lua:NNN`). **Verificado en local el 2026-11-15**: las lineas de ElvUI ya son exactas (antes eran ±3 desde WebFetch); ver §1 (marcas [OK]/[CORREGIDO]) y la subseccion «ElvUI verificado en local (v16.01)» en §4.

Nota de honestidad: los parpadeos NO se han reproducido ni medido. Los mecanismos de 1) son deduccion a partir del codigo; hay que confirmarlos con las sondas de 4).

## 1. Por que parpadea (mecanismo)

Hallazgo clave: **EUI no engancha `Minimap:SetSize/SetPoint/SetScale/SetZoom`** (solo engancha `SetParent`, y `SetPoint` solo si existe FarmHud). No hay bucle de hooks EUI<->QDT. El conflicto es de **ultimo en escribir gana, disparado por eventos y temporizadores**.

1. **Re-aplicacion completa de EUI en eventos que QDT tambien usa.** `ApplyMinimap` hace `SetScale(1.0)`, `SetSize(mapSize,mapSize)`, `SetMaskTexture`, `SetClampedToScreen` (`EUI_Minimap_Apply.lua:246-256, 540`). Se llama desde `ApplyAll` en cada PLAYER_ENTERING_WORLD (`EUI_Minimap_Lifecycle.lua:527-530`, diferido `C_Timer.After(0)`), al salir de combate (cola `ns.CombatQueue.Defer("ApplyAll")`, `EllesmereUIMinimap.lua:208-210`), y desde unlock mode/opciones/perfil (`Lifecycle.lua:586-606`). Si QDT agranda en PEW/zona-in o al salir de combate, EUI lo pisa un frame despues y QDT lo vuelve a poner: parpadeo grande-pequeno-grande. Entrar a mazmorra = justo PEW.
2. **El "empujon" de zoom fuerza un re-render doble, en ambos addons.** EUI: "Force the engine to re-render at the new size: nudge zoom" (`Apply.lua:543-546`):
   ```lua
   local curZoom = minimap:GetZoom()
   minimap:SetZoom(curZoom > 0 and 0 or 1)
   minimap:SetZoom(curZoom)
   ```
   ElvUI hace lo mismo en `UpdateSettings` (`Minimap.lua:592-598`) [OK, **con matiz**: solo si `E.MinimapSize ~= M.NeedsCanvasUpdate`, es decir una vez por cambio de tamano propio de ElvUI, no en cada llamada; lineas 593-597]. El propio comentario de EUI confirma que cambiar el tamano sin tocar el zoom deja el render viejo; cada `SetSize` + nudge = dos repintados del terreno. Si QDT hace su paso de `SetZoom` y EUI/ElvUI otro nudge, se ven tres. Animar el tamano por frame (tween) lo multiplica.
3. **Reseteos de zoom con temporizador que revierten el paso de zoom de QDT.** EUI "Auto Zoom Reset": `C_Timer.NewTimer(secs, ... Minimap:SetZoom(0))` (`EUI_Minimap_Buttons.lua:165-181`), re-armado por rueda/botones/ApplyMinimap (`Apply.lua:1206`). ElvUI: `hooksecurefunc(Minimap,'SetZoom')` -> `SetupZoomReset` -> `E:Delay(db.time, ResetZoom)` -> `Minimap:SetZoom(0)` (`Minimap.lua:343-369`, hook en `:368`) [OK]: **un hook sobre SetZoom que se dispara con CUALQUIER SetZoom, tambien el de QDT**. Resultado: el zoom de QDT salta a 0 pasados N segundos (solo si `resetZoom.enable`). [CORREGIDO/precisado: `resetZoom` es opcion del usuario, **por defecto DESACTIVADA** (`enable=false, time=3`, `Defaults/Profile.lua:218-221`); el asistente de instalacion la activa con 5 s (`General/Install.lua:525-526`). Un solo temporizador a la vez (guard `isResetting`, `Minimap.lua:358`) y `ResetZoom` ademas re-habilita/deshabilita los botones zoom (`:351-352`).]
4. **Guardia de padre de EUI.** `hooksecurefunc(minimap,"SetParent", ...)` revierte al instante cualquier reparent a otro padre que no sea `UIParent`/su `layoutFrame` (`Apply.lua:136-149`; en combate lo difiere con `QueueApplyAll`). Reparentar el Minimap a un contenedor de QDT se deshace en el mismo frame -> posible oscilacion si QDT reintenta. Ademas EUI ya reparenta el Minimap fuera de MinimapCluster y oculta el cluster con alpha 0 (`Apply.lua:111-135`).
5. **Posicion: EUI la fija solo en la primera activacion** (`Apply.lua:1208-1230`, `if not GetFFD(minimap).active`); despues "unlock mode owns positioning". Mover el Minimap con `SetPoint` no lo pisa salvo que se llame a `applyPos` (unlock mode) -- pero al restaurar, hay que devolver exactamente el anclaje previo (leer con `GetPoint` antes). ElvUI mueve el Minimap con su `MapHolder` y re-ancla `MinimapBackdrop` en `Minimap_PostDrag` (`Minimap.lua:683-686`) [OK]; sus hooks son sobre `MinimapCluster` (`SetPoint`->`ClusterPoint`, `SetSize`->`ClusterSize`, `Minimap.lua:875-876`; [CORREGIDO: no ~874-875]), no sobre Minimap [OK]. Ambos hooks difieren a `PLAYER_REGEN_ENABLED` si hay combate (`:696-699`, `:708-711`) y solo reescriben el cluster.
6. **ElvUI fuerza escala 1 del contenedor:** `hooksecurefunc(MinimapContainer,'SetScale',M.ContainerScale)` -> `if scale ~= 1 then self:SetScale(1)` (`Minimap.lua:722-726`; `SetScale(1)` inicial `:797`; hook `:803`) [OK; antes ~801]. Solo se instala si existe `MinimapCluster.MinimapContainer` (`:795-796`). Afecta a `MinimapContainer`, no a `Minimap:SetScale`, pero indica que cambiar escala en el arbol del cluster se revierte.
7. **Blizzard/Edit Mode:** el layout de `MinimapCluster` reajusta al cambiar el Minimap si esta dentro del cluster (ElvUI lo mantiene dentro; EUI lo saca). No verificado: sonda S6.
8. **Combate:** EUI y ElvUI difieren todo a `PLAYER_REGEN_ENABLED` (no tocar en combate); QDT debe hacer lo mismo y no solapar con su re-apply. [CORREGIDO para ElvUI: solo `ClusterSize`/`ClusterPoint` difieren a REGEN (`Minimap.lua:688-693, 695-720`); `UpdateSettings` (`:564-681`) no tiene guard de combate y **ElvUI NO reaplica nada en PEW ni al salir de combate**: `M:PLAYER_ENTERING_WORLD` solo hace zone text y el CVar de rotacion (`:740-751`).]

## 2. Tabla por addon

| Propiedad | EllesmereUI Minimap | ElvUI | Disparadores |
|---|---|---|---|
| Tamano (`SetSize`) | Si: `mapSize` (`Apply.lua:253`) | Si: `Minimap:Size(E.MinimapSize)` en `UpdateSettings` (`Minimap.lua:608`), `M.db.size` en `SetGetMinimapShape` (`:760-761`) | EUI: cada `ApplyAll`. ElvUI: Initialize, opciones, perfil |
| Escala (`SetScale`) | Si: fuerza 1.0 (`Apply.lua:246`) | Escala `MinimapCluster`/holders (`:669`, `:848`); hook que fuerza `MinimapContainer` a 1 (`:797-803`); `Minimap:SetScale` NO se toca | EUI: ApplyAll. ElvUI: hook inmediato sobre el contenedor |
| Posicion (`SetPoint`/`ClearAllPoints`) | Primera activacion + unlock mode (`Apply.lua:1209-1230`); hook solo con FarmHud (`Lifecycle.lua:627`) | `ClearAllPoints`+`Point` TOPRIGHT a `MapHolder` en UpdateSettings (`:606-607`); hooks en `MinimapCluster` (`:875-876`) | EUI: unlock/savePos. ElvUI: UpdateSettings, mover, combate->REGEN |
| Padre (`SetParent`) | Hook que fuerza `UIParent`/layoutFrame (`Apply.lua:139-149`), reparenta fuera del cluster | No reparenta Minimap [OK] (solo iconos/elementos, `:475-536`, `:558-560`) | EUI: inmediato (hook) + `C_Timer.After(0)` |
| Zoom (`SetZoom`) | Nudge en Apply (`:545-546`), restaura `savedZoom` si no activo (`:1198`), auto-reset (`Buttons.lua:178`), rueda (`Apply.lua:199`) | Nudge en UpdateSettings solo si cambia el tamano (`:593-597`); hook de `SetZoom` -> reset programado solo si `resetZoom.enable` (`:368`, `:357-366`) | EUI: ApplyAll/timer. ElvUI: cualquier SetZoom (hook) |
| Mascara (`SetMaskTexture`) | Si: 186178 o recorte (`Apply.lua:256`) | Si (`SetMinimapMask`, `:728-734`) | Cambios de forma/estilo |
| Alpha | Opacidad del mapa (`EBS._MapAlpha`), alpha 0 al cluster (`Apply.lua:129`) | Alpha 0 a regiones decorativas (`:211`, `:631`); nada sobre `Minimap:SetAlpha` | EUI: visibilidad/hover/FarmHud |
| Clamp | `SetClampedToScreen(true)` + insets (`Apply.lua:540-542`) | n/d | ApplyAll |
| `GetMinimapShape` | Lo define solo si es nil o suyo (`Apply.lua:260-267`) | Lo sobrescribe global (`:757-758`), solo si `minimap.enable` (`General/Initialize.lua:748-750`) | ApplyAll / Initialize |
| OnUpdate sobre Minimap | No (solo OnUpdate de FPS/botones) | No | - |
| Flag/API para "prestar" el mapa | **Ninguna publica.** `TEMP_DISABLED` es local y vacio ("call-site compat only", `EllesmereUIMinimap.lua:25`). Unico guiño: FarmHud (hooks de EUI lo respetan: `Lifecycle.lua:617-666`) | `E.private.general.minimap.enable` solo en carga (`Minimap.lua:792`; desactivarla exige `ReloadUI`, `General/Core.lua:791-792`); expone `M.MapHolder`, `M.ClusterHolder`, `M.Initialized`, no hay flag de cesion | - |

## 3. Estrategias para QDT (de mas a menos robusta)

1. **No tocar el Minimap real: segunda vista propia.** Si el cliente lo permite, otro frame tipo mapa (no hay segundo `Minimap` en la API; solo el widget unico). Probablemente inviable: `Minimap` es un widget singleton. Descartar salvo sonda positiva (S9). Pro: cero conflicto. Contra: casi seguro imposible.
2. **Detectar dueno y degradar (recomendada como capa de seguridad).** Detectar `ElvUI`/`EllesmereUIMinimap` cargados (`C_AddOns.IsAddOnLoaded`) o, mejor, **por sondeo**: `Minimap:GetParent()~=MinimapCluster`, `GetMinimapShape`, `ns`... Con dueno presente: modo "suave" (solo escala/alpha, sin reparent, sin SetSize) o aviso y desactivar. Pro: nunca pelea. Contra: la funcion pierde potencia.
3. **`SetScale` en vez de `SetSize`.** Escalar el Minimap (y su ancla) evita el re-render del terreno y el nudge de zoom (el contenido ya renderizado se estira). Ninguno engancha `Minimap:SetScale` (EUI lo fija a 1.0 solo en ApplyAll; ElvUI lo fuerza solo en `MinimapContainer`). Pro: un solo escalon, menos parpadeo, restaurar = `SetScale(1)`. Contra: pixelado/borroso si el terreno no se re-renderiza a mayor resolucion (no gana area visible, solo tamano); EUI lo revertira en su proximo ApplyAll; hijos (botones, textos) escalan tambien. Sondar S1/S4.
4. **Aplicar tras sus re-aplicaciones, con guard anti-recursion y re-aplicacion por eventos.** Escuchar PEW (+2 frames, despues del `C_Timer.After(0)` de EUI) y `PLAYER_REGEN_ENABLED`; reaplicar UNA vez por evento, con flag `applying` y comparando `GetWidth/GetScale` antes de escribir (no escribir si ya esta). `hooksecurefunc(Minimap,"SetSize"/"SetScale")` solo para detectar que otro lo cambia y entonces ceder, NO para re-escribir en bucle. Pro: funciona con ambos. Contra: carrera entre temporizadores; puede dejar un frame del tamano de EUI.
5. **No tocar zoom salvo necesidad y no nudge propio.** Hacer UN `SetZoom` (el paso pedido) y, si se necesita repintado, un unico nudge; y desactivar de forma explicita el reset ajeno: ElvUI `resetZoom` y EUI `zoomResetSeconds` revertirian el zoom (ver 1.3). Se puede detectar leyendo `GetZoom()` tras N s y no reintentar. Pro: menos repintados. Contra: no hay API para desactivar sus timers; solo observar.
6. **Reparentar a un contenedor propio: desaconsejada con EUI.** Su hook de `SetParent` lo revierte (`Apply.lua:136-149`) y reintentar crea oscilacion. Con ElvUI es posible pero rompe su `MapHolder`/mover. Pro: control total del clip/escala en ausencia de otros duenos. Contra: peor coexistencia.
7. **Desactivar sus hooks via flag:** no existe flag publico en ninguno. No hay nada que activar. Descartada.

## 4. Recomendacion y sondas in-game para F1

**Recomendacion:** capas. (a) Sin dueno detectado: SetSize + un SetZoom + mover, en un solo bloque, sin nudge propio salvo sonda S3, fuera de combate, guardando `GetPoint/GetParent/GetSize/GetScale/GetAlpha/GetZoom` previos. (b) Con EUI o ElvUI detectado: probar primero `SetScale` (estrategia 3) y, si el sondeo muestra pisoteo, modo degradado (solo alpha/aviso). (c) En ambos: reaplicar en PEW diferido y `PLAYER_REGEN_ENABLED` con guard anti-recursion; al detectar que otro cambia el tamano (hook de solo lectura), ceder y avisar. Restaurar al apagar/salir de mazmorra leyendo los valores guardados, no constantes. Nunca animar el tamano por frame.

**Sondas (cada una con EUI solo, ElvUI solo y sin ninguno):**
- S1. `SetSize` agranda y se mantiene? Medir `GetSize()` en +0, +1 y +2 s, tras `/reload` y tras entrar/salir de mazmorra (PEW). Contar cuantas veces cambia (hook `SetSize` de solo lectura con contador).
- S2. Contador de llamadas a `SetPoint/SetParent/SetZoom/SetScale/SetAlpha/SetMaskTexture` sobre Minimap con `hooksecurefunc` + `debugstack(2,1,0)` para ver QUIEN escribe tras nuestra aplicacion (confirma o refuta 1.1-1.4).
- S3. Parpadeo con y sin nudge de zoom propio (A/B): `SetSize` solo, `SetSize`+`SetZoom(z)`, `SetSize`+nudge. Capturar a video/frames. Verificar si el render queda viejo sin nudge.
- S4. `SetScale(2)` vs `SetSize(2x)`: aspecto, hijos, clip, y si EUI/ElvUI lo revierten (cuando y por que evento).
- S5. Zoom: aplicar el paso y leer `GetZoom()` a +5/+10/+30 s para detectar el auto-reset de ElvUI (`resetZoom`) y EUI (`zoomResetSeconds`).
- S6. `Minimap:GetParent():GetName()` y el tamano de `MinimapCluster` antes/despues del `SetSize`; ver si Edit Mode / ElvUI `ClusterSize` reacciona.
- S7. Probar `SetParent(QDTcontainer)` con EUI: confirmar que el hook lo revierte (y si hay oscilacion), y con ElvUI que `MapHolder` no se rompe.
- S8. Restauracion: tras apagar, comparar `GetPoint/GetSize/GetScale/GetAlpha/GetZoom/GetParent` con lo guardado, con cada addon; incluir /reload con el modulo encendido (el estado debe volver a la normalidad).
- S9. Confirmar que no existe un segundo widget de mapa utilizable (descarta la estrategia 1).
- S10. Combate: `InCombatLockdown()` y que `SetSize/SetPoint` del Minimap lancen o no taint/ADDON_ACTION_BLOCKED; confirmar diferido a REGEN.
- S11. En dungeon (restriccion de posicion): `GetMinimapShape`, mascara y rotacion con el Minimap agrandado.

### ElvUI verificado en local (v16.01)

Todo contrastado con `Minimap.lua` local (WoW Forever, `Interface 16001`). Resumen de veredictos: el doc acertaba en el fondo (no hay hooks de ElvUI sobre `Minimap:SetSize/SetScale/SetPoint/SetParent/SetAlpha`), pero **sobrestimaba la agresividad de ElvUI** en PEW/combate y en el zoom.

| Afirmacion previa | Veredicto | Evidencia |
|---|---|---|
| Hook sobre `Minimap:SetZoom` -> reset a 0 por temporizador | **OK, pero opcional y apagado por defecto** | `Minimap.lua:357-368`; default `enable=false, time=3` (`Defaults/Profile.lua:218-221`); la instalacion lo activa a 5 s (`Install.lua:525-526`) |
| Nudge de zoom | **OK, acotado**: solo al cambiar `E.MinimapSize` | `Minimap.lua:593-597` |
| ElvUI reaplica en PEW / al salir de combate | **ERRONEO** para tamano/posicion/zoom | PEW solo zone text + rotacion (`:740-751`); REGEN solo reordena el cluster (`:688-693`); `UpdateSettings` se llama en `Initialize` (`:939`) y desde `E:UpdateMinimap` (opciones/perfil, `Core.lua:1721`) |
| Hooks sobre `MinimapCluster:SetPoint/SetSize` | **OK** (lineas 875-876, no 874-875) | `Minimap.lua:875-876`; handlers `:695-720` |
| `MinimapContainer:SetScale(1)` forzado | **OK** (solo contenedor, no `Minimap`) | `:797`, `:722-726`, `:803` |
| Engancha `Minimap:SetSize/SetScale/SetPoint/SetParent/SetAlpha` | **No** (confirmado): solo `HookScript` de `OnShow/OnHide/OnEnter/OnLeave` y el `SetZoom` | `Minimap.lua:878-881`; unica escritura propia de tamano/ancla: `:606-608`, `:761` |
| LibDBIcon / botones | ElvUI **no gestiona botones LDB** (sin barra de botones): solo skin del tooltip `LibDBIconTooltip` (`Skins/Tooltip.lua:34`). Botones de Blizzard: reparenta a `E.HiddenFrame`/`Minimap` y los reescala individualmente (`:475-536`); mata zoom in/out (`:773-774`) | Si QDT agranda el Minimap, los iconos LDB quedan donde esten (hijos de `Minimap`, escalan con el si es `SetScale`) |
| Ramas Forever | Existen (`E.Forever = WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`, `General/Initialize.lua:111`) pero **solo cosmeticas**: menu (`Minimap.lua:68`, `:92`) y `killFrames` extra `DielFrame`/`MinimapCompassTextureUnderlay` (`:779-782`). Ninguna cambia tamano/zoom/hooks | No hay logica de zoom/escala distinta en Forever |
| Flag para saber que ElvUI controla el mapa | `E.private.general.minimap.enable` (`:792`) es privado de ElvUI; senal externa mas simple y robusta: **existencia del global `ElvUI_MinimapHolder`** (creado solo tras pasar ese `if`, `:843`) y `ElvUI_MinimapClusterHolder` (`:850`) | `M.Initialized=true` (`:807`) tambien, pero accesible solo via la tabla `ElvUI`/`E.Minimap` (no verificado como acceder) |

**Efectos para la estrategia de QDT (modo suave):**
1. Con ElvUI **no hay pelea de re-aplicacion**: ElvUI solo reescribe el Minimap al cargar y al cambiar opciones/perfil. QDT puede hacer `SetSize`/`SetScale`/`SetZoom` una vez y mantenerlo; basta restaurar al salir. Detectar por `_G.ElvUI_MinimapHolder`.
2. **Unico riesgo de zoom:** si el usuario activo `resetZoom`, cada `SetZoom` de QDT arma un `E:Delay(time)` que lo devuelve a 0 (3-5 s tipicos). Mitigacion: tras nuestro `SetZoom`, comprobar `GetZoom()` a `time+1` s y no reintentar en bucle; o documentar la opcion al usuario. Leer la config via `ElvUI` es posible pero no esta verificado aqui.
3. **`SetSize` desalinea el layout de ElvUI:** `MapHolder` y mover conservan el tamano de ElvUI (`holder:SetSize` solo en `:614`), y el Minimap esta anclado `TOPRIGHT` al holder (`:607`), asi que agrandar crece hacia izquierda/abajo y puede solapar el panel de datatexts. `SetScale` hereda ademas `MinimapCluster:SetScale(mmScale)` (`:669`) por ser hijo del cluster. Restaurar con los valores guardados (`GetPoint/GetSize/GetScale`), nunca con constantes.
4. **No tocar `MinimapCluster`/`MinimapContainer`** (hooks que revierten, `:722-726`, `:875-876`) ni `SetParent` del Minimap; si se toca el cluster en combate, ElvUI lo rehace en REGEN.
5. Si el usuario cambia opciones de ElvUI (mientras QDT tiene el mapa agrandado), `E:UpdateMinimap` reescribira tamano/ancla (`:606-608`) y hace nudge de zoom; QDT puede escuchar con `hooksecurefunc(Minimap,"SetSize")` de solo lectura para ceder.

## Fuentes

- EUI: archivos citados arriba (solo lectura).
- ElvUI v16.01 local: `F:\Games\World of Warcraft\_forever_\Interface\AddOns\ElvUI\Game\Shared\...` (Minimap.lua, Defaults/Profile.lua, General/Initialize.lua, General/Core.lua, General/Install.lua, Skins/Tooltip.lua). Version web original: <https://raw.githubusercontent.com/tukui-org/ElvUI/main/ElvUI/Game/Shared/Modules/Maps/Minimap.lua>
- Referencias de addons que agrandan/restauran el minimapa (no leidas en detalle): FarmMode (<https://github.com/paradosi/FarmMode>, dice guardar y restaurar posicion original y ser compatible con ElvUI/SexyMap, con guard de combate) y MountMapMove (curseforge `mountmapmove`, centra y escala el minimapa de ElvUI montado y lo devuelve al ancla original). No se encontro un patron documentado de "dueno unico"; las busquedas web no dieron fuentes utiles sobre SexyMap/Mappy/Leatrix. Pendiente: leer el codigo de FarmMode (FR/tarea para `addon-scout`) para su patron de guardar/restaurar.
