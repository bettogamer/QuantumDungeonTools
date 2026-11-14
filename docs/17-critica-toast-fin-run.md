# Crítica: toast de fin de run (Instance Tracker, M1 F5c)

Encuadre: la tarjeta izquierda de `Avisos.dc.html` frente a la captura in-game de `/qdt it alert toast`
(locale EN). Pregunta del norte: «¿cómo ha ido esta run frente a mi mejor?». La captura se lee bien y el
código sigue al artboard en casi todo. Lo que falta es jerarquía y ritmo vertical.

Fuentes leídas: captura `images/8.png`, `Avisos.dc.html` líneas 21-45, `modules/InstanceTracker/wow/Alerts.lua:296-418`,
`core/Style.lua` (`S.alert*`, `S.toast*`, `FONT.toast*`).

## 1. Hallazgos priorizados

### Alta

**A1. El delta (−1:49) es el dato que contesta la pregunta y es de lo más pequeño y pálido del toast.**
- Se ve: reloj 34 px bold y, al lado, `−1:49` a 14 px medium, mismo turquesa. Va sin etiqueta: no dice «contra qué».
  El rótulo NEW RECORD lo insinúa, pero un jugador sin récord previo no sabrá si es contra su mejor, la media o el par.
- Importa: contra el norte, «adelantado/atrasado respecto a la referencia» es la lectura principal y aquí
  pesa menos que el botón.
