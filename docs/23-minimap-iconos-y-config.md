# 23 — Minimap Lens: iconos, botones y contenido del minimapa en Forever

Investigación para F0/F1 del hito M2 (`docs/plan-m2-minimap-lens.md`). Solo lectura de código; **nada medido in-game** salvo lo que dice el plan (SetSize/SetZoom valen en combate). Todo lo marcado «SONDA» está por verificar en F1.

Fuentes: LibDBIcon vendoreada (`QuantumDungeonTools/libs/LibDBIcon-1.0/LibDBIcon-1.0.lua`, MINOR 57) y FrameXML de Forever, rama `forever` de `Gethe/wow-ui-source` (`Interface/AddOns/Blizzard_Minimap/...`). Forever carga el `Minimap.xml` **Mainline** (familia) + overrides `Camelot/` (`Blizzard_Minimap.toc`: `[Family]\Minimap.xml`, `[Game]\Minimap.lua` para camelot). Es decir: `MinimapCluster` con `MinimapContainer`, Modo edición y marco de arte en atlas, igual que retail 12.x.

## 1. Estructura real del minimapa en Forever (lo que condiciona todo)

`Mainline/Minimap.xml` (URL base `.../forever/Interface/AddOns/Blizzard_Minimap/`):

| Frame | Padre | Anclaje | Línea |
|---|---|---|---|
| `MinimapCluster` | UIParent | `TOPRIGHT`, 256x256, sistema de Modo edición | `Minimap.xml:3-9` |
| `ZoneTextButton`, `Tracking`, `IndicatorFrame` (correo, crafteo), `InstanceDifficulty` | `MinimapCluster` | **a `ZoneTextButton`/cluster, NO a Minimap** | `Minimap.xml:24-46`, `Minimap.lua:357-362` |
| `GameTimeFrame` (calendario/reloj) | `MinimapCluster` | `TOPLEFT` de `ZoneTextButton` (+`-4,0`) | `Mainline/GameTime.xml:3`, `Camelot/GameTimeFrameTemplate.xml` |
| `AddonCompartmentFrame` | `MinimapCluster` | debajo de `GameTimeFrame` | `Camelot/AddonCompartment.xml:3-11` |
| `MinimapContainer` (215x226) | `MinimapCluster` | `TOP` +10,-30 | `Minimap.xml:47-50` |
| **`Minimap`** (198x198) | `MinimapContainer` | `CENTER` | `Minimap.xml:56-62` |
| `ZoomIn`/`ZoomOut`/`ZoomHitArea` | Minimap | offsets fijos desde el centro (88,-68 / 72,-84 / 77,-77), ocultos hasta `OnEnter` | `Minimap.xml:65-92`, `Minimap.lua:253-266` |
| `MinimapBackdrop` (+`MinimapCompassTexture` = el aro) | Minimap | `CENTER` de Minimap pero **tamaño fijo 215x226** | `Minimap.xml:101-123` |
| `ExpansionLandingPageMinimapButton` | `MinimapBackdrop` | `TOPLEFT` -3,-150 **del backdrop** | `Minimap.xml:128-139` |
| `ExternalEventURLButton` | `MinimapBackdrop` | `TOPLEFT` -7,-96 | `Minimap.lua:351-354` |
| `PlayerCoords` | `MinimapContainer` | `BOTTOM` de Minimap, y=-18 | `Minimap.xml:287-291` |
| `QueueStatusButton` (cola LFG/PvP) | UIParent (sistema de Modo edición) | por defecto «en el borde del Minimap» escalado con `MinimapCluster:GetEditModeScale()` | `Blizzard_QueueStatusFrame/Camelot/QueueStatusFrameOverrides.lua` (`UpdateDefaultAnchor`) |
| Dificultad de instancia | `MinimapCluster.InstanceDifficulty`, `Camelot/MinimapInstanceDifficulty.lua` lo **omite** (3 líneas: «Intentionally omits InstanceDifficulty») | — | — |

Consecuencias directas:

