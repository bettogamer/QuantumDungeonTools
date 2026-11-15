# AGENTS.md — QuantumDungeonTools

> README ejecutable para agentes de IA. Fuente de verdad única del proyecto: si cambia una
> decisión, este archivo (y el ADR, si nivel M+) se actualizan en el mismo commit.
>
> **Estado (2026-11-14):** hito M1, F1-F6 en código (F6 ✅ in-game); falta la run de pruebas en mazmorra y el checklist de cierre → `docs/plan-m1-instance-tracker.md`.
> **Nivel de proceso:** M (ver AddonTemplate/docs/04-proceso.md).
>
> **TECHO: este archivo ≤ 150 líneas (nivel L: 250).** Se poda al cerrar cada hito y en cada
> release (`wc -l AGENTS.md`; `/check-conformance` lo mide). El changelog NO va aquí
> (`CHANGELOG.md`); las lecciones NO van aquí (`docs/LECCIONES.md`).
>
> <!-- ANTI DOC-DRIFT — dos lecciones reales, una en cada dirección:
>      (Loom) el header decía "SIN CÓDIGO" mientras el cuerpo ya describía v0.1.0 con 89 tests.
>      (Coffer) este blockquote creció a 87 líneas intentando contarlo todo... y AUN ASÍ mintió:
>      decía "F3 pendiente de verificar, 126/227" con el hito ya cerrado en 188/227.
>      Conclusión: el estado vive aquí y SOLO aquí, pero en UNA LÍNEA + puntero. Si necesitas
>      más de 3 líneas, lo que sobra pertenece al plan de hito. Ver doc 04 §Dónde vive cada
>      estado y §AGENTS.md «Techo y poda». Reincidencia medida en 2026-11: Coffer 611 líneas,
>      craft 557, SMRT 312 (una §lecciones que crece sola). -->

## 1. Identidad del producto

- **Nombre**: Quantum Dungeon Tools (QDT; «Quantum» es la guild del owner). Carpeta del addon:
  `QuantumDungeonTools/`, slash `/qdt`, SavedVariables `QuantumDungeonToolsDB`.
- **Dominio**: addon de WoW (cliente WoW Forever) con una caja de herramientas de mazmorra por módulos.
- **Resumen**: un solo addon con módulos en carpetas. Módulo 1 «Instance Tracker»: jefes
  muertos/restantes (X/Y + lista), cronómetro de la run con split por jefe, XP ganada en la
  mazmorra e historial de las últimas 20 runs. Futuro: «Minimap Lens» (minimapa grande en
  mazmorras). Público: el owner y su guild; publicación sin decidir.
- **Arquitectura**: `core/` puro (`Format.lua`, `Style.lua`: tokens del addon, los Style de módulo heredan con
  `Style.extend`); `wow/Bootstrap.lua` (DB, versión, arranque), `wow/Kit.lua` (tema Craft), `wow/MainWindow.lua`; `modules/InstanceTracker/core/Run.lua` (modelo puro), `.../wow/Tracker.lua` (eventos
  PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA, UPDATE_INSTANCE_INFO, ENCOUNTER_END, BOSS_KILL,
  PLAYER_XP_UPDATE), `.../core/{Style,View,Demo}.lua` (tokens, modelo de vista, demos), `.../wow/UI.lua` (widget HUD sobre Craft); `Config.lua` (slash).
  Frontera core/wow forzada por `.luacheckrc` `files{}`.
- **Idiomas**: inglés (por defecto) y **español latino** (esMX); esES recibe el mismo texto latino (owner, 2026-11-12).
- **Owner**: Alberto Gomez.

## 2. Contexto que el agente MUST leer antes de actuar

1. Este archivo completo.
2. <!-- nivel M+ --> `docs/adr/` — decisiones vigentes.
3. <!-- si aplica --> `docs/NORTH-STAR.md` — el norte innegociable.
4. `related-addons/` — referencia READ-ONLY: PENDIENTE (ninguno definido por ahora).
5. La regla global de taint/secret values de `~/.claude/CLAUDE.md` aplica y tiene prioridad.

## 3. Estructura del repositorio

