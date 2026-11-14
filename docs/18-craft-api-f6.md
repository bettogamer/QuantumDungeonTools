# 18 — Chuleta de API de Craft para la ventana principal (F6)

> Craft v2.50.0 vendoreado READ-ONLY (`QuantumDungeonTools/libs/Craft/`). Fecha: 2026-11-14.
> Todas las referencias `archivo:línea` están abiertas y verificadas. Rutas relativas a
> `libs/Craft/components/` salvo que se diga otra cosa. «(no probado)» = lectura de código, no medido
> in-game. Ejemplo real de ventana con sidebar: `Craft_Browser/Browser.lua` del repo de Craft (§12).

## 0. Reglas comunes (valen para todos los componentes)

- Firma uniforme: `Craft.X:Create(parent, config)` con `config` **siempre tabla con claves con nombre**
  (no hay argumentos posicionales de texto: `{ text = "..." }`, `{ title = "..." }`). `Create` devuelve
  la instancia; el frame real sale de `inst:GetFrame()` y **el anclaje/tamaño externo lo pones tú con
  `SetPoint`/`SetWidth`** sobre ese frame. Solo Flex y Grid son layout propio (§11); el resto no
  se auto-posiciona dentro de su padre.
- Los setters programáticos son **silenciosos** salvo los que se indican (Switch:SetChecked sí dispara).
- Tema: cada componente llama `Craft.Theme.resolve(parent, config, frame)` en su `Create`
  (p. ej. `Switch.lua:65`, `Select.lua:104`, `Section.lua:47`). Orden de resolución:
  `config.theme` > heredado subiendo por `parent:GetParent()…` hasta un frame marcado `_craftTheme` > tema
  global (`Theme.lua:423-467`). **Consecuencia: basta pasar `theme = ctx` UNA vez al `Window:Create` (marca
  su frame raíz, `Window.lua:158`) y todos los descendientes lo heredan.** QDT ya hace lo análogo hoy:
  `Craft.Theme.resolve(nil, { theme = ctx }, root)` (`modules/InstanceTracker/wow/UI.lua:1083`) y el
  contexto se crea con `Craft.Theme.context("QuantumDungeonTools", {...})` (`UI.lua:1227-1240`, idempotente
  por nombre, `Theme.lua:396-415`). `ctx` es privado de UI.lua; F6 necesita exponerlo (UI.lua ya publica
  `ctx` en la tabla de `UI.lua:1199`) o crear la ventana desde ahí.
- Si el padre NO está marcado (frame suelto sin pasar por Craft) y no pasas `theme`, el componente cae al
  tema global: colores y fuente de Craft, no los de QDT. Pasa `theme = ctx` ante la duda.
- Colores: los tokens son `t.foreground`, `t.mutedForeground`, `t.background`, `t.border`, `t.sidebar*`,
  `t.primary`… (`Window.lua:434-468`, `Sidebar.lua:413-436`). Un override de color por instancia es una
  **tabla literal `{r,g,b,a}`** (`Label.lua:18`) salvo `Button.tone` y `Sidebar` item `action.color`, que
  aceptan **nombre de token** (string) o tabla (`Button.lua:52-58`, `Sidebar.lua:1140`). No inventar hex:
  sale de los roles de la paleta (memoria del proyecto).
- Tamaños de fuente: fijos por componente (12 px «text-xs»: Sidebar `ITEM_FONT` `Sidebar.lua:48`, Select
  `Select.lua:37`, Tabs `Tabs.lua:43`, Section `Section.lua:32`, Button `Button.lua:20`). Solo `Label` admite
  `size`/`weight`/`font`/`flags` por instancia (`Label.lua:25-28`). Para texto grande/pequeño propio usa Label.
- Nada de `frame:Show()/Hide()` directo sobre la Window (§1).

## 1. Window — `components/Window.lua`

`Craft.Window:Create(parent, config)` → `Window.lua:109`. Claves de `config` (`Window.lua:113-138`, `154-161`,
`392`): `title`, `description`, **`header`** (default true; `false` = sin barra, `:116`), `width`/`height`
(default 640×420, `:161`), `minWidth`/`minHeight` (360×240, `:125-126`), `maxWidth`/`maxHeight`,
`movable`/`resizable`/`closable`/`closeOnEscape` (default true), `strata` (default capa `page` = DIALOG,
`:120`), `scale`, `name` (nombre global estable del frame; sin él es `CraftWindow_N` con contador compartido,
`:154`), `theme`, `growFrom`, `dock`, `onClose`, `onMoved(win,x,top)`, `onResized(win,w,h)`, `fontFlags`.

