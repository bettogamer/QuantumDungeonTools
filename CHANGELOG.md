# Changelog

Formato: [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/). Versionado: SemVer.

## [Unreleased]

## [0.1.0-beta.4] - 2026-11-20

### Cambiado

- **El reloj de la run arranca con el primer combate dentro de la mazmorra**, no al cruzar la
  puerta: esperar al grupo ya no cuenta. Si se escapa el combate, arranca con la primera muerte.
  **Ojo con los récords:** los guardados se midieron desde la entrada, así que las runs nuevas
  saldrán algo más rápidas y pueden batirlos sin ir más deprisa. Las runs ya empezadas siguen
  contando como antes.

### Corregido

- **Excavation Site: Wetlands se reiniciaba sin parar** y el contador por hora subía a cientos
  (481/10) con aviso continuo: cada hechizo se tomaba como «otra copia de la mazmorra». Ahora la
  copia solo se comprueba tras una pantalla de carga, y una mazmorra cuyo identificador de copia
  no es fiable se detecta sola y deja de usarlo.
- **Un `/reload` dentro de la mazmorra podía abrir una run nueva** y contar otra instancia en la
  hora: el reload ya no se confunde con entrar en otra copia.
- **Cruzar subzonas dentro de la mazmorra** ya no puede reiniciar la run ni contar entradas.
- **El ping al jefe no funcionaba con el juego en español**: en esES el comando no es `/ping` sino
  `/aviso`, y en esES/esMX el tipo es «Atacar», no «attack». Ahora la macro usa el comando y el
  tipo del idioma del cliente.

## [0.1.0-beta.3] - 2026-11-17

### Añadido

- **Esquina de la lupa configurable** en la página de Minimap Lens (por defecto abajo a la
  izquierda, para no tapar el + / − de EllesmereUI).
- **«Lupa solo al pasar el ratón»** (activada por defecto): la lupa se oculta y aparece al pasar el
  ratón por el minimapa, con la lente abierta o cerrada.

### Cambiado

- **La lupa se ve con el módulo activo**, también fuera de las instancias, y cuelga de UIParent
  para que EllesmereUI no la recoja entre sus botones.
- **Quitado «Zoom extra al activarla»**: la lente mantiene el zoom que tenías (el ajuste guardado
  se ignora).

### Corregido

- **Terreno bajo tierra** (cuevas, Entrañas): con opacidad por debajo del 100 % la lente solo
  pintaba los puntos, no el mapa. Ahora lo pinta al abrirse, al cruzar una puerta, al bajar de
  nivel y tras cada cambio de zoom, sin bucles de zoom ni parpadeo continuo.
- **Tras un `/reload` la lente no crecía** y, al reabrirla, pintaba un solo cuadrante hasta
  refrescarse: ahora repone el tamaño si otro addon lo deshace y se pinta entera a la primera.

### Interno

- Sondas `/qdt check pos` y `/qdt check door` (investigación de coordenadas propias en mazmorra y
  del cambio de mapa del minimapa; `docs/27-coordenadas-propias.md`).

## [0.1.0-beta.2] - 2026-11-15

### Añadido

- **Minimap Lens (módulo nuevo, M2):** agranda el minimapa real a demanda (2,6× su lado por defecto,
  un paso de zoom más cerca, contorno QDT en lugar del aro de Blizzard, iconos de addons
  alrededor). Al apagarla, al recargar o en una pantalla de carga todo vuelve como estaba, también
  en combate. Se cierra sola al salir de la instancia y al abrir el Modo edición.
- **Disparadores de la lente:** atajo en Opciones › Atajos › AddOns › Quantum Dungeon Tools (sin
  tecla por defecto), botón lupa pegado al minimapa (solo dentro de una instancia, con el atajo en
  su tooltip) y `/qdt lens`.
- **Convivencia con otros UI:** si EllesmereUI, ElvUI u otro addon recoloca el minimapa con la
  lente puesta, la lente repone solo lo que cambió, sin pelear; si insiste, cede y avisa una vez
  con un toast que lleva a los ajustes. También avisa si el minimapa está pegado en EllesmereUI.
- **Página de Minimap Lens** en la ventana principal (ya sin «PRONTO»): interruptor del módulo,
  «Probar la lente» y «Mover la lente»; tamaño y opacidad en vivo; zoom extra, ocultar hierbas y
  minas mientras está activa y bloquear la posición; el atajo asignado y quién manda en el minimapa.

## [0.1.0-beta.1] - 2026-11-15

### Cambiado

- **Craft v2.51.0 vendoreada** (FR-152 badge «PRONTO» en la fila del sidebar, FR-153 contenido de
  `Craft.Tabs` con rect): sustituye a la v2.50.0 de la entrada siguiente.
- **Barras con la textura BettoBar** (Craft v2.50.0, re-vendoreada): el relleno de la barra de tiempo,
  los segmentos de jefe y las capas de la barra de XP usan la textura teñida con su color de la paleta,
  y va dentro del borde de 1px, como en el diseño (antes lo tapaba).