```
/
├── AGENTS.md
├── docs/              00-contexto-sesion-origen.md (LEER), adr/ (por crear), NORTH-STAR, LECCIONES, plantillas
├── related-addons/    referencia READ-ONLY (gitignored, NO tocar, NO distribuir)
├── scripts/           deploy-local.ps1: espeja QuantumDungeonTools/ → _forever_\Interface\AddOns
├── tests/             lua tests/run.lua (core/, wow/, modules/<Nombre>/)
└── QuantumDungeonTools/     ← el addon (lo que se despliega)
    ├── QuantumDungeonTools.toc
    ├── Locale.lua     ← primero en el .toc
    ├── core/          lógica PURA compartida (Format.lua, Brand.lua, Style.lua: tokens del addon)
    ├── wow/           Bootstrap.lua (DB, versión, arranque), Kit.lua (tema Craft), MainWindow.lua
    ├── modules/
    │   └── InstanceTracker/
    │       ├── core/  Run.lua (modelo de la run) + Guid.lua + Style.lua (colores/tamaños del widget; hereda core/Style.lua)
    │       │          + View.lua (qué pinta el widget) + Detail.lua (tooltip Detalle) + Demo.lua
    │       └── wow/   Tracker.lua (eventos) + UI.lua (widget) + Page/HistoryTab.lua (página) + CheckF1/CheckF2.lua
    ├── libs/          LibStub, Weave, Craft vendoreadas READ-ONLY (versiones: libs/README.md)
    └── Config.lua     ← último: /qdt
```

Módulo nuevo = `modules/<Nombre>/{core,wow}/` + sus líneas en el `.toc` + su bloque en
`.luacheckrc` (core/ sin globals, wow/ con los suyos) + su arranque en `wow/Bootstrap.lua`.

## 4. Stack tecnológico autoritativo

| Capa | Tecnología | Nota |
|------|------------|------|
| Lenguaje | Lua 5.1 | sandbox WoW: sin `io`/`socket`/`os.time`/`require` externo |
| Interface (TOC) | `## Interface: 16001` | WoW Forever 1.60.x (motor de 12.1.5: aplican secret values), una sola `.toc`; **elige la base de datos de taintlint** — mantenerla al día. Instalación local: `F:\Games\World of Warcraft\_forever_\Interface\AddOns` |
| Libs vendoreadas | LibStub (minor 2), CallbackHandler-1.0 (8), LibDataBroker-1.1 (4), LibDBIcon-1.0 (57; icono del minimapa, owner 2026-11-14), Weave v0.10.0, **Craft v2.51.0** (build 53, @`e8ccb1b`) | READ-ONLY en `libs/` (tabla en `libs/README.md`); Craft con contexto de tema propio `QuantumDungeonTools` (FR-104) |
| Integraciones | ninguna | `## Dependencies` / `## OptionalDeps` |
| Lint | luacheck (`.luacheckrc`) + taintlint | doc 03 del estándar |
| Estándar | AddonTemplate `v1.2.0` | la versión contra la que se escribió este repo; `/check-conformance` la compara con la vigente |
| Testing | mini-runner `lua tests/run.lua` desde el root (descubre `tests/**/*_spec.lua`) + manual in-game (BugSack); autopruebas `/qdt check f1`/`f2` (lectores: `scripts/read-check-f1.lua`/`-f2.lua`) | ver §7 |

> MUST NOT introducir dependencias fuera de esta tabla <!-- nivel M+ -->sin ADR<!-- -->.

## 5. Reglas de dominio invariantes (MUST / MUST NOT)

<!-- Las genéricas del estándar aplican siempre (AddonTemplate/README.md §10 reglas).
     Aquí SOLO las específicas del proyecto. Ejemplos del formato: -->
- **MUST** guardar con `issecretvalue` (antes de CUALQUIER test de verdad) y `pcall` las APIs
  secretables: Forever usa el motor de 12.1.5.
- **MUST NOT** intentar flecha/posición del jugador dentro de mazmorras: `GetBestMapForUnit`,
  `UnitPosition` y `GetPlayerFacing` devuelven nil ahí (hecho medido in-game).
- **MUST** mantener `core/` puro (sin APIs de WoW); lo que toca el cliente vive en `wow/`.
- **MUST NOT** editar `related-addons/` ni `libs/` — integración solo por lectura (no hay integraciones).
- **MUST NOT** cambiar el schema de `QuantumDungeonToolsDB` sin migración por `_version` — y la
  migración se escribe solo contra lo PUBLICADO: compara con el último tag antes de subir
  `DB_VERSION` (doc 02 §SavedVariables).
- **Decisiones marcadas «del owner»** (alcance, dependencias, producto): se le preguntan, nunca
  se cierran sin él.
- **Craft vendoreada** (F2): bug o falta en Craft → FR en `craft/docs/requests/` + fallback local, nunca editar `libs/Craft`.