- **Cabecera propia**: `header = false` (FR-019) → no se crea title bar ni botón de cerrar; `title` y
  `closable` se ignoran (`:123`, `:280`). El contenido cuelga del frame inset 1 px por el aro (`:339-345`,
  `:460-462`). Arrastre desde tu cabecera: `win:EnableDragFrom(region)` (`:497`; sobrescribe `OnMouseDown/Up`
  de la región; no-op si `movable=false`). Botón de cerrar propio: `win:Close()` (dispara `onClose` y
  desvanece, `:773`) o `win:Hide()`.
- Con cabecera estándar: título + descripción + botón X (24 px, `:19`, `:307-333`); `win:SetTitle(t)`
  (`:479`), `win:SetDescription(t)` (`:484`); `win:GetTitleBar()` (nil si headless, `:477`).
- Contenido: **`win:GetContent()`** (`:476`) es el frame donde se monta todo; ancla tus hijos a él, no al
  root (`Browser.lua:110-112`). Resize: grip abajo-derecha de 16 px a nivel de frame +10 (`:348-375`);
  marca `_craftCornerInset` en el contenido para que `Scroll` aparte su riel (`:364`).
- Ciclo de vida: `win:Show()/Hide()/Toggle()/IsShown()` (`:761-770`) conmutan una señal con fade+zoom;
  **nunca `GetFrame():Show()`** (pelea con el bind de alpha/shown, `Browser.lua:445-448`). Se crea oculta
  (`:395`). `closeOnEscape` mete el frame en `UISpecialFrames` (`:378-380`).
- **Posición: `win:SetPosition(point, relTo, relPoint, x, y)` / `win:GetPosition()` / `win:Center()`**
  (`:536`, `:560`, `:565`), no `SetPoint` sobre el frame: el zoom re-ancla por CENTER en cada tick (`:517-528`).
  Tamaño: `win:SetSize(w, h, {animate=}` `:615`. Scale: `SetBaseScale` (`:739`).
- Trampa: la ventana tiene dos entradas de ratón (frame raíz `EnableMouse(true)`, `:163`) → bloquea el
  mundo detrás; es lo deseado. Ventana pensada para 640×420 mínimo 360×240; para 220 de sidebar sube
  `minWidth` (el Browser usa 600×400, `Browser.lua:26`).

## 2. Sidebar — `components/Sidebar.lua`

`Craft.Sidebar:Create(parent, config)` → `Sidebar.lua:106`. Claves (`:110-126`): `items`, `activeItem`/
`selection`, `size` (`"default"` 220 / `"compact"` 180 / `"wide"` 260, `:40-44`; altura de fila 32/28/48,
`:34-38`), `width`, `onSelect(id)`, `onClick(id, mods)` (si lo das, **tú** llevas la selección, `:1100-1103`),
`onDoubleClick`, `onContextMenu`, `onToggle`, y la familia de drag&drop (`draggable`, `onDrop`…). `items`
puede ser señal (reactivo, `:145-146`).

- **Anclaje**: el frame solo tiene ancho; tú lo anclas: `TOPLEFT`+`BOTTOMLEFT` al contenido y `SetWidth(220)`
  (`Browser.lua:119-122`). Hereda `t.sidebar` (fondo) y borde derecho de 1 px (`:165-173`).
- **Añadir ítems**: por config `items = { {id=,label=,icon=,section=,onClick=,children=,disabled=,muted=,
  tooltip=,action=,collapsible=,defaultOpen=,selectable=}, ... }` (`:868-872`; `item.section` abre un grupo
  nuevo automáticamente, `:397-400`) o en caliente `AddSection(label)` (`:837`), `AddItem(cfg)` (`:873`),
  `AddSeparator()` (`:1431`). Cambiar todo el árbol: `SetItems(items, opts)` (`:1995`, conserva expansión).
  Ejemplo con secciones: `Browser.lua:192-238`.
- **Selección**: `SetActiveItem(id)`/`Select(id)` (`:1499-1508`) es **silencioso** (no llama `onSelect`);
  `GetActiveItem()` (`:1510`). `onSelect(id)` solo se dispara por clic de usuario (`:1105-1107`). El `onClick`
  de ítem corre en ambos casos (`:1101`, `:1106`).
