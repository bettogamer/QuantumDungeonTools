# Crítica del widget HUD, estado "En curso" — 2026-11-13

Encuadre: jerarquía, flujo de lectura (izq = ganancias, der = estado), contraste del texto apagado sobre fondos claros,
ritmo de espaciado, fila RARE y roturas probables in-game (nombres largos, español). Captura: lienzo `11.png` (estado
En curso, sin instancias/hora); comparación con `8.png` (in-game, versión anterior con tag). Complementa
`docs/13-critica-widget-live-badge.md` (no repito RARE a 9 px ni el padY de tags). No hay D-N vigentes en
`docs/ux-pantallas.md`; me ciño a las decisiones del owner de hoy. Px leídos de captura, ±2.

## Resumen
Contesta al norte a la primera: reloj 16:22 / 31:40 (turquesa = por delante), jefes 3/6, barra. Quitar el tag de
instancias ha limpiado la fila de totales y la lista de jefes sube compacta. Problemas reales: (1) el texto `muted` es lo
que más información lleva y lo que menos contraste tiene; (2) las filas de jefes/RARE pueden desbordar por la izquierda
con nombres largos y no hay guarda; (3) el flujo "izquierda = ganancias" se rompe a medias.

## Hallazgos (priorizados)

### 1. `muted` 93B6C2 sobre fondo claro: la línea "Jefes 3/6 · vs. récord" y el sufijo de la rep se pierden — 🟡
- Se ve: en el lienzo (fondo verde-oliva/beige claro abajo a la derecha) "Jefes", "vs. récord", "/ 31:40", "Nv 54 · 62% ·
  descanso 18%" y "Undercity" son lo más pálido y de menor tamaño (11-12 px). En `8.png` (fondo oscuro) se leen bien;
  el lienzo es el caso pesimista (esquina clara). "/ 31:40" es el récord, dato clave, y está en muted a 16 px: ok por
  tamaño; "vs. récord" (12 px) no.
- Contra: legibilidad + memoria de estilo (colores saturados, Medium mínimo). `muted` es azul-gris desaturado de
  luminancia media: sobre beige claro, contraste bajo.
- Código: `Style.lua:25` (`muted`), usado en `UI.lua:515, 534, 551, 585`; `repText` `UI.lua:187-190`.
- Propuesta: aclarar y saturar `muted` hacia `B4D8E4` (misma familia, +luminancia; sigue por debajo de cream F7EDDC, la
  jerarquía se mantiene por tono frío y tamaño). Alternativa: dejar el color y dar a las líneas muted (`info`, `rep`,
  `name`) sombra más dura, `C.shadow` a=1 con offset 1,-1 ya existente; más barato pero no arregla fondos beige.
  No tocar `tickIdle` (marcas de split no alcanzados) en este cambio.

### 2. Filas de jefe/RARE sin tope de ancho: un nombre largo se sale por la izquierda — 🟡
- Se ve: nombre 15 px + `[12:53]` + delta, anclados a la derecha. Hoy "Viktor the Vile" ocupa ~190 de 340 px. No se ve
  el límite, pero en español ("Comandante de la Guardia de Lordaeron", "Capitán de Lordaeron" rare + tag RARE + tiempo)
  una fila supera el ancho del widget.
- Por qué: `chain` (`UI.lua:106-119`) solo ancla piezas a la derecha; `SetWordWrap(false)` (`UI.lua:59`) pero sin
  `SetWidth` en `name`; la fila (`newRow`, `UI.lua:194`) mide `S.width` y no recorta. El nombre invade la izquierda y
  puede sobrepasar el borde de la ventana o chocar con el borde del arrastre. Contraste: la fila de totales SÍ tiene
  truncado con "..." (`UI.lua:590-599`); las de jefe no, incoherencia de diseño.
- Propuesta: replicar el patrón de totales: tras fijar `time`/`delta`/`tag`, `r.name:SetWidth(min(natural,
  S.width - restoAnchos - gaps))` (ancho 0 → natural primero, como `UI.lua:593-594`). Para RARE el tag va después del
  nombre; el orden de recorte es: nombre primero, nunca tag ni tiempo. Pedir captura con nombre largo para confirmar (no
  verificable desde la imagen).

