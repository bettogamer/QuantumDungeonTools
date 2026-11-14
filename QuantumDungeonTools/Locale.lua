---@diagnostic disable: undefined-global
-- Locale.lua -- i18n. enUS is the base/fallback; other locales override it.
-- User-visible text only: internal lookup keys are NEVER localized.
local _, ns = ...

local L = {}
ns.L = L

-- enUS (base)
L.MSG_LOADED   = "%s v%s loaded. Type /qdt for options."
L.MSG_ON       = "on"
L.MSG_OFF      = "off"
L.HELP_USAGE   = "usage: /qdt [it | it compact | it demo | new | history | auto | info | check f1 | check f2]"
L.HELP_LINES   = {
  "/qdt it -- show/hide the Instance Tracker widget",
  "/qdt it compact -- one-line widget, bosses on hover (on/off)",
  "/qdt it demo <live | done | first | compact | off> -- preview a state of the widget",
  "/qdt new -- forget the current run and start a new one",
  "/qdt history -- last runs (time, bosses, XP)",
  "/qdt auto -- open the window automatically inside dungeons (on/off)",
  "/qdt info -- version",
  "/qdt check f1 [label | off] -- Forever probes snapshot (dev)",
  "/qdt check f2 -- widget and Craft self-test (dev)",
}

-- Instance Tracker
L.IT_TITLE          = "Instance Tracker"
L.IT_NO_RUN         = "No active run."
L.IT_STATS          = "Bosses %d/%s  |  %s  |  XP +%s"
L.IT_NEW_RUN        = "new run started."
L.IT_RUN_CLOSED     = "run closed (you are not in a dungeon)."
L.IT_AUTO           = "auto show: %s"
L.IT_HISTORY_EMPTY  = "no runs in the history yet."
L.IT_HISTORY_HEADER = "last runs:"
L.IT_HISTORY_LINE   = "%s (%s): %d/%d bosses, %s, XP +%s%s"
L.IT_INCOMPLETE     = " [incomplete]"

-- Instance Tracker widget (plan M1 F2)
L.IT_BOSSES         = "Bosses %s"
L.IT_VS_PB          = "vs. record %s"
L.IT_FIRST_TAG      = "FIRST TIME"
L.IT_RARE           = "RARE"
L.IT_FIRST_HINT     = "this run will set your record"
L.IT_NEW_RECORD     = "NEW RECORD %s"
L.IT_DEATH          = "%d death"
L.IT_DEATHS         = "%d deaths"
L.IT_XP_RUN         = "%s XP this run"
L.IT_XP_GAINED_LV   = " · %d level"
L.IT_XP_GAINED_LVS  = " · %d levels"
L.IT_XP_LEVEL       = "Lv %d · %d%%"
L.IT_XP_RESTED      = " · rested %d%%"
L.IT_XP_SHORT       = "%s XP"
L.IT_RECORD         = "Record"
L.IT_AGE_TODAY      = "today"
L.IT_AGE_DAY        = "%d day ago"
L.IT_AGE_DAYS       = "%d days ago"
L.IT_WAITING        = "reading the boss list..."
L.IT_HINT           = "Drag to move. Right-click: hide until the next zone change."
L.IT_COMPACT        = "compact mode: %s"
L.IT_DEMO           = "demo '%s' shown. '/qdt it demo off' goes back to the real run."
L.IT_DEMO_OFF       = "demo off."
L.IT_DEMO_USAGE     = "demo states: %s, off"
L.IT_NO_CRAFT       = "the Craft library did not load: the widget is disabled."
-- Hover detail (F4b)
L.IT_D_PACE         = "PACE"
L.IT_D_XP_HOUR      = "XP / hour"
L.IT_D_GOLD_HOUR    = "Gold / hour"
L.IT_D_TO_LEVEL     = "To level %d"
L.IT_D_RUN          = "~%d run"
L.IT_D_RUNS         = "~%d runs"
L.IT_D_REP          = "REPUTATION"
L.IT_D_RECORDS      = "RECORDS"
L.IT_D_PERSONAL     = "Personal"
L.IT_D_GROUP        = "With this group (%d)"
L.IT_D_INSTANCES    = "INSTANCES IN THE LAST HOUR · %d/%d"
L.IT_D_NEXT_SLOT    = "Next slot"
L.IT_D_THEN_SLOT    = "Then"
L.IT_D_IN           = "in %s"
L.IT_D_EMPTY        = "Nothing to show yet."
L.CHECK_F2_SAVED    = "check f2: %d/%d ok (%s). Saved to QuantumDungeonToolsDB._checkF2."
L.CHECK_F2_FAIL     = "  FAIL %s: %s"

-- /qdt check f1 (dev probes, plan M1 F1)
L.CHECK_F1_SAVED  = "check f1: snapshot %d saved (%s)."
L.CHECK_F1_LOCK   = "lockout: %s/%s killed, %d encounter rows"
L.CHECK_F1_TARGET = "target zoneUID: %s"
L.CHECK_F1_STATIC = "globals %d/%d present, events %d/%d valid"
L.CHECK_F1_ARMED  = "passive log ON (survives /reload). '/qdt check f1 off' clears it."
L.CHECK_F1_OFF    = "check f1: data cleared, passive log OFF."

