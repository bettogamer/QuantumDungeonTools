# Crítica del widget HUD (demo `live`) tras migrar los tags a Craft.Badge — 2026-11-13

Encuadre: ¿los tags sobre `Craft.Badge` (FR-140) han empeorado el widget, y cuadran con el resto del HUD?
Captura: `1.png` (demo `live`, ~336 px de ancho, un solo estado: sin FIRST TIME / NEW RECORD).
Límite: el lienzo de diseño (artifact) no es accesible desde este agente; no se ha comparado con él. `docs/ux-pantallas.md`
solo tiene la plantilla de decisiones (D-1/D-2 vacías), así que no hay D-N vigentes contra las que medir.
Los píxeles de abajo son lectura de la captura (±1-2 px), no medidas.

## Resumen
La pantalla contesta bien a la pregunta del norte (reloj 16:22 / 31:40, delta vs récord, jefes 3/6). La migración no
rompe nada visible. Hay UN punto a vigilar (RARE a 9 px) y dos preguntas cerradas con razonamiento (sombra, +1 px).

## Hallazgos (priorizados)

### 1. RARE a 9 px: legible en captura pero es el texto más débil del HUD — 🟡
- Qué se ve: la etiqueta «RARE» (gris `C.muted` sobre borde `C.mutedHalf`, ~14 px de alto) se lee, pero sus mayúsculas son
  las más pequeñas y de menor contraste de toda la ventana, sobre un fondo de juego variable.
- Por qué: legibilidad. Memoria de estilo: «peso mínimo Medium, saturado, con contorno»; aquí tamaño mínimo + color
  apagado + sin sombra se suman. Es una etiqueta secundaria (la fila rare no es lo que el addon responde), así que
  no es 🔴.
- Código: `Style.lua:108` (`rareTag size = 9`), `Style.lua:86-87` (`rareTagPadX 4, rareTagPadY 0`), `UI.lua:305`, `UI.lua:511`.
- Propuesta: subir a **10 px** (lo que sugería el plan) con `rareTagPadY = 0`: alto = 10·16/12 + 2 = ~15 px, solo +1 px
  de caja, y el texto gana ~11 %. Alternativa: dejar 9 px y subir el color a `C.cream`/`C.sand` con alfa 0.8. Mi
  recomendación es la primera; decide el owner mirándola in-game, no es decisión mía.

### 2. Sin sombra 1,-1 en los tags: no se nota en 11 px, sí puede notarse en RARE — ⚪
- Qué se ve: el texto de los tags se ve nítido y legible; no se aprecia diferencia con el resto en la captura.
  La caja de 1 px del borde ya da contorno y el texto vive sobre el hueco de la caja, no directamente sobre el juego
  como «Witherfang» o «Ruins of Lordaeron».
- Por qué importa poco: `newText` solo pone sombra (`UI.lua:56-57`); el tag es el único texto sin ella, pero queda
  enmarcado. En el tag de 9 px el efecto se sumaría al hallazgo 1 (más fino, sin refuerzo).
- Código: `UI.lua:85-96`. Badge solo expone `fontFlags` (override del contorno, FR-102), no sombra.
- Propuesta: no hacer nada ahora. Si tras subir RARE a 10 px sigue flojo, opciones en orden: (a) `fontFlags = "OUTLINE"`
  solo en el tag RARE (soportado hoy, sin tocar Craft); (b) FR a Craft para `shadow` por instancia. NO tocar
  `badge._label` desde QDT (campo privado, Craft es read-only).

### 3. +1 px de alto del Badge frente al tag anterior: no verificable desde la captura — ⚪
- Qué se ve: «Normal» (~19 px) y «Instances 8/10…» (~19 px) caben sin que la cabecera ni la fila de extras parezcan
  más altas ni apretadas; no hay solapes ni huecos raros.
- Cálculo (código): alto = lineHeight(size·16/12) + 2·padY + 2 (`Badge.lua:322-323`). Para `tag` 11 px / padY 1:
  14,67 + 2 + 2 = 18,67 → 19 px (con `snapPx`). Un tag a mano con la altura de texto del FontString (~13-14 px) + 2 + 2
  daría 17-18 px, así que +1 px es plausible y NO es un defecto: es la caja CSS del diseño.
