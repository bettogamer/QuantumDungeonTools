## Conformidad — QuantumDungeonTools (nivel M)

**Fecha:** 2026-11-15 · **Estado declarado:** «hito M1, F1-F6 en código (F6 ✅ in-game); falta la run de pruebas en mazmorra y el checklist de cierre» (línea de estado fechada 2026-11-14) · **Estado real:** `.toc` con `## Version: @project-version@`, sin ningún tag (`git describe` falla), último commit 2026-11-15 «F6f verificada in-game», CHANGELOG entero bajo `[Unreleased]`, plan M1 con F6f ✅ in-game (2026-11-15). Estándar declarado `v1.2.0` = vigente (`v1.2.0`): nada pendiente de adoptar.

### Resumen

| Área | Veredicto |
|------|-----------|
| Documentos y estado | ⚠️ |
| Frontera de capas | ✅ |
| Tests y CI | ⚠️ |
| Cadena de verificación | ✅ |
| Agentes y scripts | ⚠️ |

Cadena medida (local): luac -p OK en todos los .lua del addon; `lua tests/run.lua` → 17 spec files, 195 ok, 0 fallos; luacheck 55 archivos, 0 warnings / 0 errors; taintlint (db 1.60.1, de `## Interface: 16001`) 95 archivos, 0/0/0; `check-upvalues` 32 archivos OK (max 55).

### Hallazgos (ordenados por coste de revertir)

1. **Contradicción política de commits / atribución (alto: afecta al historial público).** `AGENTS.md` §8 dice «a petición» y «sin trailers de co-autoría de IA», mientras `CLAUDE.md` dice «el agente puede commitear sin preguntar» (owner 2026-11-13). El estándar manda declarar UNA política. Acción: arreglar `AGENTS.md` §8 («Política de commits: agente autónomo en `main`, push solo a petición del owner») y decidir con el owner si los trailers de co-autoría se permiten; hoy dos instrucciones del proyecto se contradicen y el repo va a hacerse público.
2. **`AGENTS.md` dice «Publicación sin decidir (no CurseForge por ahora): sin `docs/curseforge/`» (§1 y §10)** pero se prepara la beta. Acción: reescribir en el mismo commit que cree `docs/curseforge/` (ruta D, manual) y quitar «publicación sin decidir» del resumen de §1. (Es doc-drift inminente, no esperar al tag.)
3. **`AGENTS.md` 167 líneas (techo 150).** Solo se reporta la cifra (poda en curso). Las secciones no tienen «Registro de cambios» ni §lecciones larga: §9 es una sola línea de placeholder.
4. **Estado desfasado de la realidad:** línea de estado fechada 2026-11-14; plan y último commit son del 2026-11-15 (F6f ✅ in-game). Acción: actualizar la línea de estado (1 línea) al cerrar la beta, con fecha y «0.1.0-beta.1».
5. **`.github/workflows/ci.yml`, job `lua51` no ejecuta `check-upvalues`** (solo `luac -p` 5.1). El estándar (doc 03) pide sintaxis 5.1 + `check-upvalues`; el script existe en `scripts/` y pasa en local. Acción: añadir un paso `lua scripts/check-upvalues.lua $(find QuantumDungeonTools -name '*.lua' -not -path '*/libs/*')` al job `lua51`.
6. **Pin de taintlint:** `bettogamer/taintlint@v0` sin `version:`. Vale mientras no haya release; en cuanto se publique la beta (hay release), el estándar pide `@v0.5.0` + `version: 0.5.0`. Acción: pinear en el commit del tag. Nota: el `path:` apunta a la carpeta del addon (correcto).
7. **`release.yml` no equivale a la ruta D:** sustituye `@project-version@` con `sed` y empaqueta con `zip -r` (sirve para GitHub Release, no para CurseForge); no acepta `-beta.N` en el nombre ni valida mayúsculas del `.toc`. Reportar tras llegar `scripts/build-dist.ps1`: decidir si `release.yml` se elimina, se alinea o se deja solo para GitHub (sin remoto aún, nunca ha corrido).
8. **Sin ADR en `docs/adr/` (directorio vacío), nivel M exige al menos uno.** Decisiones ya tomadas candidatas: núcleo puro + `files{}` por capa, Craft vendoreado con contexto de tema propio, Interface 16001 (Forever), icono de minimapa con LibDBIcon. Acción: crear un ADR al menos para la elección de cliente/Interface (ver 9). No bloquea la beta, pero va en el AGENTS.md como «MUST sin ADR».
9. **`## Interface: 16001` ≠ `120105` del estándar: es divergencia consciente (cliente WoW Forever, db 1.60.1) y correcta.** Pero para una subida pública a CurseForge conviene que el owner confirme el game version / flavor que ofrece CurseForge para Forever (un solo `.toc` con 16001 no se instala en retail). Esto es decisión del owner; no hay ADR que lo registre (ver 8).
10. **Idioma del código (comentarios en inglés):** la sonda da solo 4 comentarios en español reales, todos en tests (`History_spec.lua:115`, `View_spec.lua:223`); el resto de coincidencias son nombres de artboard entre comillas. Bajo coste; pasar a inglés en un solo commit o declarar que los comentarios de specs van en español. No bloquea.
11. **`## Notes:` de `.toc`:** correcto (inglés base + esES/esMX). Sin `## Dependencies`/`OptionalDeps` (declarado «ninguna»).
12. **Agentes:** están `addon-scout`, `error-triager`, `doc-writer`, `verifier` y `ui-critic` (hay UI propia), más `scribe` (extra, no es problema). Sin `TODO(new-addon)` ni `instantiator-runner`. `CLAUDE.md` 65 líneas, puntero fino (límite ~60: pasado por 5; no grave).
13. **`.toc` sin bloque `# >>> vendored-libs` / `# <<< vendored-libs`** y no existe `scripts/vendor-libs.ps1`: las libs (LibStub, CallbackHandler, LDB, LibDBIcon, Weave, Craft) están enumeradas a mano en el `.toc`. `libs/README.md` documenta versiones y commits (bien, versión de Craft anotada: v2.51.0 build 53 @`e8ccb1b`). `/qdt info` sí existe (`Config.lua`). Acción: declarar deuda o generar el bloque con el script del estándar antes de subir. Riesgo menor: `libs/README.md` aún dice Craft v2.51.0 pero el CHANGELOG [Unreleased] menciona «Craft v2.50.0 re-vendoreada» — comprobar cuál es la versión real vendoreada.
14. **Scripts PS:** `bump-build.ps1` menciona `Get-Content/Set-Content` solo en un comentario de advertencia (sin uso real). OK. `deploy-local.ps1` y `.bat` presentes.
15. **`.gitignore`/`.gitattributes`:** correctos (`related-addons/`, `*.zip`, `dist/`, `settings.local.json`; sin comentarios a final de línea; `.gitattributes` marca `.tga/.ttf` binarios y hay `.tga` trackeados).
16. **Versión en runtime:** `ns.resolveVersion` en `wow/Bootstrap.lua:61` degrada el token `@project-version@` correctamente. Mini-runner con `local print = print` OK.
17. **CHANGELOG:** existe, pero todo está bajo `## [Unreleased]` (sin ningún tag es esperable). Acción: en el commit de release renombrar a `## [0.1.0-beta.1] - fecha`.
18. **Memoria del agente:** 7 notas, todas feedback/referencia, ninguna por FR ni por release. Sin duplicados del CHANGELOG. Sin poda necesaria.
19. **Publicación CurseForge:** `scripts/build-dist.ps1` y `docs/curseforge/` aún no existen: EN CURSO (no es hallazgo). Pendiente de verificar cuando lleguen: nombre `.toc` = `QuantumDungeonTools.toc` coincide en mayúsculas con la carpeta (✔ hoy, un único `.toc`), `-beta.N` aceptado, changelog con la versión del último tag, Project ID vacío hasta publicar.