- Propuesta: subir el delta a 16 px / 600 y añadirle debajo-derecha una micro-etiqueta secundaria
  («vs récord», 11 px, #93B6C2). Detalle en la sección 2, M1 y M2. El código lo fija en
  `Alerts.lua:348-349` y `Style.lua:176`.

**A2. La columna de oro no tiene margen con cifras reales.**
- Se ve: `+8 ● 75 ●` ocupa ~60 de los ~77 px de columna (`colW = (360-28-3·8)/4`, `Alerts.lua:375`).
- Importa: con `+120 ● 45 ●` o más se ensancha ~15-20 px y se envuelve o pisa la columna Rep.
  **Pedir captura con oro de 3 cifras** para confirmarlo; la geometría sugiere riesgo. Las columnas iguales
  son una decisión del artboard, pero el contenido no es uniforme.
- Propuesta: columnas de ancho proporcional (rejilla `1fr 1fr 1.5fr 1fr`) en vez de 4 iguales. En código sería
  un ancho por columna en `buildToast`/`layoutToast`, sin tocar `S.toastStatGap`. Alternativa: dejar los
  4 iguales y asegurar que el valor no se envuelva (`SetWordWrap(false)`).

### Media

**M1. Ritmo vertical plano: todo a 10 px, así que nada agrupa.**
- Se ve: cabecera, nombre de mazmorra, reloj, stats y botón separados por el mismo hueco (`S.toastGap = 10`),
  más 4 extra sobre el botón. El nombre de mazmorra queda tan lejos del reloj como el reloj de las stats.
- Importa: «Ruins of Lordaeron · Normal» y «29:51» son la misma unidad (qué run y cuánto tardó) y las
  stats son otra. Legibilidad/jerarquía.
- Propuesta: nombre→reloj 4 px, reloj→stats 14 px, stats→botón 14 px (valores en la sección 2). Esto
  cambia `S.toastGap` en `layoutToast` (`Alerts.lua:372,374,381`) por tres tokens.

**M2. Título «Run complete» (14 px) y nombre de mazmorra (12 px muted) compiten, y la mazmorra queda lejos de la cabecera.**
- Se ve: la cabecera dice solo «Run completa» + tag; el qué-run viene bajo la línea.
- Importa: no es un fallo, pero la mazmorra es el dato identificador y está en la capa más pálida.
- Propuesta (mejora, no obligatoria): subir el nombre a 13 px #F7EDDC y dejarlo bajo la línea. Así el título sigue
  siendo la etiqueta del evento y la mazmorra gana presencia. Es solo cambio de color/tamaño.

**M3. Artboard desactualizado en monedas.**
- Se ve: el artboard dibuja círculos CSS (`#e3b341`, `#c7cdd4`, líneas 36); el juego usa iconos de moneda reales
  (correcto, regla del owner). Esos hex además NO son de la paleta B.
- Importa: quien vuelva a leer el artboard copiará un hex inventado.
- Propuesta: sustituir los círculos por un marcador de icono (12 px, sin color propio, p. ej. un `<span>` con
  borde punteado y `aria-label`) y anotar «icono de moneda del juego». Es cambio del artboard, no del código.

### Baja

**B1. `3` suelto en la posición del delta (`Alerts.lua:349`, `SetPoint(..., S.toastClockGap, 3)`).** Es un ajuste
de línea base a mano. Con la fuente actual queda bien en la captura, pero conviene subirlo a un token
`S.toastDeltaBase` (token que tocaba).

**B2. El botón cream es el bloque más brillante del toast y compite con el reloj.** Es decisión vigente (commit
`6341d2e`) y no se re-discute. Si se quisiera calmar, la alternativa sería quitar el relleno y dejar borde
`rgba(245,191,87,0.22)` como «Historial» pero eso lo haría indistinguible del botón secundario. Se deja como está.

**B3. Hueco vacío a la izquierda del botón.** Subir el botón a la fila del reloj (que tiene ~150 px libres)
ahorraría ~35 px de alto, pero con «Historial» (F6) no cabe (~208 + ~135 > 332). No se propone.

## 2. Propuesta de diseño (valores para `Avisos.dc.html`, tarjeta izquierda, líneas 21-45)

### 2a. El código no sigue al artboard
Casi nada. Diferencias observadas:
- Monedas: el código ya usa iconos del juego; el artboard sigue con círculos (M3, arreglo en el artboard).
- Resto (colores, pesos, tamaños 14/12/34/14/13/11, padding 12/14, borde 1px blanco 10 %): coincide.
- Pendiente de verificar en juego: ancho de la columna de oro (A2).

### 2b. Mejoras al artboard (cada una opcional)

| Id | Elemento | Ahora | Propuesta |
|----|----------|-------|-----------|
| M1 | Fila reloj+delta (línea 28) | `gap:10px` | sin cambio |
| M1 | Contenedor del cuerpo (línea 26) | `gap:10px` único | `gap:0`; márgenes por bloque: nombre `margin-bottom:4px`, reloj `margin-bottom:14px`, rejilla de stats `margin-bottom:14px` |
| A1 | Delta (línea 30) | 14px / 400 / #36C9E8 | `font-size:16px; font-weight:600; color:#36C9E8` (= `adelantado`; si atrasado, #FF6B4F; sin run previa, sin delta) |
| A1 | Micro-etiqueta del delta | no existe | `<span style="font-size:11px; color:#93B6C2; font-weight:500">vs récord</span>`, a la derecha del delta, `margin-left:6px`, misma línea base. Texto nuevo en `L`; si el owner no la quiere, omitir y quedarse con el subir de tamaño |
| A2 | Rejilla de stats (línea 32) | `repeat(4, minmax(0,1fr))` | `grid-template-columns: 1fr 1fr 1.5fr 1fr; gap:8px` |
| M2 | Nombre mazmorra (línea 27) | 12px / #93B6C2 | `font-size:13px; font-weight:500; color:#F7EDDC` (rol `texto`) |
| M3 | Monedas (línea 36) | círculos #E3B341 / #C7CDD4 | `<span style="display:inline-block;width:12px;height:12px;margin:0 4px 0 2px;vertical-align:-2px;border:1px dashed #93B6C2" aria-label="oro">` (placeholder: el juego pone el icono real; no pintar color de moneda) |
| — | Fila de botones (línea 40) | `margin-top:4px` | `margin-top:0` (el espacio lo da el margen de la rejilla, 14px) |

Lo que NO cambia: colores de stats (muertes #FF6B4F, XP #8FE3F5, oro y rep #F7EDDC), padding 12/14, línea
bajo la cabecera, tag NUEVO RÉCORD, botón Compartir cream con texto navy #042239.

### 2c. Qué tocaría en código si el owner aprueba
- Tokens nuevos en `Style.lua`: `S.toastNameGap = 4`, `S.toastBlockGap = 14` (sustituyen a `S.toastGap` y `S.toastBtnTop`
  en `layoutToast`), `S.toastDeltaBase` (el `3`), `FONT.toastDelta = { size = 16, weight = "semibold", flags = "" }`.
- Etiqueta «vs récord»: nueva clave `L.IT_A_VS_RECORD`, `FONT.alertSmall`, `C.muted`.
- Sin color nuevo en ningún caso.

## 3. Lo que NO toqué
- Botón «Historial» oculto hasta F6 (decisión vigente).
- Botón Compartir cream (decisión vigente, commit 6341d2e).
- `SIZE` escalado ×1000/932 (a propósito).
- Estados no vistos: toast sin récord / delta atrasado / sin delta, y muertes = 0. Pedir captura de esos estados
  antes de dar hallazgos.
- Animación del toast, 30 s de duración y apilado con el aviso 10/10 (fuera del encuadre).
- Idea de producto (una línea): mostrar el tiempo del récord anterior en lugar de, o junto al, delta.