### Añadido

- **Vista previa del widget** (F6f) en IT › Resumen › «Qué enseña»: pestañas En curso / Completada /
  Primera vez a la derecha y, debajo, el widget real con los datos de la demo; cada ajuste (líneas,
  compacto) se ve en él al momento. Mientras se ve, el widget vive en la ventana (sin arrastre ni pings)
  y vuelve a su sitio al plegar el grupo, cambiar de pestaña o cerrar la ventana.
- **Página Novedades** en la ventana principal: una tarjeta plegable por versión (las cinco más
  recientes) con una frase corta por cambio, en español e inglés.
- **Icono del minimapa** (hito M1 F6e): clic abre la ventana principal, mayús+clic el Historial de
  runs y clic derecho un menú (Instance Tracker, Historial, Ajustes generales, Ocultar el icono);
  se arrastra por el borde del minimapa. Nueva página **Ajustes generales** con su interruptor y
  `/qdt minimap` para mostrarlo u ocultarlo.
- **Avisos de instancias y toast de fin de run** (hito M1 F5b/F5c): aviso rojo «Límite de
  instancias: 10/10» con el tiempo hasta el siguiente hueco (al entrar en la décima, al unirte a un
  grupo estando en 10/10 y cuando el juego rechaza la entrada); franja ámbar al entrar en la 8.ª y
  la 9.ª; y al terminar la run, una tarjeta con el tiempo, el delta y NUEVO RÉCORD, muertes, XP,
  oro y reputación, con «Compartir en grupo» (una línea por el canal del grupo). Vistas previas:
  `/qdt it alert toast|cap|near`.
- **Instancias en la última hora** (hito M1 F5a): el tooltip Detalle enseña «INSTANCIAS EN LA
  ÚLTIMA HORA · N/10» para toda la cuenta (todos los personajes) y cuándo se libera el siguiente
  hueco. Cuenta al entrar en una copia nueva; volver a la misma copia dentro de la hora no suma.
- **Más IDs de jefe**: el Instance Tracker reconoce también los encounterID alternativos que
  recoge ForeverDungeonJournal (46 jefes: Gnomeregan, Deadmines, BFD, Thaurissan, Thalnos…), por
  si Forever emite el ID clásico en vez del nuevo.
- **Instance Tracker distingue la COPIA de la mazmorra** por el zoneUID del castGUID de tus
  propios hechizos: si sales y entras en otra copia (te unes a un grupo y vas a la del líder, o
  hubo un reset), se cierra la run anterior y empieza una nueva; si es la misma, la run sigue. Al
  volver a entrar, el lockout no se mezcla en la run hasta que el primer hechizo confirma la copia.
- **Reset de instancias cierra la run**: el mensaje «X has been reset.» termina la run de esa
  mazmorra; al volver a entrar empieza una nueva (también para runs guardadas sin copia).
- **Pausa del reloj**: al salir de la mazmorra o desloguear la run se pausa y el tiempo fuera no
  cuenta (ni en el reloj ni en los splits). Al volver se retoma si es la misma mazmorra y
  dificultad y estuviste fuera menos de 90 min (20 min si ya habías matado a todos los jefes);
  si no, empieza una run nueva.
- **Widget nuevo del Instance Tracker sobre Craft** (hito M1 F2): HUD transparente con contorno,
  paleta Forever y fuente BettoGeo; nombre y dificultad, reloj grande, línea de jefes, barra de
  tiempo de 14 px (o segmentos por jefe si no hay récord), barra de XP con lo ganado en la run y
  el descanso (se oculta al nivel máximo), «Instancias X/10» desde 7/10 y lista de jefes con su
  split. Estados En curso, Completada, Primera vez y Compacto (`/qdt it compact`, jefes en un
  tooltip). Se mueve arrastrando la cabecera; clic derecho lo oculta hasta el próximo cambio de
  zona. Récord, deltas, muertes, oro/reputación y el contador por hora llegan en F3-F5.
- `/qdt it demo <live | done | first | compact | off>`: enseña cada estado con los datos de los
  artboards, sin mazmorra.
- `/qdt check f2`: autoprueba (libs cargadas, contexto de tema, fuentes, los cuatro estados, APIs
  de XP de Forever) → `QuantumDungeonToolsDB._checkF2`, lector `scripts/read-check-f2.lua`.
- Libs vendoreadas: LibStub, Weave v0.10.0 y Craft v2.47.0 (`libs/README.md`).
- Idiomas: inglés por defecto y español latino.

- `/qdt check f1 [etiqueta | off]`: sondas de WoW Forever para el hito M1 (lockout por jefe,
  zoneUID del GUID, globales de dinero/reputación/reset/límite por hora, eventos). Vuelca a
  `QuantumDungeonToolsDB._checkF1` y deja un registro pasivo con fotos automáticas; se lee con
  `scripts/read-check-f1.lua`.

