# 15 · Cotejo diseño ↔ código del Instance Tracker (2026-11-13)

Solo lectura. Diseño = lienzo Claude Design `QCFDYZLH1HU8Mj72a3VAXy` (6 artboards). Código = `QuantumDungeonTools/modules/InstanceTracker/` (`core/Style.lua`, `wow/UI.lua`, `core/View.lua`, `core/Detail.lua`) y `QuantumDungeonTools/Locale.lua`. `SIZE` se compara sin escalar (×1000/932 a propósito); las monedas son iconos del juego. Cada fila lleva una frase de posible arreglo; la decisión de cuál manda es del owner.

Rutas de código abreviadas: `Style` = `core/Style.lua`, `UI` = `wow/UI.lua`, `Loc` = `QuantumDungeonTools/Locale.lua`.

## Diferencia transversal (afecta a todos los artboards)

| Elemento | Diseño | Código | Nota |
|---|---|---|---|
| Pesos de fuente | Mezcla de 400 (cabecera, info, `/ 31:40`, etiquetas XP, tiempos de jefe), 500 y 600 (nombre de jefe, `<b>` de cifras, etiquetas RARO/PRIMERA VEZ) y 700 (reloj) | Todo `medium` salvo reloj y `tagStrong` en `bold` (`Style:112-130`) | Deliberado: «sin regular» (`Style:77-78`). Las cifras en negrita del diseño (`3/6`, `+350`, `+18,450`, `+4g12s`) no tienen peso propio. Si manda el código, anotarlo en el lienzo. |
| Letter-spacing | Reloj `-1px`, etiqueta RARO `0.5px`, títulos del detalle `0.5px` | No existe en WoW; no se emula (`Style:116-131`) | No arreglable con FontStrings; solo documentar. |
| Menos tipográfico | Delta con `−` (U+2212): `−0:12` | `Format.delta` emite `-` ASCII (`core/Format.lua:36`) | Cambiar a U+2212 si BettoGeo lo trae, o dejar `-`. |
| Literales sin escalar | Gap 8 entre piezas de fila de jefe/rara, 10 en fila del reloj, 3 bajo la barra de XP | Literales `8` (`UI:637-650`), `10` (`UI:561`), `3` (`UI:373,494`) | Coinciden con el número del diseño, pero NO pasan por `SIZE`: quedan ~7 % más pequeños que el resto de la geometría escalada (p. ej. `rowGap` vale 9 en cabecera y 8 en jefes). Pasarlos por tokens de `SIZE` los alinea. |

## Main (en curso)

| Elemento | Diseño | Código (archivo:línea) | Nota |
|---|---|---|---|
| Separación fila de totales → lista de jefes | 10 px (gap 6 + `margin-top` 4) | 4 px: `y = y + S.bossTop - S.gap` con `bossTop = 4` (`UI:623`, `Style:87`) | Cambio consciente del owner (commit `ac94b74`, «10 left a hole»). Si manda el diseño, subir `bossTop` a 10. |
| Separador `·` de la fila de info | Tres piezas con gap 10: `Jefes 3/6`, `·`, `vs. récord` | Una sola cadena con `"  ·  "` (dos espacios BettoGeo ≈ 3,5 px) (`UI:497`) | Separación real ≈ 7 px + punto, no 10 + punto. Medir in-game. |
| Gap reloj ↔ `/ 31:40` y muertes | 10 | 10 literal sin escalar (`UI:561`) | Ver fila transversal de literales. |
| Tamaño de monedas | 10 px | `coinSize = 11` (`Style:94`) | Se justifica por la escala y «= FONT.small», pero sin escalar 11 ≠ 10. |
| Etiqueta RARO: tamaño de fuente | 9 px, peso 600, `line-height` 13 | `FONT.rareTag size = 10` (`Style:128`), peso medium | Bajar a 9 si manda el diseño. |
| Hueco del `<b>` de cifras (`3/6`, `+350`, `+4`) | Peso 600 | Medium sin negrita (`UI:501`, `UI:189`) | Ver fila transversal de pesos. |

## Completada

| Elemento | Diseño | Código (archivo:línea) | Nota |
|---|---|---|---|
| Texto de XP en la run | `+41,220 XP en la run · 1 nivel` | `IT_XP_RUN = "%s XP en la run"` sin sufijo de niveles (`Loc:125`, `UI:491`) | Falta el dato «N nivel(es)» ganado en la run; View tampoco lo calcula (`View:110-128`). |
| Línea tachada del récord | `text-decoration: line-through` (~1 px, mismo color muted) | Textura de 2 px (`UI:333`) | Cambiar a 1 px si se quiere clavar el diseño. |
| Tag NUEVO RÉCORD: gap con el resto de la fila | Gap 10 entre `Jefes 6/6`, `·` y el tag | `chain(..., 0)` + cadena `"  ·  "` terminada en separador (`UI:572`, `UI:510`) | Mismo caso que el `·` de Main. |