1. **`Minimap:SetSize` agranda solo el círculo (la máscara va con él), no el aro.** `MinimapCompassTexture`/`MinimapBackdrop` tienen 215x226 fijos y los reescribe `UpdateMinimapConfig` al cambiar `rotateMinimap` (`Camelot/Minimap.lua:28-50`). Los botones de zoom, el de la página de expansión y el de eventos cuelgan de offsets fijos: se quedarían en el sitio chico, dentro del mapa grande. Una lente con `SetSize` debe **ocultar o redimensionar el backdrop** (decisión de diseño; ver §3) o usar `SetScale` en `MinimapContainer`, que es lo que hace el propio Modo edición (`Minimap.lua:418-420`, `SetEditModeScale`) y arrastra aro, zoom, landing button y coords. Ojo: `SetScale` escala la **geometría**, `SetSize` cambia el tamaño en pantalla del mismo contenido; la sesión de viabilidad dice que SetSize muestra «lo mismo, más grande» — **SONDA S1**: `C_Minimap.GetViewRadius()` (yardas, `MinimapDocumentation.lua`) antes/después de `SetSize` y tras `SetZoom`.
2. **Mover `Minimap` (ClearAllPoints/SetPoint) NO mueve ningún botón de Blizzard del encabezado** (zona, tracking, correo, calendario, compartimento de addons, dificultad): están anclados al cluster. Sí se llevan consigo el aro, zoom, landing page, botón de eventos y los LibDBIcon (hijos de Minimap).
3. `MinimapClusterMixin:ResetFramePoints`/`SetHeaderUnderneath` reponen los anclajes **cacheados** de `MinimapContainer`, `ZoneTextButton`, `InstanceDifficulty`, `IndicatorFrame` (`Minimap.lua:376-391, 435-441`). Eso ocurre al cambiar el ajuste «cabecera debajo» del Modo edición, no por evento propio; la lente puede mover `Minimap` (hijo de `MinimapContainer`) sin que se lo toquen, pero si el jugador abre el Modo edición con la lente activa, `MinimapContainer` sí puede reponerse → **cerrar la lente al entrar en Modo edición** (SONDA S2).

## 2. Botones de addons (LibDBIcon)

- Cada botón es `CreateFrame("Button", "LibDBIcon10_"..name, Minimap)` (`:252`): **hijo de `Minimap`**, strata MEDIUM fija, nivel 8 fijo (`:257-260`). Consecuencia: heredan `Minimap:SetAlpha` y `Minimap:SetScale`; la opacidad de la lente los atenúa (SONDA S3 sobre si la opacidad de Blizzard del mapa también afecta a los hijos; en WoW la alpha es multiplicativa por la jerarquía, así que sí debería).
- **Posición** (`updatePosition`, `:156-174`): ángulo `minimapPos` (grados, 225 por defecto) y se coloca con `SetPoint("CENTER", Minimap, "CENTER", x, y)`. Radio **no fijo**: `w = Minimap:GetWidth()/2 + lib.radius`, `h = GetHeight()/2 + lib.radius` (`:163-164`), `lib.radius` por defecto **5** (`:19`; el comentario «Upgrade to 40» de `:711` solo reaplica el valor existente). Forma: `GetMinimapShape and GetMinimapShape() or "ROUND"` (`:161`); en Forever Blizzard **no define `GetMinimapShape`** (grep en `Minimap.lua` sin resultados; solo lo definen addons de minimapa cuadrado como ElvUI), así que normalmente `"ROUND"`; si otro addon lo define, los botones van a tabla de cuadrantes (`:138-150`, esquinas con radio diagonal).
- **No se recolocan solos al cambiar el tamaño.** `updatePosition` se llama en `createButton` (si `lib.loggedIn`, `:304`), en `PLAYER_LOGIN` (`:318-330`), `Show`/`Refresh` (`:402,416`), `SetButtonRadius` (`:459-465`), `SetButtonToPosition` (`:468`) y al arrastrar. No hay `OnSizeChanged`/hook sobre Minimap. Por eso tras `SetSize` hay que **re-posicionar a mano**: `for _, n in ipairs(icon:GetButtonList()) do icon:Refresh(n) end` (Refresh relee `db.minimapPos`, `Show/Hide` según `db.hide`). Al restaurar, lo mismo. (`SetButtonRadius` también recoloca todos, pero cambiaría un valor global de la lib y lo vería cualquier otro addon: no usarlo.)
- Eventos/callbacks: solo `LibDBIcon_IconCreated`, `LibDBIcon_IconCreated`→`lib.callbacks:Fire(...)` (`:315`) y el `IconCallback` de LDB para texto/icono (`:24`). **No hay evento «reposicionado»**. Botones creados con la lente activa nacen ya con el `Minimap:GetWidth()` agrandado (se colocan bien solos).
- Arrastre (`onUpdate`, `:196-207`): usa `Minimap:GetCenter()` y `GetEffectiveScale()`, así que con el mapa grande el arrastre y el ángulo siguen funcionando; solo el radio cambia. Guarda `db.minimapPos` en el ángulo, no en píxeles: **el ángulo es invariante al tamaño**, la restauración no pierde nada.
- Botones de addons que NO usan LibDBIcon (hechos a mano, p. ej. SMRT, doc 19) se anclan donde quieran: pueden quedar dentro del mapa grande o fuera. Imposible gobernarlos; **no tocarlos**.
- Compartimento de addons (`AddonCompartmentFrame`): es del cluster (arriba), no se mueve con el Minimap.