- **Cabecera/pie propios**: `GetHeader()` / `GetFooter()` (`:2091`, `:2096`): frames ocultos con altura 0;
  pon `SetHeight(n)` y llama **`RefreshLayout()`** (`:2104`) — `Browser.lua:125-126`, `:245-247`. Sin eso el
  scroll interno no se reancla.
- Trampa: la fila aparece activa con `t.sidebarAccent`/`sidebarAccentForeground` y peso Medium
  (`:538-548`); el resto de colores sale de `t.sidebar*`: no sirven overrides por ítem salvo `muted` (`:567`).
- Las filas se reciclan (pool): no guardes el frame de una fila (`:18-22`). Alto del contenido = suma de
  filas + 8 px por grupo (`:628-713`); con overflow aparece un riel de 4 px solo en ese caso (`:448-452`).

## 3. Tabs — `components/Tabs.lua`

`Craft.Tabs:Create(parent, config)` → `Tabs.lua:54`. Claves: `tabs = { {id=,label=,icon=}, ...}`
(`:132-136`), `defaultTab` (id o señal, `:151`), `onTabChange(id, prev)` (`:71`), `variant`
(`"default"` barra `t.muted` / **`"line"`** transparente + subrayado de 2 px, `:61`), `fill` (columnas
iguales, `:65`).

- Anclaje: tú anclas/dimensionas el frame; la barra mide 32 px y **crece en altura si las pestañas se
  envuelven** (`:86-90`, `:92-105`); el área de contenido llena el resto (`:118-120`).
- API: `AddTab(id, label, {icon=})` (`:171`), `SetActiveTab(id)` (`:492`, dispara `onTabChange`),
  `GetActiveTab()` (`:503`), `RemoveTab(id)` (`:511`), `SetTabEnabled(id, bool)` (`:567`),
  **`GetContentFrame(id)`** (`:552`: un frame por pestaña, llena el área; Tabs muestra/oculta solo el activo,
  `:176-179`), `GetContent()` (`:556`).
- Trampa: **la pestaña inicial se pinta sin llamar `onTabChange`** (`:138-157`, FR-070): si necesitas el
  efecto inicial, llámalo tú tras el `Create`. Un id repetido en `AddTab` se ignora (`:172`).

## 4. Section (grupo plegable) — `components/Section.lua`

`Craft.Section:Create(parent, config)` → `Section.lua:35`. Claves (`:39-44`): `title`, `divider` (borde
inferior, default true), `onToggle(expanded)`, **`collapsed`** (**default true = nace plegada**; pasa
`collapsed = false` para abrirla, `:44`).

- **Contenido**: se construye un frame hijo con su alto ya fijado y se entrega con
  **`section:SetContent(frame)`** (`:184`): lo reparenta, lo ancla TOPLEFT y le empuja el ancho
  explícitamente (`:187-192`). El alto del cuerpo se lee de `child:GetHeight()` (`:325-332`) → si cambia
  después, **`section:Refresh()`** (`:404`). `GetContent()` (`:195`) devuelve el contenedor interno.
- Plegado: `Toggle()` (`:343`), `SetExpanded(bool)` (`:347`, anima y dispara `onToggle`), `Expand()`,
  `Collapse()`, `IsExpanded()` (`:360-362`), `SetTitle(t)` (`:398`).
- **Dimensionado**: el frame de la sección tiene **ancho que le das tú** (ancla izq+der o `SetWidth`) y su
  **alto lo deriva él** (cabecera 36 px + cuerpo animado, `:29`, `:334-337`). Para apilar varias: ancla cada
  una al `BOTTOMLEFT` de la anterior; el alto animado re-fluye solo (no probado con 6+ secciones).
- Trampa: el ancho debe estar asignado; antes de tenerlo la cabecera no pinta (FR-099, `:53-58`). Crea la
  sección ya con su padre anclado, o haz `SetWidth` antes de `SetContent`.
- **Layout de 2 columnas** dentro de la sección: el hijo de `SetContent` es un frame tuyo con
  `Craft.Grid.new(child, {columns={"1fr","1fr"}, gap=…})` (§11) y celdas con Switch/Select.

## 5. Switch — `components/Switch.lua`

`Craft.Switch:Create(parent, config)` → `Switch.lua:40`. Claves (`:44-49`): `checked` (bool o señal
escribible, two-way), `disabled`, `size` (`"default"` 32×18 / `"sm"` 24×14, `:17-20`), `onChange(checked)`.