### Frontera de capas

- Estructura `core/` + `wow/` existe (raíz y `modules/InstanceTracker/`).
- Frontera **realmente enforced**: `globals` de nivel superior solo contiene `LibStub`; cada capa `wow/` declara los suyos en `files{}` y `core/` queda con `{}`. Cumple el test mecánico.
- Módulos puros con specs headless: `core/Format`, `core/Style`, `InstanceTracker/core/{Run,View,Style,Demo}` (16 de los 17 spec files caen en `tests/core` y `tests/modules/InstanceTracker`; 1 en `tests/wow`).
- Nota menor: la lista `globals` de `wow/` repite `print`, `LibStub`, `CreateFrame`; no es problema. No se detectan globals eliminados por parche (`GetItemInfo`, `GetDetailedItemLevelInfo`, `MouseIsOver` no aparecen).

### Tests y CI

- 17 spec files (5 `tests/core`, 11 `tests/modules/InstanceTracker`, 1 `tests/wow`); 195 tests OK en local. El job `test` corre `lua tests/run.lua` **sin argumentos** (descubre todo, cubre las 3 carpetas) sobre Lua 5.1. Jobs presentes: lint (luacheck sobre la carpeta con `nebularg/actions-luacheck`, que sí acepta carpeta), lua51, test, taintlint. CI nunca ha corrido (sin remoto): el contenido es conforme salvo hallazgos 5 y 6.

### Deuda ya declarada (no son hallazgos)

- `## Interface: 16001` (Forever) en vez de `120105`: declarado en AGENTS.md §4, db de taintlint 1.60.1 confirmada.
- Libs vendoreadas READ-ONLY con FR a Craft (declarado en §5 y `libs/README.md`).
- §9 de AGENTS.md sin lecciones propias («PENDIENTE»): lecciones reales viven en `docs/LECCIONES.md` (76 líneas). Confirmar si sigue teniendo sentido el placeholder.

### Antes de la beta pública (resumen)

Arreglar: 1 (política de commits/atribución), 2 (AGENTS.md y publicación), 5 (check-upvalues en CI), 6 (pin taintlint al publicar), 7 (decisión sobre `release.yml`), 13 (comprobar versión de Craft vendoreada y bloque de libs), 17 (cabecera del CHANGELOG). El resto puede ir a deuda declarada.