## 3. Botones de Blizzard: opciones al agrandar o mover

| Elemento | Qué le pasa con `SetSize`/mover `Minimap` | Notas |
|---|---|---|
| Zona (`ZoneTextButton`), tracking, correo/crafteo (`IndicatorFrame`), calendario (`GameTimeFrame`), compartimento, dificultad | **Se quedan** en el cluster (no dependen de Minimap) | Si el mapa grande se mueve lejos, quedan «huérfanos» en su esquina. Si crece sobre ellos, el mapa (strata LOW del cluster) puede taparlos. |
| Zoom +/- y `ZoomHitArea` | Siguen a Minimap pero con **offsets fijos** (centro+88,-68…) → quedan dentro del mapa en vez de en el borde | Aparecen solo al pasar el ratón. Con rueda del ratón (`OnMouseWheel`, `Minimap.lua:146-151`) no hacen falta. |
| Aro (`MinimapBackdrop`/`CompassTexture`) | Tamaño fijo 215x226; no crece | Ocultarlo mientras la lente está activa (`MinimapBackdrop:Hide()`) o escalarlo con la lente; **SONDA S4**: ¿es no protegido y se restaura con `Show()`? |
| `ExpansionLandingPageMinimapButton`, `ExternalEventURLButton` | Hijos del backdrop: siguen su offset fijo del tamaño chico | Se ocultan solos si se oculta el backdrop. |
| `QueueStatusButton` | Es del Modo edición, ancla por defecto «borde del Minimap» con la escala del cluster (no con `Minimap:GetWidth`) | Con `SetSize` queda donde estaba (dentro del mapa grande). Con `SetScale` del contenedor se recalcula (`UpdateDefaultAnchor`). Es importante dejarlo visible: es la señal de cola. |
| `PlayerCoords` | Sigue a Minimap por `BOTTOM` | Sin problema. |

**Recomendación (default):** la lente tiene su **marco propio de tamaño** y NO intenta llevarse los botones del encabezado: (1) `Minimap:SetSize` + `SetPoint` al ancla de la lente; (2) ocultar `MinimapBackdrop` (aro chico, zoom, landing, eventos) mientras dura; (3) dejar **donde están** zona, tracking, correo, calendario, compartimento y `QueueStatusButton` (el jugador debe seguir viendo cola/correo); (4) re-posicionar LibDBIcon con `Refresh` por botón. Alternativa más barata y más fiel a Blizzard si el diseño admite escalar en vez de redimensionar: `MinimapCluster.MinimapContainer:SetScale(s)`, que mantiene aro, zoom y coords coherentes sin ocultar nada, a costa de pisar el escalado del Modo edición (guardar `GetEditModeScale()` y restaurarlo). Esta alternativa **mueve/escala todo el contenedor**, no el `Minimap` solo; no resuelve los botones del cluster. Ofrecer «ocultar botones de addons mientras está activa» como ajuste (§5).

## 4. Contenido del minimapa

API documentada de Forever (`Blizzard_APIDocumentationGenerated/MinimapFrameAPIDocumentation.lua`, `MinimapDocumentation.lua`):