## 6. Convenciones de código

- **En INGLÉS: código, identificadores, comentarios in-code y mensajes de error de la API.**
  **En español: docs/, ADRs, descripciones `it("...")` de los tests y la conversación.**
  (Regla precisada en Weave: "código en inglés" incluye los comentarios.)
- Namespace por vararg: `local ADDON, ns = ...`.
- Módulos `PascalCase` en `ns.*`; funciones locales `camelCase`; constantes `UPPER_SNAKE`.
- Sin globals salvo `SLASH_*`.
- Trampas de Lua 5.1 y de frames: ver AddonTemplate/docs/02-arquitectura.md (aplican todas).

## 7. Verificación

1. `luac -p <archivo>` tras cada edición; `luacheck QuantumDungeonTools/ --config .luacheckrc` sin
   warnings nuevos; `npx taintlint QuantumDungeonTools/` (en local, re-córrelo tras tocar código
   sensible a secret values; en CI y desde la creación corre SIEMPRE, todos los niveles).
2. **El deploy lo corre EL AGENTE**, sin preguntar, siempre que vaya a pedir una prueba
   in-game (`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/deploy-local.ps1`).
   El owner solo hace `/reload` y reporta errores de BugSack (`/sack`).
3. **Autoprueba antes que guion**: lo verificable por código se comprueba con
   `/qdt check <fase>` (vuelca a `QuantumDungeonToolsDB._check*`; el agente lo lee con un reductor,
   sin capturas) y al owner solo le queda una pregunta visual corta. Si el addon es una lib, cada
   cambio trae su demo y deploy antes de pedir prueba.
4. El agente indica QUÉ probar: pasos, **campos a contrastar uno por uno** y valores esperados
   **ya calculados** con el mismo formateador de la UI. El guion vive en el plan de hito, no en
   el chat (estándar doc 04 §Verificación in-game). Simulaciones útiles:
   ```
   /run PENDIENTE (comandos de simulación de eventos aún no definidos)
   ```

## 8. Git / workflow

- Ramas: **trunk-based en `main`** (owner, 2026-11-12). Conventional Commits, en español.
- **Política de commits: a petición.** El agente commitea solo cuando el owner lo pide; nunca
  commit/push por iniciativa propia.
- **Sin trailers de co-autoría de IA ni atribuciones de herramientas en los commits** (nada
  de `Co-Authored-By: Claude ...` ni "Generated with..."). SIEMPRE, no solo en repos públicos.
- **MUST NOT `git push`** (lo hace el owner). El estado de push/tags se comprueba con
  `git ls-remote --tags origin`, no se anota.
- Releases: ritual en commits fijos (feat/fix → docs FR+spec → docs changelog → chore bump → tag
  anotado, doc 04 §Release); tag `v*` → `release.yml` (zip debe cubrir los archivos del `.toc`).

## 9. Lecciones / errores comunes del proyecto

**Las lecciones completas viven en `docs/LECCIONES.md`** (síntoma → causa → patrón correcto).
Aquí SOLO las reglas que muerden en cada sesión — **máximo 10, una línea cada una**, cada una
con puntero a su entrada:

- Aún sin lecciones propias (PENDIENTE: se añaden con el primer bug pagado).

<!-- NO dejes que esta sección crezca: SMRT llegó a ~140 líneas aquí y su AGENTS.md pasó de 312.
     Criterio de qué sube a LECCIONES.md: la lección REUSABLE; el gotcha de una fase concreta se
     queda en su plan de hito. Al podar (cierre de hito/release), lo que sobre baja a LECCIONES. -->

## 10. Dónde está el resto

<!-- NO pongas un registro de cambios aquí. Fue un error del estándar hasta 2026-08 (prescribía
     CHANGELOG.md en la raíz Y una tabla §10): dos changelogs = un changelog viejo. Coffer acabó
     con una tabla de 67 filas aquí y un CHANGELOG.md entero bajo "[Unreleased]". -->

- **Historial por versión** → `CHANGELOG.md` (se actualiza en el commit de la feature, no en el
  de release).
- <!-- nivel M+ -->**Hito en curso** (fases, decisiones del owner, gotchas) → `docs/plan-m1-instance-tracker.md` (contexto de origen y diseño: `docs/00-contexto-sesion-origen.md`).
- <!-- nivel M+ -->**Decisiones arquitectónicas** → `docs/adr/`.
- Publicación sin decidir (no CurseForge por ahora): sin `docs/curseforge/`.
