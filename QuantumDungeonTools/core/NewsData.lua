-- core/NewsData.lua -- the "What's new" notes, WRITTEN BY HAND (core/News.lua).
--
-- One short sentence per change a PLAYER notices, "Title (optional tag): detail", in Spanish
-- (`es`) and English (`en`); newest version first. The full technical record is CHANGELOG.md
-- (CurseForge): every release adds its CHANGELOG entry AND its lines here. Internal work (libs,
-- self-tests, /qdt check) does not go here. A missing language falls back to the other one.
local _, ns = ...

ns.NewsData = {
  {
    unreleased = true,
    es = {
      "Novedades: esta página, con lo que cambia en cada versión.",
      "Icono del minimapa: clic abre la ventana, mayús+clic el Historial y clic derecho un menú. "
        .. "Se oculta desde Ajustes generales o con /qdt minimap.",
      "Ventana principal (/qdt): Inicio, ajustes del Instance Tracker e Historial de runs en un solo sitio.",
      "Avisos de instancias: aviso al llegar a 10/10 con el tiempo hasta el siguiente hueco, y franja "
        .. "ámbar en la 8.ª y la 9.ª.",
      "Fin de run: tarjeta con tiempo, récord, muertes, XP, oro y reputación, y un botón para "
        .. "compartirla en el grupo.",
      "Instancias en la última hora: el detalle del widget cuenta las de toda la cuenta y cuándo "
        .. "se libera la siguiente.",
      "Copias y reinicios: entrar en otra copia de la mazmorra o reiniciarla empieza una run nueva.",
      "Pausa: al salir de la mazmorra el reloj se para y sigue al volver.",
      "Widget del Instance Tracker: reloj con tu récord y splits por jefe, barra de XP, y el oro y "
        .. "la reputación de la run.",
      "Barras: nueva textura en las barras de tiempo, de jefes y de XP.",
    },
    en = {
      "What's new: this page, with what changes in each version.",
      "Minimap icon: click opens the window, shift+click the History and right click a menu. "
        .. "Hide it from General settings or with /qdt minimap.",
      "Main window (/qdt): Home, Instance Tracker settings and run History in one place.",
      "Instance alerts: a warning at 10/10 with the time until the next slot, and an amber strip "
        .. "on the 8th and 9th.",
      "End of run: a card with time, record, deaths, XP, gold and reputation, and a button to "
        .. "share it with the group.",
      "Instances in the last hour: the widget's detail counts the whole account's and when the "
        .. "next one frees up.",
      "Copies and resets: entering another copy of the dungeon or resetting it starts a new run.",
      "Pause: leaving the dungeon stops the clock; it goes on when you come back.",
      "Instance Tracker widget: clock with your record and boss splits, XP bar, and the run's gold "
        .. "and reputation.",
      "Bars: new texture on the time, boss and XP bars.",
    },
  },
}