- **No trae etiqueta**: es solo el interruptor (frame 32×18 fijo, `:66`). La etiqueta es un `Craft.Label`
  al lado (o `Craft.Field`, no revisado aquí). Ancla tú el frame (suele ir a la derecha de la celda).
- API: `SetChecked(v)` (`:273`) **SÍ dispara `onChange`** (¡al contrario que Select!); `GetChecked()`
  (`:281`); `Toggle()` (`:288`); `SetEnabled(bool)` (`:293`, alpha 0.5).
- Trampa: para sincronizar sin disparar el callback usa una señal en `checked` (`Switch.lua:271-273`) o una
  bandera tuya `silent` alrededor de `SetChecked`. El estado inicial de `checked` no dispara nada.

## 6. Select — `components/Select.lua`

`Craft.Select:Create(parent, config)` → `Select.lua:55`. Claves (`:59-76`): **`options = { {value=,label=}, ... }`**
(`:60`, ver `:883-885`), `value`, `placeholder` (default `"Select..."`), `size` (`"default"` 32 / `"sm"` 28,
`:29-32`), `width` (fijo; **nil = llena el padre**, hay que anclarlo), `disabled`, `maxItems` (filas visibles
antes de scroll, 6, `:69`), `onSelect(value, label)` (`:395-396`), y modo múltiple (`multiple`, `values`,
`onChange(set)`, `:73-75`).

- API: `SetValue(v)` (`:922`) y `GetValue()` (`:928`) — **`SetValue` es silencioso** (no llama `onSelect`);
  `SetOptions(opts)` (`:932`, reconstruye); `SetEnabled(bool)` (`:939`); `Open()`/`Close()` (`:766`, `:816`);
  múltiple: `SetValues`/`GetValues` (`:912-920`).
- Dimensionado: alto 32/28 fijo (`:102-106`); ancho: `width` o ancla izq+der en tu celda de Grid (el
  panel desplegable mide ≥144 px, `:45`). El panel es overlay propio y **resuelve el tema del ancla al
  abrirse** (`Theme.lua:471-474`), por eso hay que pasar `theme` al root o cuidar el padre marcado (§0).
- Trampa: `value` que no esté en `options` se muestra como texto crudo (`:877`, `SetValue` degrada así).
  `options` y `value` aceptan señales (`:84-98`).

## 7. Scroll (+ ScrollBar) — `components/Scroll.lua`, `ScrollBar.lua`

`Craft.Scroll:Create(parent, config)` → `Scroll.lua:37`. Claves: `orientation` (`"vertical"` default /
`"horizontal"` / `"both"`, `:41`), `width`, `height` (`:52-53`), `onScroll(offsetY)` (`:46`). `ScrollBar`
es **interno** (`ScrollBar.lua:8`): lo crea Scroll, no se instancia a mano.

- Montaje: `scroll:GetFrame():SetAllPoints(container)` (`Browser.lua:363-364`) y `local child =
  scroll:GetScrollChild()` (`:226`). Tú pones **solo el alto** del hijo; **el ancho lo gestiona Scroll**
  (viewport − 8 px de riel, `:31`, `:78-80`). No fijes el ancho del hijo (peleaba y parpadeaba:
  `Browser.lua:367-372`). El riel (8 px) se reserva siempre (`:59-60`).
- API: `ScrollToTop()` (`:253`), `ScrollToBottom()` (`:259`), `SetScrollOffset(n)`/`GetScrollOffset()`
  (`:265`, `:293`), `SetScrollChild(f)` (`:239`). Rueda: 20 px por muesca (`:32`).
- Tabla de 100 filas × 9 columnas: **no existe componente tabla**. Patrón: un frame hijo del scroll con
  filas de alto fijo ancladas `TOPLEFT` a `child, 0, -(i-1)*rowH`; alto del hijo = `n*rowH`; columnas con
  anchos fijos o `Grid` por fila (`Grid:Layout()` manual, §11). 100 filas × 9 FontStrings = 900 regiones:
  asumible, pero **crea las filas una vez y reutilízalas** (no probado el coste; el Sidebar recicla filas
  igual, `Sidebar.lua:18-22`). La cabecera de columnas va **fuera** del scroll para que no se desplace.
- Trampa: si el contenido encoge con el scroll al final, Scroll ya reajusta el offset (FR-113, `:125-128`).

## 8. Button — `components/Button.lua`