- Propuesta: aceptar. Si el owner lo quiere idéntico al anterior, `tagPadY = 0` en `Style.lua:76` (alto 17 px). No lo
  recomiendo: el texto quedaría más pegado al borde que en el lienzo (2 px de aire vertical por lado hoy).

### 4. Alineación vertical por línea base: se ve correcta — sin hallazgo
- «Normal» y «Ruins of Lordaeron» (cabecera, `W.head`) y «RARE» / «Lordaeron Captain» comparten línea visual; la
  diferencia, si la hay, es ≤1 px y no distingo el sentido en esta captura.
- Aviso de código (no visible): `chainBaseline` usa `DESCENT = 192/932` para FontStrings (`UI.lua:39`), mientras
  `Badge:GetBaselineOffset` usa 0,2 (`Badge.lua:50`): dos ratios distintos mezclados en `descentOf` (`UI.lua:134-138`).
  Con la tipografía actual la diferencia es 0,2 - 0,206 = <0,1 px por glifo, irrelevante hoy. Si algún día aparece un +1 px
  en la fila del reloj con FIRST TIME / NEW RECORD, mira aquí primero. «Pedir captura de FIRST TIME / NEW RECORD»
  (11 px bold, junto al 42 px del reloj) para cerrar esta preocupación, que es donde más se amplificaría.

### 5. Otros (cosas que sí se ven)
- ⚪ Borde derecho: las cajas de «Normal» e «Instances 8/10…» y la barra terminan a ~320 px; el texto de las filas de
  debajo («Witherfang», «-0:17», «rested 18%») termina ~6 px antes. Es la diferencia natural caja (con borde) frente
  a texto sin padding; solo es defecto si en el lienzo el texto remata en la misma línea. «Comparar con el artboard Main».
- ⚪ Jerarquía: la fila «Instances 8/10 · free in 12:40» (caja dorada) compite en peso con «Bosses 3/6 · vs. record -0:17»,
  que es más importante para el norte. Hoy gana el tag por tener borde. Es herencia del diseño, no de la migración;
  solo anotarlo si el owner lo ve en juego.
- ⚪ Cabecera: «Normal» está a la derecha del nombre, con el espacio entre ambos holgado; correcto, sin cambios.

## Lo que NO toqué
- Colores, paleta y pesos de fuente (decisión de estilo del owner, memoria `feedback-ui-estilo-widget`).
- La fila «2 deaths» en rojo y el cuerpo de la lista de jefes: no cambian con la migración y la captura es coherente.
- Estados no capturados: FIRST TIME, NEW RECORD, 10/10 («free in» en rojo), compacto, pausa, hover, toast.
- Comparación con el lienzo de diseño (no accesible aquí).

## Idea de producto (fuera de encuadre)
Ninguna.


## A/B padding vertical (2026-11-13)

Encuadre: elegir entre padY 1 (A: tags 19 px, RARE 15 px) y padY 2 (B: 21 px / 17 px) en los Craft.Badge outline del widget live y first-time.

**Veredicto: B (tagPadY = 2, rareTagPadY = 1).** Sin mezcla.

- Aire vertical: en A el texto de «Instances 8/10 · free in 12:40» casi toca el borde superior e inferior mientras que a los lados hay ~6 px. En B el aire arriba/abajo se acerca al lateral y la caja se lee como pastilla, no como texto subrayado en un marco. Es lo que compensa las mayúsculas más altas de BettoGeo frente a Inter.
- Peso del tag dorado: crece 2 px de alto; sigue siendo secundario frente al reloj de 42 px y a «Bosses 3/6», y no compite con los nombres de jefe. No llega a ser el elemento dominante.
- Proporción con el vecino: «Ruins of Lordaeron» y «Normal» (tag 11 px) quedan alineados y con mejor relación altura-caja/texto 12 px en B; en A el tag parece más bajo que su texto vecino.
- Coherencia RARE vs 11 px: la diferencia es 4 px en ambos casos (19/15 y 21/17), así que la relación se mantiene; en B el RARE gana aire sin parecer un chip distinto.
- FIRST TIME junto al reloj (captura 8 vs 2): en B la caja es más alta pero sigue centrada respecto a la línea base del reloj; no se ve desplazamiento apreciable. Pedir captura del tag FIRST TIME en live si se quiere verificar a 1:1 (la 2 es de otra versión de RARE).
- Coste: +2 px por tag, ~4-6 px de alto total del HUD; densidad aceptable. Severidad: ⚪ pulido.
