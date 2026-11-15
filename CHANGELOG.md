# Changelog

Formato: [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/). Versionado: SemVer.

## [Unreleased]

### Cambiado

- **Barras con la textura BettoBar** (Craft v2.50.0, re-vendoreada): el relleno de la barra de tiempo,
  los segmentos de jefe y las capas de la barra de XP usan la textura teñida con su color de la paleta,
  y va dentro del borde de 1px, como en el diseño (antes lo tapaba).

### Añadido

- **Página Novedades** en la ventana principal: lo que cambió en cada versión (las cinco más
  recientes), sacado de este mismo registro de cambios.
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