### 3. Flujo izquierda/derecha: bloque de ganancias a la izquierda, resto alineado a la derecha — ⚪/🟡
- Se ve: reloj, nombre, `Jefes 3/6`, jefes y RARE terminan en el borde derecho; XP, monedas y rep están pegados al borde
  izquierdo de la barra. La mirada hace zigzag: derecha (reloj) → centro (barra) → izquierda (+18.450 XP, +4 12) →
  derecha (jefes). Es decisión de hoy (totales a la izquierda del borde de las barras): no la reabro.
- Matiz real: la línea de XP tiene **dos** extremos (izq "+18.450 XP en la run", der "Nv 54 · 62% · descanso 18%") y
  la de totales solo uno, con 3 filas debajo de la barra de 8 px el bloque izquierdo se lee como una ficha única. OK.
  Lo que sí falta: la columna izquierda de totales termina a ~320 px del borde derecho; en una ventana de 340 px con
  jefes cortos (ej. "Rath'mael") queda un hueco enorme entre totales y jefes. Es el ritmo del diseño, no un bug.
- Propuesta: no cambiar. Anotar solo: no meter nada más a la derecha de la fila de totales (el hueco es lo que la
  separa de los jefes).

### 4. Ritmo vertical irregular entre bloques — ⚪
- Se ve: header → reloj (~gap 6) → info "Jefes" (gap 6, pegado al reloj) → barra (gap 12) → XP (gap 8) → totales
  (gap 8) → jefes (gap ~4+) → RARE (+4). Los saltos 12/8/8/4 no siguen un patrón; la barra queda algo más aislada
  del texto de jefes que del XP.
- Código: `place(W.bar, S.barH, S.gap)` extra=gap (`UI.lua:567`), XP extra=2 (`UI.lua:576`), extras extra=2
  (`UI.lua:613`), `bossTop` 4 y `rareTop` 4 (`Style.lua:85-86`). Todos los extras sueltos (2) son números a mano en
  `UI.lua`, sin token.
- Propuesta: tokenizar `extraXP = 2` y `extraTotals = 2` en `Style.SIZE`; si se quiere simplificar, `bossTop` 4→6 deja
  una cadencia 6/6/12/8/8/6 más legible que el pelado actual. Cambio opcional, pedir revisión in-game.

### 5. RARE: separación visual del bloque de jefes bien resuelta; el nombre queda más tenue que los jefes — ⚪
- Se ve: tag a la izquierda, nombre turquesa ("Lordaeron Captain") a 13 px; los jefes normales en cream 15 px. El rare
  usa tono `ahead`/turquesa porque `tone` = vivo. Se lee como "extra, no cuenta", que es lo correcto.
- Atención: con rare **muerto** el nombre toma el tono del estado y el tag `muted`; el tag (10 px) sobre fondo claro es
  el punto más débil de la ventana (ver `13`). Sin captura de rare muerto/vivo juntos, no abro hallazgo.
- Código: `UI.lua:626-636`, `Style.lua:124-126`.

### 6. Cabecera: "Normal" y nombre — ⚪
- Se ve: nombre muted 12 px + tag `Normal` (sand sobre goldSoft). Con nombres largos en español ("Ruinas de
  Lordaeron" ~ mismo ancho; "Cámaras de Piedra" etc.) caben en 340 px; **no hay truncado** en `W.name` (`UI.lua:515-523`).
  Riesgo bajo; mismo remedio que en 2 si algún nombre de mazmorra supera ~250 px (p. ej. en alemán/ruso).
- Pedir captura con nombre más largo.

### 7. Cadena `- 0:12` / `+0:20` a 11 px junto a `[3:58]` a 13 px: orden de lectura correcto, delta secundario — sin hallazgo
- Delta (11 px, turquesa/rojo) a la izquierda del tiempo y del nombre: ves primero el nombre en cream grande, luego el
  tiempo en el color del estado. Coherente con "¿voy bien?". `+0:20` en rojo y `-0:12` en turquesa son legibles.

## Lo que NO toqué
- Tag de instancias eliminado, márgenes de monedas 2/5, rep truncada con "...", bossTop 4, tamaños de fuente del
  diseño, geometría x1000/932, tooltip solo en el bloque superior, widget sin panel (todas decisiones de hoy).
- Paleta base (gold/turquoise/red/cream) y peso mínimo Medium (memoria de estilo).
- Estados no capturados: FIRST TIME, NEW RECORD, 10/10, compacto, pausa, tooltip Detalle, rare muerto + vivo.

## Idea de producto (fuera de encuadre)
Ninguna.