`Craft.Button:Create(parent, config)` → `Button.lua:39`. Claves (`:44-61`): `text`, `size` (`"default"` 32 /
`"lg"` 36 / `"icon"`, `"icon-xs"`, `"icon-sm"`, `"icon-lg"`, `:20-26`), `variant` (`"default"`, secondary,
outline, ghost… ver `Button.lua:484` `SetVariant`), `disabled`, `icon` (nombre Lucide), `iconPosition`
(`"left"`/`"right"`), `onClick`, `tooltip` (string), `tone` (token o `{r,g,b,a}`), `fontFlags`.
API: `SetText` (`:450`), `SetEnabled` (`:469`), `SetVariant` (`:484`), `SetTone`/`GetTone` (`:495-502`),
`SetIcon` (`:510`), `SetSize` (`:517`). El ancho se adapta al texto; ancla tú.

## 9. Label — `components/Label.lua`

`Craft.Label:Create(parent, config)` → `Label.lua:12`. Claves (`:17-28`): `text`, `color` (`{r,g,b,a}`,
nil = hereda), `disabled`, `maxWidth` (elide con «…»), `width`+`wrap` (multilínea; `wrap` gana a
`maxWidth`, `:41-47`), `align`, `onClick`, `weight` (`"normal"|"medium"|"bold"`), `size` (px), `font`,
`flags`. API: `SetText` (`:200`), `SetWidth` (`:210`), `SetFontOptions` (`:240`), `GetTextWidth` (`:251`),
`SetColor` (`:256`), `SetEnabled` (`:262`). Sin `width`, el frame **se ajusta al texto** (una línea).
Trampa: da al frame un alto explícito si lo anclas por dos lados (`Browser.lua:157`, `:168` lo hacen).
Trampa de fuente: la fuente del tema se carga asíncrona; al primer arranque los anchos medidos pueden
estar mal hasta que Craft avisa → `Craft.Theme.onFontMetricsChanged(fn)` (`Browser.lua:479-481`).

## 10. Separator y Empty

- **Separator**: `Craft.Separator:Create(parent, {orientation = "horizontal"|"vertical"})`
  (`Separator.lua:15-19`). Línea de 1 px con `t.border`; **se ancla a ambos lados**
  (`Browser.lua:354-356`: `BOTTOMLEFT`+`BOTTOMRIGHT` de la cabecera). `SetOrientation` (`:83`).
- **Empty** (estado vacío del historial): `Craft.Empty:Create(parent, config)` → `Empty.lua:69`. Claves
  (`:74-85`): `title`, `description`, `icon` (Lucide), `mediaVariant`, `border`, `width`, `height`,
  `maxWidth`, `fontFlags`; también `media`/`content` (widgets propios, `:133-134`). API: `SetTitle`
  (`:318`), `SetDescription` (`:324`), `SetIcon` (`:359`), `SetContent` (`:366`), `GetHeight` (`:398`),
  `Relayout` (`:404`). Muéstralo/ocúltalo tú según haya runs.

## 11. Flex y Grid — `layout/` (no son componentes: motores sobre un frame contenedor)

Se usan como `Craft.Flex.new(container, cfg)` / `Craft.Grid.new(container, cfg)` (`Flex.lua:29`,
`Grid.lua:90`), `:Add(frame, itemCfg)`, `:Remove`, `:Clear`, `:SetConfig`, `:Layout()` (`Flex.lua:50-100`,
`Grid.lua:112-163`). **Llama `Layout()` tras añadir** y cuando cambie el ancho del contenedor (Tabs lo
hace en `OnSizeChanged`, `Tabs.lua:122-125`). Las medidas naturales se cachean en `Add` (`Grid.lua:122-128`):
da tamaño al frame **antes** de añadirlo.

- Grid: `{columns={"1fr","1fr"}, rows={"auto","auto"}, gap, rowGap, colGap, paddingH, paddingV}`
  (`Grid.lua:82-89`); pistas `"<n>fr"`, `"auto"` o px (`:29-41`). Item: `{col,row,colSpan,rowSpan,
  justifySelf,alignSelf}` (`:109-111`, 1-indexado, default `"stretch"`). Útil para los ajustes en 2
  columnas (fila = Label+control). Para ítems de altura distinta, fija `rows` en px.
- Flex: `{direction,wrap,justify,align,gap,paddingH,paddingV}` (`Flex.lua:18-27`); item
  `{grow,shrink,basis,alignSelf,order}` (`:48`). Útil para cabeceras (título a la izquierda, botones a la
  derecha).