- **Widget `Minimap` (MinimapFrameAPI):** `GetZoom`, `GetZoomLevels`, `SetZoom`, `GetPingPosition`, `PingLocation`, `SetIconScale`, `SetMaskTexture`, `UpdateBlips`, `UpdateMouseoverAtPoint`, `SetUsingSoftCursor`, y los `SetArchBlob*`/`SetQuestBlob*`/`SetTaskBlob*` (`InsideAlpha`, `InsideTexture`, `OutsideAlpha`, `OutsideTexture`, `RingAlpha`, `RingScalar`, `RingTexture`). **No figuran** `SetBlipTexture`, `SetPlayerTexture`, `SetPOIArrowTexture`, `SetStaticPOIArrowTexture` en la documentación generada: no asumir que existen; **SONDA S5** (`type(Minimap.SetBlipTexture)` etc.). `SetMaskTexture` sí existe y Blizzard lo usa (`Camelot/Minimap.lua:23-24`, atlas `ui-hud-minimap-frame-generic-mask`, redondo en ambos modos). Una máscara cuadrada exigiría **definir `GetMinimapShape`** (afecta a LibDBIcon y a otros addons: fuera de alcance, riesgoso).
- **`C_Minimap` (namespace):** `GetNumTrackingTypes`, `GetTrackingInfo(spellIndex)`→`{name, texture, type, subType, spellID}`, `GetTrackingFilter(index)`, `SetTracking(index, on)`, `ClearAllTracking`, `IsFilteredOut(filterType)`, `GetViewRadius()` (yardas visibles), `SetDrawGroundTextures`/`GetDrawGroundTextures`, `SetIgnoreRotateMinimap`/`IsRotateMinimapIgnored`, `SetMinimapInsetInfo`/`ClearMinimapInsetInfo`, `GetUiMapID`, `ShouldUseHybridMinimap`, `IsInsideQuestBlob`.
- **CVars** (usados por Blizzard en `Minimap.lua`): `rotateMinimap` (`:483`, y `CVarCallbackRegistry` repinta el aro), `minimapShowPlayerCoords` (`:487`), `coordsByTenths`, `minimapTrackingShowAll` (`:733`, decide qué tipos lista el menú de tracking), `minimapTrackedInfov4` (bitfield del tracking activo, `:885`).
- **Tracking en el menú de Blizzard:** `MiniMapTrackingButtonMixin` itera `C_Minimap.GetNumTrackingTypes()`/`GetTrackingFilter` (`Minimap.lua:741-775`) y escucha `MINIMAP_UPDATE_TRACKING` (`:727`). Es el evento para saber que otro addon o el jugador lo cambió mientras la lente está activa.

**Secret / protegido en 12.1.5 y Forever (taintlint `db/apidb-forever-1.60.1-70755.json`, `apidb-12.1.5-70391.json`):** toda `C_Minimap.*` (`GetTrackingInfo`, `SetTracking`, `GetTrackingFilter`, `IsFilteredOut`, `IsInsideQuestBlob`, `SetDrawGroundTextures`, `SetIgnoreRotateMinimap`, `SetMinimapInsetInfo`, `GetDefaultTrackingValue`, `GetPOITextureCoords`) solo lleva `SecretArguments = "AllowedWhenUntainted"` = **solo afecta a los argumentos secretos**, no a los retornos; **ningún `Secret*` ni `Requires*` en los retornos** y las funciones no están marcadas protegidas. Los métodos del widget `Minimap` no están en la db (la db es de `C_*` y globales): pero el doc generado tampoco les pone flags. Conclusión: **no hay riesgo de secret en leer/guardar/restaurar tracking**; no se ve restricción de combate (el plan ya midió `SetSize`/`SetZoom` en combate). `SetCVar` en combate: algunos CVars están protegidos en combate en retail, **SONDA S6** antes de usar CVars.

### Qué podría configurarse SOLO mientras la lente está activa

| Candidato | Viable | Seguro restaurar | Veredicto |
|---|---|---|---|
| Ocultar tracking de hierbas/minas/etc. (`C_Minimap.SetTracking(i,false)` por tipo) | Sí | **Riesgo medio**: es estado **persistente de la cuenta/personaje** (`minimapTrackedInfov4`); si el cliente cae o el jugador hace `/reload` con la lente activa sin haber restaurado, queda cambiado. Mitigación: guardar copia en `ns.db` **antes** de tocar y restaurar en `PLAYER_LOGOUT`/`PLAYER_ENTERING_WORLD`/cierre de lente. Los tipos «siempre activos» y «condicionales» (`MinimapConstants.lua`) no se deben tocar. Otros addons que cambien tracking a la vez pueden pisar o ser pisados (`MINIMAP_UPDATE_TRACKING`). | **Opcional, apagado por defecto**, tras F1 |
| Opacidad del mapa (`Minimap:SetAlpha`) | Sí (en el plan) | Trivial, no persistente; guardar alpha previo | Sí |
| Zoom (un paso) | Sí (plan) | Guardar `GetZoom()`; `SetZoom` | Sí |
| `SetIconScale` (tamaño de los blips) | Sí | Valor original por `MinimapCluster:SetIconScale` (Edit Mode); leerlo no hay getter documentado → SONDA | Opcional |
| `SetArchBlob*/QuestBlob*/TaskBlob*Alpha/RingScalar` | Sí (efecto visual en el mapa mundial/zona; **en mazmorra casi no hay blobs**) | No hay getters → no se pueden guardar | **No** (poco valor, no restaurable) |
| `SetDrawGroundTextures` | Sí | Hay getter (`GetDrawGroundTextures`) | Poco valor en mazmorra; opcional |
| `rotateMinimap` | Sí, vía CVar | Persistente; reaplica aro | **No** (preferencia del jugador, y fuerza `UpdateMinimapConfig`) |
| `SetMaskTexture`/forma, `SetPlayerTexture`, blips custom | Máscara sí, pero rompe el aro; textura del jugador irrelevante (sin posición en instancia) | — | **No** |

