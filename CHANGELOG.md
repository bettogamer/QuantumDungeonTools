# Changelog

Formato: [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/). Versionado: SemVer.

## [Unreleased]

### Añadido

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