- Ninguno ajusta el alto del contenedor: léelo con `Grid:GetContentHeight()` (`Grid.lua:283`) /
  `Flex:GetContentCross()` (`Flex.lua:338`) y aplícalo tú al frame antes de `Section:SetContent`.

## 12. Ejemplo real: ventana con sidebar y páginas (Craft_Browser)

Fuente: `craft/Craft_Browser/Browser.lua` (repo de Craft, solo lectura). Esqueleto:

1. Ventana headless con límites y persistencia: `Craft.Window:Create(UIParent, {header=false, width,
   height, minWidth, minHeight, strata, onResized, onMoved})` (`Browser.lua:77-92`). Posición guardada
   se restaura tras el `Create` (`:104-108`; ojo, ese snippet usa `SetPoint` directo; la API oficial es
   `SetPosition`, ver §1).
2. `local content = _win:GetContent()` (`:112`); todo cuelga de `content`.
3. Sidebar a la izquierda: `Craft.Sidebar:Create(content, {size="default", activeItem=...})` +
   `SetPoint TOPLEFT/BOTTOMLEFT` + `SetWidth(220)` (`:115-122`); cabecera propia con
   `GetHeader():SetHeight(48)` y arrastre con `_win:EnableDragFrom(hdr)` (`:125-143`); botón cerrar a mano
   (`:171-179`); ítems con `AddSection`/`AddItem{id,label,onClick}` (`:192-238`); `RefreshLayout()` (`:189`,
   `:247`).
4. Zona de contenido: frame anclado `TOPLEFT content (220,0)` → `BOTTOMRIGHT content` (`:298-300`);
   cabecera de 48 px con título/descripción en `Craft.Label` (`:303-351`); `Craft.Separator` (`:354-356`);
   `Craft.Scroll` bajo la cabecera con `SetAllPoints` (`:359-365`).
5. Cambio de página: `Navigate(pageId)` (`:399-441`): limpia los hijos del scroll child
   (`:409-412` `Hide()`+`SetParent(nil)`), ejecuta `page.render(_demoFrame)` (que devuelve `{height=,
   cleanup=}`), fija el alto del hijo (`:428-433`), `SetActiveItem(pageId)` (`:419`), `ScrollToTop()` (`:440`).
   Mostrar: `_win:Show()` y luego `Navigate` (`:449-453`).

**Para QDT conviene (propuesta, no es lo que hace el Browser):** construir **un frame por página una sola
vez** (hijos de la zona de contenido) y en `onSelect(id)` hacer `Show()` de una y `Hide()` del resto +
`SetActiveItem` en el sidebar; el patrón destruir-y-repintar del Browser re-renderiza cada visita y
asume páginas baratas. Si hay pestañas dentro de una página, `Tabs:GetContentFrame(id)` ya hace ese
Show/Hide por ti.

## 13. Trampas resumidas

1. **Tema**: `theme = ctx` en el `Window:Create`; los frames intermedios (`CreateFrame`) no rompen la
   herencia, pero un componente creado con `parent = nil` o `UIParent` pierde el contexto (`Theme.lua:437-449`).
2. **Colores por token**: Label pide tabla `{r,g,b,a}`; para seguir los cambios de tema léela de
   `ctx:get()` en tu callback `register`, o usa `Button.tone` (string de token). No hex a mano.
3. **Texto «posicional»**: nada es posicional, todo `config.text`/`title`/`label`; `AddTab(id, label)` y
   `AddItem{label=}` son los únicos con el texto fuera de `config` raíz (`Tabs.lua:171`).
4. **Callbacks**: Switch:SetChecked sí dispara `onChange`; Select:SetValue, Sidebar:SetActiveItem, Tabs
   inicial y Section creada **no**; `Tabs:SetActiveTab` y `Section:SetExpanded` **sí**.
5. **Fuente**: BettoGeo se carga asíncrona (`UI.lua:1233`); medir texto antes del aviso de métricas da anchos
   cortos → relayout en `Craft.Theme.onFontMetricsChanged`.
6. **Tamaños fijos** (Switch 32×18, Select 32/28 de alto, Tabs barra 32, Sidebar fila 32): diseña la rejilla
   en esos múltiplos; no hay forma de cambiar altura por config salvo `size`.
7. **No editar Craft**: si falta algo (p. ej. un componente tabla con columnas, o un Switch con etiqueta),
   FR en `craft/docs/requests/` y fallback propio mientras tanto (regla global).
