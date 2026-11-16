# Revisión 2026-11-15 · Switch de las páginas de ajustes (color del thumb)

Encuadre: ¿el círculo (thumb) debe pasar de blanco (off) a oscuro (on), o cambiar? Captura: `1.png`
del owner (arriba off, abajo on). Solo hay estos dos estados; no se ven hover ni disabled.

## Veredicto: MANTENER

### Qué se ve
Off: pista gris-azulada oscura, círculo crema/blanco. On: pista dorada, círculo azul marino.
El círculo siempre contrasta fuerte con su pista, y el estado se lee por tres canales a la vez
(posición izquierda/derecha, luminosidad de la pista, color).

### Qué token pinta cada cosa (Craft vendoreada)
`libs/Craft/components/Switch.lua:256-261` (`_applyTheme`):
- thumb off = `foreground`; thumb on = `primaryForeground`.
- pista off = `input` al 80 % de alfa; pista on = `primary`.

Nuestro contexto de tema (`wow/Kit.lua:117,122`) los sobrescribe así:
- `foreground = C.cream` (F7EDDC). Por eso el thumb off es crema, no blanco puro.
- `primary = C.gold` (F5BF57) y `primaryForeground = C.panel` (042239). Por eso el thumb on es marino.
- `input` NO se sobrescribe: es el de Craft, blanco al 15 % (`theme/Presets.lua:149`), x0.80 = ~12 % de blanco sobre el fondo.
Las páginas de Minimap Lens usan `Craft.Switch:Create` en `modules/MinimapLens/wow/Page.lua:179` y `:236`, y heredan ese contexto.

### Contraste (calculado desde los hex de `core/Style.lua`)
- Thumb on (042239) sobre pista oro (F5BF57): ~9,7:1. Es el mismo par que ya usa el botón primario («oro sobre marino 9,7:1», comentario de `Kit.lua:117`).
- Thumb off (crema) sobre pista off (~223D51): ~10:1.
- Daltonismo: no depende del matiz. Pista on = clara, pista off = oscura (diferencia de luminosidad enorme), más la posición del círculo. Se distingue incluso en escala de grises o con protanopia/deuteranopia.

### Por qué cambiarlo sería peor
El thumb on oscuro NO es un capricho: es el patrón shadcn-Lyra (thumb = primary-foreground cuando está marcado). Es además coherente con el resto de la UI: texto marino sobre oro en los botones primarios (paleta B, un solo par «oro + marino»). Un thumb crema sobre pista oro daría ~1,4:1 (crema ≈ oro en luminosidad): el círculo casi desaparecería sobre la pista. Un thumb blanco/crema en on es la peor opción.

### Único punto flojo (⚪ pulido, no es el color del thumb)
La pista OFF sobre el panel marino tiene poco contraste propia (~1,4:1): el control «apagado» se lee sobre todo por el círculo crema, no por la pista. Funciona (el círculo es muy visible) y es fiel a Lyra; no recomiendo tocarlo. Si en una prueba in-game el off se perdiera sobre fondos claros del cristal, pedir captura de ese caso antes de actuar.

### Alternativas (solo si el owner insiste en cambiar; ninguna recomendada)
Roles de la paleta B: gold, cream, panel, track, tickIdle, muted.
1. Mantener thumb on marino, pista off más legible: pista off = `tickIdle` (5A808E), thumb off = cream. Requiere sobrescribir `input` (alfa del 80 % lo aplica el Switch: queda deslucido) → solo tokens de contexto, pero ese contexto afecta a Checkbox/Input/Slider si comparten `input`; habría que crear un contexto exclusivo del Switch (`config.theme`), sin FR a Craft.
2. Thumb on crema sobre pista oro: no se consigue con tokens sin romper los botones (`primaryForeground` es el texto de los botones oro) y además da contraste ~1,4:1. Descartada.
3. Pista on = turquesa `accent` en vez de oro: no es posible con tokens (el Switch lee `primary`), y el oro es la señal «activo/progreso» de la paleta. Descartada.

## Lo que NO toqué
Tamaño 32x18 y animación (Lyra, `Switch.lua:17-21`); estados hover/disabled (no están en la captura: pedir captura si importan); el resto de controles de la página.

## Resolución (2026-11-15)

Se mantiene el thumb tal cual (veredicto aceptado por el owner); sin commit de código.