local locale = GetLocale()
-- Supported: enUS (default) and Latin American Spanish (esMX, owner 2026-11-12). esES gets the
-- same Latin American text rather than falling back to English.
if locale == "esES" or locale == "esMX" then
  L.MSG_LOADED   = "%s v%s cargado. Escribe /qdt para opciones."
  L.MSG_ON       = "activado"
  L.MSG_OFF      = "desactivado"
  L.HELP_USAGE   = "uso: /qdt [it | it compact | it demo | new | history | auto | info | check f1 | check f2]"
  L.HELP_LINES   = {
    "/qdt it -- mostrar/ocultar el widget del Instance Tracker",
    "/qdt it compact -- widget en una línea, jefes al pasar el mouse (sí/no)",
    "/qdt it demo <live | done | first | compact | off> -- ver un estado del widget",
    "/qdt new -- olvidar la run actual y empezar otra",
    "/qdt history -- últimas runs (tiempo, jefes, XP)",
    "/qdt auto -- abrir la ventana sola al entrar en mazmorras (sí/no)",
    "/qdt info -- versión",
    "/qdt check f1 [etiqueta | off] -- foto de las sondas de Forever (dev)",
    "/qdt check f2 -- autoprueba del widget y de Craft (dev)",
  }

  L.IT_TITLE          = "Instance Tracker"
  L.IT_NO_RUN         = "Sin run activa."
  L.IT_STATS          = "Jefes %d/%s  |  %s  |  XP +%s"
  L.IT_NEW_RUN        = "nueva run iniciada."
  L.IT_RUN_CLOSED     = "run cerrada (no estás en una mazmorra)."
  L.IT_AUTO           = "mostrar automáticamente: %s"
  L.IT_HISTORY_EMPTY  = "todavía no hay runs en el historial."
  L.IT_HISTORY_HEADER = "últimas runs:"
  L.IT_HISTORY_LINE   = "%s (%s): %d/%d jefes, %s, XP +%s%s"
  L.IT_INCOMPLETE     = " [incompleta]"

  L.IT_BOSSES         = "Jefes %s"
  L.IT_VS_PB          = "vs. récord %s"
  L.IT_FIRST_TAG      = "PRIMERA VEZ"
  L.IT_RARE           = "RARO"
  L.IT_FIRST_HINT     = "esta run fijará tu récord"
  L.IT_NEW_RECORD     = "NUEVO RÉCORD %s"
  L.IT_DEATH          = "%d muerte"
  L.IT_DEATHS         = "%d muertes"
  L.IT_XP_RUN         = "%s XP en la run"
  L.IT_XP_GAINED_LV   = " · %d nivel"
  L.IT_XP_GAINED_LVS  = " · %d niveles"
  L.IT_XP_LEVEL       = "Nv %d · %d%%"
  L.IT_XP_RESTED      = " · descanso %d%%"
  L.IT_XP_SHORT       = "%s XP"
  L.IT_RECORD         = "Récord"
  L.IT_AGE_TODAY      = "hoy"
  L.IT_AGE_DAY        = "hace %d día"
  L.IT_AGE_DAYS       = "hace %d días"
  L.IT_WAITING        = "leyendo la lista de jefes..."
  L.IT_HINT           = "Arrastra para moverlo. Clic derecho: ocultar hasta el próximo cambio de zona."
  L.IT_COMPACT        = "modo compacto: %s"
  L.IT_DEMO           = "demo '%s' en pantalla. '/qdt it demo off' vuelve a la run real."
  L.IT_DEMO_OFF       = "demo desactivada."
  L.IT_DEMO_USAGE     = "estados de la demo: %s, off"
  L.IT_NO_CRAFT       = "la librería Craft no cargó: el widget está desactivado."
  L.IT_D_PACE         = "RITMO"
  L.IT_D_XP_HOUR      = "XP / hora"
  L.IT_D_GOLD_HOUR    = "Oro / hora"
  L.IT_D_TO_LEVEL     = "Para nivel %d"
  L.IT_D_RUN          = "~%d run"
  L.IT_D_RUNS         = "~%d runs"
  L.IT_D_REP          = "REPUTACIÓN"
  L.IT_D_RECORDS      = "RÉCORDS"
  L.IT_D_PERSONAL     = "Personal"
  L.IT_D_GROUP        = "Con este grupo (%d)"
  L.IT_D_INSTANCES    = "INSTANCIAS EN LA ÚLTIMA HORA · %d/%d"
  L.IT_D_NEXT_SLOT    = "Siguiente hueco"
  L.IT_D_THEN_SLOT    = "Después"
  L.IT_D_IN           = "en %s"
  L.IT_D_EMPTY        = "Todavía no hay nada que mostrar."
  L.CHECK_F2_SAVED    = "check f2: %d/%d ok (%s). Guardado en QuantumDungeonToolsDB._checkF2."
  L.CHECK_F2_FAIL     = "  FALLA %s: %s"

  L.CHECK_F1_SAVED  = "check f1: foto %d guardada (%s)."
  L.CHECK_F1_LOCK   = "lockout: %s/%s muertos, %d filas de jefe"
  L.CHECK_F1_TARGET = "zoneUID del objetivo: %s"
  L.CHECK_F1_STATIC = "globales %d/%d presentes, eventos %d/%d válidos"
  L.CHECK_F1_ARMED  = "registro pasivo ACTIVADO (sobrevive a /reload). '/qdt check f1 off' lo borra."
  L.CHECK_F1_OFF    = "check f1: datos borrados, registro pasivo DESACTIVADO."
end
