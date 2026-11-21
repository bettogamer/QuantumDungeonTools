# AGENTS.md — QuantumDungeonTools

> README ejecutable para agentes de IA. Fuente de verdad única del proyecto: si cambia una
> decisión, este archivo (y el ADR, si nivel M+) se actualizan en el mismo commit.
>
> **Estado (2026-11-20):** hito M1 en código y verificado (F1-F6f); release `0.1.0-beta.1` preparada para CurseForge (beta para la guild); pendiente la run de pruebas en mazmorra → `docs/plan-m1-instance-tracker.md`. M2 «Minimap Lens» **cerrado** (F0-F5), releases `0.1.0-beta.2` y `0.1.0-beta.3` publicadas; `0.1.0-beta.4` (2026-11-20, fixes del tracker) con tag local, pendiente de subir; restos a la run en mazmorra → `docs/plan-m2-minimap-lens.md`.
> **Nivel de proceso:** M (ver AddonTemplate/docs/04-proceso.md).
>
> **TECHO: este archivo ≤ 150 líneas (nivel L: 250).** Se poda al cerrar cada hito y en cada
> release (`wc -l AGENTS.md`; `/check-conformance` lo mide). El changelog NO va aquí
> (`CHANGELOG.md`); las lecciones NO van aquí (`docs/LECCIONES.md`).
>
> <!-- ANTI DOC-DRIFT: el estado vive aquí en UNA línea + puntero; el detalle, en el plan de hito (doc 04 §Dónde vive cada estado). -->

## 1. Identidad del producto

- **Nombre**: Quantum Dungeon Tools (QDT; «Quantum» es la guild del owner). Carpeta del addon:
  `QuantumDungeonTools/`, slash `/qdt`, SavedVariables `QuantumDungeonToolsDB`.
- **Dominio**: addon de WoW (cliente WoW Forever) con una caja de herramientas de mazmorra por módulos.
- **Resumen**: un solo addon con módulos en carpetas y una ventana principal (`/qdt`). Módulo 1
  «Instance Tracker»: widget con jefes restantes, reloj contra el récord con splits, XP, oro y
  reputación; avisos 10/hora, toast de fin de run e historial de 100 runs. Futuro: «Minimap Lens».
  Público: la guild del owner, vía **beta en CurseForge** (subida manual, `docs/curseforge/`).
- **Arquitectura**: `core/` puro (tokens, formato), `wow/` (Bootstrap, Kit = tema Craft, MainWindow,
  Minimap) y un `modules/<Nombre>/{core,wow}/` por módulo (mapa en §3). Frontera core/wow forzada
  por `.luacheckrc` `files{}`.
- **Idiomas**: inglés (por defecto) y **español latino** (esMX); esES recibe el mismo texto latino (owner, 2026-11-12).
- **Owner**: Alberto Gomez.

## 2. Contexto que el agente MUST leer antes de actuar

1. Este archivo completo.
2. <!-- nivel M+ --> `docs/adr/` — decisiones vigentes.
3. `docs/NORTH-STAR.md` (el norte) y `related-addons/` (referencia READ-ONLY, gitignored).
4. La regla global de taint/secret values de `~/.claude/CLAUDE.md` aplica y tiene prioridad.

## 3. Estructura del repositorio

```
/
├── AGENTS.md
├── docs/              plan de hito, LECCIONES, NORTH-STAR, curseforge/ (textos y checklist de subida)
├── related-addons/    referencia READ-ONLY (gitignored, NO tocar, NO distribuir)
├── scripts/           deploy-local.ps1 (→ _forever_\Interface\AddOns), build-dist.ps1 (zip de release)
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
    ├── libs/          LibStub, CallbackHandler, LDB, LibDBIcon, Weave, Craft READ-ONLY (libs/README.md)
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
| Testing | mini-runner `lua tests/run.lua` desde el root (descubre `tests/**/*_spec.lua`) + manual in-game (BugSack); autopruebas `/qdt check f1`/`f2`/`m2` (lectores: `scripts/read-check-*.lua`) | ver §7 |

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

1. `luac -p <archivo>` tras cada edición; luacheck con ARCHIVOS explícitos (sin lfs no recorre
   carpetas) sin warnings nuevos; `npx taintlint QuantumDungeonTools/` tras tocar código sensible
   a secret values (en CI corre SIEMPRE, pineado a v0.5.0).
2. **El deploy lo corre EL AGENTE**, sin preguntar, siempre que vaya a pedir una prueba
   in-game (`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/deploy-local.ps1`).
   El owner solo hace `/reload` y reporta errores de BugSack (`/sack`).
3. **Autoprueba antes que guion**: lo verificable por código se comprueba con
   `/qdt check <fase>` (vuelca a `QuantumDungeonToolsDB._check*`; el agente lo lee con un reductor,
   sin capturas) y al owner solo le queda una pregunta visual corta. Si el addon es una lib, cada
   cambio trae su demo y deploy antes de pedir prueba.
4. El agente indica QUÉ probar: pasos, **campos a contrastar uno por uno** y valores esperados
   **ya calculados** con el mismo formateador de la UI. El guion vive en el plan de hito, no en
   el chat (estándar doc 04 §Verificación in-game). Demos: `/qdt it demo <live|done|first|compact>`.

## 8. Git / workflow

- Ramas: **trunk-based en `main`** (owner, 2026-11-12). Conventional Commits, en español.
- **Política de commits: agente autónomo** (owner, 2026-11-13): commitea sin preguntar en `main`
  tras luac/luacheck/tests en verde, revisando `git diff --cached --name-only`.
- **Sin trailers de co-autoría de IA ni atribuciones de herramientas en los commits** (nada
  de `Co-Authored-By: Claude ...` ni "Generated with..."). SIEMPRE, no solo en repos públicos.
- **MUST NOT `git push`** (lo hace el owner). El estado de push/tags se comprueba con
  `git ls-remote --tags origin`, no se anota.
- Releases: **ruta D** (doc 04 §Release): CHANGELOG + NewsData → tag anotado local →
  `scripts/build-dist.ps1 -Version X.Y.Z[-beta.N]` → subida manual (`docs/curseforge/upload.md`) →
  aprobada → push del tag. Sin `release.yml` (owner, 2026-11-15).

## 9. Lecciones / errores comunes del proyecto

**Las lecciones completas viven en `docs/LECCIONES.md`** (síntoma → causa → patrón correcto).
Aquí SOLO las reglas que muerden en cada sesión — **máximo 10, una línea cada una**, cada una
con puntero a su entrada:

- Aún sin lecciones propias (PENDIENTE: se añaden con el primer bug pagado).

## 10. Dónde está el resto

- **Historial por versión** → `CHANGELOG.md` (se actualiza en el commit de la feature, no en el
  de release).
- <!-- nivel M+ -->**Hito en curso** (fases, decisiones del owner, gotchas) → `docs/plan-m1-instance-tracker.md` (contexto de origen y diseño: `docs/00-contexto-sesion-origen.md`).
- <!-- nivel M+ -->**Decisiones arquitectónicas** → `docs/adr/`.
- **Publicación** → `docs/curseforge/` (ficha, checklist, textos en inglés). Licencia: All Rights Reserved (`LICENSE`).
- **Deuda declarada** (conformidad 2026-11-15, `docs/20-conformidad-beta1.md`): sin ADR en
  `docs/adr/` (las decisiones viven en el plan de hito) y `.toc` sin bloque `# >>> vendored-libs`
  ni `scripts/vendor-libs.ps1` (libs copiadas a mano; versiones en `libs/README.md`).