## 5. Ajustes propuestos para la página del módulo (recomendación)

1. Interruptor del módulo, **atajo** (aviso Teclado › Atajos › AddOns) y botón «Probar» — ya decididos en el plan.
2. **Tamaño** (deslizador, ~1.5×–3× del original; el default ~2× del plan) y **Opacidad** (30–100 %, default 100 %) — ya decididos; los límites finales tras S1/S3.
3. **«Subir un paso de zoom»** (casilla, activa): decidido (punto 3 del plan).
4. **«Ocultar botones de addons mientras la lente está activa»** (casilla, **desactivada**): oculta los `LibDBIcon10_*` con `Hide()` (no cambia `db.hide`, así que no ensucia la config del otro addon) y los vuelve a `Show()` según `db.hide`. Alternativa por defecto sin ocultar: `Refresh` y listo.
5. **«Ocultar el marco de Blizzard (aro y botones de zoom)»** (casilla, **activa**): necesaria si se usa `SetSize` (§1.1).
6. **«Cerrar al abrir el Modo edición»**: no es ajuste, es regla fija (S2).
7. Opcional, tras F1, **«Ocultar seguimiento de recursos»** con lista de tipos (apagado). Mostrarlo en «Avanzado» con aviso de que cambia el seguimiento del personaje mientras dura.
8. No ofrecer: rotación, forma, máscara, texturas de blips, blobs, ni mover botones de Blizzard.

## 6. Sondas para F1 (`/qdt check m2`)

Todas con `pcall`; reportar `type()` del retorno y nunca operar secretos sin `issecretvalue`.

- **S1** `C_Minimap.GetViewRadius()` y `Minimap:GetZoom()/GetZoomLevels()` antes/después de `SetSize(2×)` y `SetZoom(+1)`: ¿cambian las yardas visibles? (confirma «misma zona, más grande»).
- **S2** Anclajes: volcar `GetNumPoints`/`GetPoint(i)` de `Minimap`, `MinimapContainer`, `MinimapBackdrop`, `GameTimeFrame`, `ZoneTextButton`, `QueueStatusButton`, `AddonCompartmentFrame` y `GetEffectiveScale`; mover `Minimap`, restaurar y comparar byte a byte; abrir el Modo edición con la lente activa y ver qué se repone; `EditModeManagerFrame` abrir/cerrar como arista de cierre (`EventRegistry` `EditMode.Enter`).
- **S3** `Minimap:SetAlpha(0.5)`: ¿atenúa blips, aro, zoom y los `LibDBIcon10_*`? (`GetEffectiveAlpha()` de un botón).
- **S4** `MinimapBackdrop:Hide()/Show()` en combate y fuera: ¿ok, y `MinimapCompassTexture` visible tras restaurar? También `GetSize()` tras cambiar `rotateMinimap` con la lente activa.
- **S5** `type(Minimap.SetBlipTexture / SetPlayerTexture / SetPOIArrowTexture / SetStaticPOIArrowTexture / SetIconScale / SetArchBlobRingScalar)` y `type(GetMinimapShape)`.
- **S6** `C_Minimap.GetNumTrackingTypes()`; por cada índice `GetTrackingInfo(i)` (name/spellID/type/subType) y `GetTrackingFilter(i)`; `GetCVar("minimapTrackedInfov4")`. En combate: `pcall(C_Minimap.SetTracking, i, state)` con el mismo estado (no-op) para ver si lanza; luego `SetCVar` en combate sobre un CVar inocuo (`pcall`).
- **S7** Forever: ¿`AddonCompartmentFrame` y `QueueStatusButton` se ven realmente? (`IsShown`, `GetParent():GetName()`); con LibDBIcon cargado, listar `icon:GetButtonList()` y la posición de cada botón antes y tras `SetSize` + `Refresh`.
- **S8** `Minimap:GetWidth()` tras `SetSize` y que `Refresh` use el ancho nuevo (radio = ancho/2 + 5): comprobar solapes de botones contra el borde del mapa grande.
- **S9** Restauración con otros addons de minimapa (SMRT, ElvUI si hay): comparar `GetPoint`/`GetSize`/`GetZoom`/alpha tras apagar la lente.
