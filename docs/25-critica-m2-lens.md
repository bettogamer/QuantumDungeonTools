# 25 · Crítica de cierre M2 «Minimap Lens» (2026-11-15)

Encuadre: ¿la página del módulo y la lente puesta se leen a la primera y siguen el artboard AppLens / paleta B?

Capturas recibidas:
- `WoWScrnShot_111526_214418.jpg`: página **Instance Tracker** (Resumen), no es M2. Solo sirve para ver que la fila «Minimap Lens» del sidebar existe, sin «PRONTO», con icono de mapa. Sin hallazgos.
- `WoWScrnShot_111526_214828.jpg`: página **Minimap Lens** (AppLens) con la **lente activa** al 200 % / 55 % sobre el minimapa (Thousand Needles) y EllesmereUI detectado (modo suave). No se ve el toast LensAviso ni el modo mover.

Ya revisado, no repito: Switch (docs/24).

## Conviene (arreglar antes de cerrar)

### 1. El texto de Convivencia se corta justo en la promesa — 🟡
- **Se ve**: «…the lens re-applies after it, without fighting. If it still overri…» (elipsis en el borde de la tarjeta). Lo que se pierde es «you get one warning».
- **Problema**: legibilidad; la frase truncada es la que dice qué pasa si falla. La versión ElvUI (`LENS_P_HELP_ELVUI`) es igual de larga y se cortará igual. En español (`LENS_P_HELP_EUI`, 2 líneas de concatenación) también.
- **Código**: `Page.lua:378-379` (`P.ownerHelp` una sola línea, sin ancho ni alto para 2 líneas); textos en `Locale.lua:200-203` y `495-498`.
- **Propuesta (mía)**: acortar los textos a ≤ ~95 caracteres: «EllesmereUI recoloca el minimapa al entrar: la lente se reaplica sola. Si lo pisa, un aviso.» **Alternativa**: `P.ownerHelp` con `SetWidth(cardW - …)`, `SetWordWrap(true)` y subir la altura de la tarjeta (`buildCoexist`, `card(...)` de ~l.370) para 2 líneas.

### 2. El subtítulo de «Tamaño» se corta — 🟡
- **Se ve**: «Compared to the normal mi…» (la columna izquierda pierde 150 px de slider + 42 de valor).
- **Problema**: legibilidad; Opacidad cabe porque su texto es corto. El texto es el único aclarador de qué significa 200 %.
- **Código**: `Page.lua:253-256` (la pista se ancla al control con `RIGHT` y recorta); `Page.lua:23` (`SLIDER_W` 150, copiado del artboard); texto `Locale.lua:183`.
- **Propuesta (mía)**: pista más corta, «Vs. the normal minimap» / «Sobre el minimapa normal». **Alternativa**: `SLIDER_W` 120 (hay holgura: la columna derecha de Opacidad también está apretada).

## Pulido

### 3. Etiqueta MODO SUAVE con el borde en oro pleno — ⚪
- **Se ve**: «SOFT MODE» con borde dorado más fuerte que la etiqueta de tecla.
- **Código**: `Page.lua:150` usa `C.gold` como color de borde; `Page.lua:134` y `MainWindow.lua:417` usan `C.goldTag` para el mismo tipo de etiqueta.
- **Propuesta**: `kit.setTag(P.ownerTag, L.LENS_P_SOFT, C.gold, C.goldTag)`.

### 4. La tecla «,» casi no se lee en su etiqueta — ⚪
- **Se ve**: una coma diminuta en una caja de 16 px junto a «Toggle the lens».
- **Código**: `Page.lua:132-134` (`kit.setTag(P.keyTag, key, …)`).
- **Propuesta**: mostrar teclas de un solo signo con nombre legible (`,` → «, (coma)» o `,` entre comillas) o ancho mínimo de la etiqueta. Solo afecta a signos; el resto de teclas se leen bien.

### 5. Pestaña única «Summary» — ⚪
- **Se ve**: una sola pestaña subrayada bajo el título.
- **Código**: `Page.lua:431` (`Craft.Tabs` con una sola entrada).
- **Matiz**: es la misma estructura que la página del Instance Tracker y el artboard AppLens la dibuja así. Si hay decisión de paridad, es "descartado"; si no, quitar la pestaña y ganar 30 px. No lo toco sin decisión del owner.

## Lo que se ve bien (no tocar)
- Jerarquía: MÓDULO → LENTE → ATAJO → CONVIVENCIA, con el interruptor y «Cerrar la lente» (primario dorado) frente a «Mover la lente» (outline). Una sola acción primaria por tarjeta.
- Puntos dorados en Tamaño y Opacidad = «cambiado del defecto»; coherentes con «2 settings changed from their default» y «Reset the lens ›».
- Colores: todo sale de roles de paleta B (muted, cream, gold, hairline, hairlineSoft). No hay hex a mano en `Page.lua`.
- Lente puesta al 55 %: mapa legible sobre el mundo, iconos de rastreo vecinos visibles, no tapa ni la ventana ni la barra de acción.

## Lo que NO toqué
- Toast LensAviso y modo Mover: no estaban en las capturas. **Pedir captura de ambos** (`/qdt lens notice soft` y «Move the lens») si se quiere cierre visual completo.
- Hueco vacío bajo CONVIVENCIA: es el fin del contenido; no es defecto.
- Página Instance Tracker (captura 1): fuera de encuadre.
- Valores por defecto de tamaño/opacidad (260 % / 100 %): decididos en plan §F5.

Cierre: hallazgos 1-2 bloquean el «cierre visual»; 3-5 pueden ir a pulido. Cada uno se marca «resuelto en <commit>» por quien lo arregla.