(Resto de la fila de cortes oscuros `042239`, sin tick del 100 %, relleno 94,3 %, XP sin base ni descanso, jefes dorados con delta turquesa/rojo: ver «Coinciden».)

## PrimeraVez

| Elemento | Diseño | Código (archivo:línea) | Nota |
|---|---|---|---|
| Tag PRIMERA VEZ: peso | 600 | `FONT.tagStrong` = bold (700) (`Style:117`, `UI:554`) | Efecto de que 600 y 700 usan ficheros distintos en BettoGeo; hoy el tag sale más grueso que en el lienzo. |

## Compacto

| Elemento | Diseño | Código (archivo:línea) | Nota |
|---|---|---|---|
| Gap reloj ↔ delta ↔ separador 2 | 10 px entre todas las piezas | `4` tras el reloj y `rowGap + 2` (≈11 tras escalar) en el resto (`UI:727`) | El reloj queda pegado al delta (4 px) y, sin delta, pegado al separador de XP. Unificar a 10. |
| Panel de detalle: forma | Panel fijo de 260 px, fondo sólido `042239`, padding 10×12, gap 6, fuente 12 | `Craft.Tooltip` con ancho/padding/gap/fuente propios de Craft (`UI:703`, `compactLines UI:668`) | Medidas no controlables desde el addon; verificar in-game. |
| Muertes en la cabecera del panel | Muted `93b6c2` | `rightColor = C.red` (`UI:673`) | Diseño usa muted; código rojo (como en el widget completo). |
| Título del panel | `Ruins of Lordaeron · Normal` | `v.name .. " · " .. v.difficulty` (`UI:671`) | Coincide el texto; sin diferencia real. Omitir en recuento. |
| Hora de jefe sin matar | `—` (raya larga) | `--` (`UI:677`) | Cambiar el literal si manda el diseño. |
| Fila de rara en el panel | Tag RARO con borde (badge) a la derecha del nombre, fuente 11 | Texto plano `RARO` coloreado muted tras dos espacios (`UI:678`) | El tooltip de Craft no admite badges; es limitación de la línea de tooltip. |
| Pie `Récord` | `31:40 · hace 3 días` | Solo `31:40` (`UI:683`, `Loc:129`) | Falta la antigüedad del récord (no hay dato ni cadena en Locale). |
| Cabecera compacta: pesos | `Jefes 3/6` y reloj en 600 | Medium (`FONT.compact`, `Style:129`) | Ver fila transversal de pesos. |

## Pausa

El estado no está implementado en la UI: `Run` ya congela el reloj (`pausedAt`, `core/Run.lua:52,87`), pero ni `View`, ni `UI`, ni `Locale` ni `Demo.NAMES` (`core/Demo.lua:92`: live, done, first, compact) tienen un estado «en pausa», y el widget se oculta fuera de la mazmorra (`UI:807`, `T.inInstance`). Todas las filas son «falta en código».

| Elemento | Diseño | Código (archivo:línea) | Nota |
|---|---|---|---|
| Etiqueta `↺ RETOMADA` | Texto 11/600 `8FE3F5` a la izquierda del nombre de mazmorra | No existe | Falta cadena Locale y estado en View. |
| Etiqueta `EN PAUSA` | Tag 11/700 RELLENO `93B6C2` con texto `042239`, sin sombra | No existe | Además rompe la regla «tags = solo borde» (`UI:81`); decidir si es excepción. |
| Reloj y referencia en pausa | Reloj y `/ 31:40` en `5A808E` (tickIdle) | No existe (tono del reloj solo `text/ahead/behind/progress`, `View:147`) | Falta un tono «paused». |
| Línea de info | `Fuera de la mazmorra · 2:05 sin contar` (el tiempo en sand `E6D2A9`) | No existe | Requiere `pausedTotal`/`pausedAt` en View y cadena Locale. |
| Relleno de barra | Rayado diagonal 135° `5A808E`/`06364A` (6 px) | No existe: relleno liso dorado (`UI:446`) | El rayado no se puede hacer con `SetColorTexture`; pedir textura o usar color liso `tickIdle`. |
| Lista de jefes | Opacidad 0,7; muertos con `[tiempo]` dorado, primer pendiente en cream, resto colapsado a `+2 jefes` (13 px muted); rara con solo tag + nombre, sin tiempo | Lista completa a opacidad 1 (`UI:624-659`) | Falta alpha de grupo y colapso «+N jefes». |
| Ticks del PB | No se pintan en pausa | Se pintan (`View:80-89`) | Parte del mismo estado nuevo. |

## Detalle (hover)

| Elemento | Diseño | Código (archivo:línea) | Nota |
|---|---|---|---|
| Color de la etiqueta izquierda de cada fila | `E6D2A9` (sand) | `leftColor = C.cream` (`UI:281`) | Cambiar a `C.sand` si manda el diseño. |
| Separadores entre secciones | Sin línea; solo gap 10 | `separator = i > 1` dibuja línea (`UI:291`) | Quitar `separator` o aceptar la línea. |
| Texto de runs hasta nivel | `≈ 2 runs` | `IT_D_RUN(S) = "~%d run(s)"` (`Loc:64-65`, `141-142`) | `≈` vs `~`; comprobar que BettoGeo trae `≈`. |
| Texto de ayuda `Pasa el ratón para ver el detalle` | Línea 11 px muted bajo la barra de XP | No existe (`IT_HINT` es otro texto, y no se pinta) (`Loc:53`, `131`) | Probablemente es solo anotación del lienzo; confirmar. |
| Zona sensible al ratón | Todo el bloque superior (contorno punteado) | Cabecera hasta fila de totales, nunca la lista de jefes (`UI:385-391`) | Coherente con la intención del outline; sin diferencia. Omitir en recuento. |
| Barra de XP y info del widget en el artboard | Solo `Jefes 3/6`, sin delta ni ticks ni etiquetas XP ni totales ni jefes | Widget completo con todos los bloques (`renderFull`) | El artboard es esquemático; el código muestra el widget entero. |
| Panel: medidas | 300 px, padding 12, gap entre secciones 10 / 4 entre filas, fuente 12 (500), títulos 11/600 | Craft.Tooltip (`UI:307`, `fontFlags = ""`) | No controlables desde el addon; verificar in-game. |

## Coinciden

- **Main**: cabecera (nombre muted 12, tag dificultad sand con borde oro 22 %, padding 6/2), reloj 42 bold turquesa con muertes rojas 12, `/ 31:40` 16 muted, barra 14 con track `06364A` y borde hairline, ticks 2 px con 3 de saliente, doradas/`5A808E`, hueco 12 hasta la barra, XP 8 px con tres capas (descanso 22 %, actual turquesa, base `0A8FB0`) y etiquetas 11 con gap 3 y cifra `8FE3F5`, totales a la derecha con gap 20 y margen 2/5 de monedas, jefes 15/13/11 con orden nombre-hora-delta, gaps 3, dorado/cream/delta turquesa o rojo, rara 13/12 con tag a la izquierda y margen 4. Textos Locale (`Jefes`, `vs. récord`, `muertes`, `Nv · %`, `descanso`, `RARO`).
- **Completada**: reloj turquesa, `31:40` tachado sin barra, tag NUEVO RÉCORD turquesa 11 bold con borde turquesa, `Jefes 6/6` dorado, barra 94,3 % con cortes `042239` y sin tick del 100 %, jefes dorados con deltas, barra de XP turquesa lisa, rara muted sin hora.
- **PrimeraVez**: tag `PRIMERA VEZ` en `8FE3F5` con borde 50 %, `esta run fijará tu récord`, 6 segmentos de 12 px con gap 3 y borde hairline (dorado/`06364A`), rara dorada con hora, totales solo con dinero, sin deltas.
- **Compacto**: barra superior con panel 82 % `042239`, borde hairline, padding 10×6, separadores 1×14 oro 22 %, `XP` en `8FE3F5`, delta 11 turquesa; panel de jefes con separadores, tonos dorado/cream/muted y pie `Récord` muted.
- **Pausa**: sin elementos que coincidan (estado inexistente).
- **Detalle**: títulos RITMO/REPUTACIÓN/RÉCORDS/INSTANCIAS EN LA ÚLTIMA HORA · n/m, filas `XP / hora`, `Oro / hora`, `Para nivel N`, `Personal`, `Con este grupo (N)`, `Siguiente hueco` (dorado), `Después` (muted), `en %s`; colores de valor (XP `8FE3F5`, grupo turquesa cuando bate el récord, cream en el resto).

## Recuento de diferencias

| Artboard | Filas |
|---|---|
| Transversal | 4 |
| Main | 6 |
| Completada | 3 |
| PrimeraVez | 1 |
| Compacto | 7 (excluida la fila «Título», que coincide) |
| Pausa | 7 (estado no implementado) |
| Detalle | 6 (excluida la fila de zona sensible, que coincide) |
