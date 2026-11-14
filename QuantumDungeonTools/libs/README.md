# libs/ — vendoreadas READ-ONLY

Nunca editar estas copias. Bug o feature faltante → FR en el repo de la lib
(`craft/docs/requests/FR-NNN-<slug>.md`) + fallback local; se re-vendorea el siguiente build
etiquetado. Cada build se copia **sin su `libs/` interno**: LibStub y Weave se cargan una sola
vez a nivel de QuantumDungeonTools (ver el `.toc`).

Orden de carga en el `.toc`: **LibStub → Weave → Craft** (Craft `Reactive.lua` necesita Weave
cargado antes). El bloque de Craft es espejo del orden de `Craft.toc`.

| Lib | Versión vendoreada | Origen | Fecha |
|---|---|---|---|
| LibStub | minor 2 | `craft/Craft/libs/LibStub/` @`ac2ebb3` (copia de Craft v2.47.0) | 2026-11-12 |
| Weave | **v0.10.0** (`LibStub("Weave-1.0")`, MINOR 11) | `craft/Craft/libs/Weave/` (sin su `libs/`) @`ac2ebb3` — la Weave embebida en Craft v2.47.0 | 2026-11-12 |
| Craft | **v2.49.0** (`LibStub("Craft-2.0")`, build 51) | `craft/Craft/` (sin su `libs/`) @`2ad00fb` (tag `v2.49.0`, FR-150), `media/` completo (atlas Lucide 16/32/64, Inter, Geist, BettoSans, BettoGeo, shapes + `shape_cring_*`). `media/` se resuelve por `_hostName` → `Interface\AddOns\QuantumDungeonTools\libs\Craft\media\`. LibStub y Weave sin cambios respecto a `ac2ebb3` | 2026-11-13 |

## Cómo re-vendorear

1. En `craft/`: build etiquetado, árbol limpio (`git status` vacío, `git describe --tags`).
2. Borrar y recopiar: `craft/Craft/libs/LibStub` → `libs/LibStub`, `craft/Craft/libs/Weave`
   (sin su `libs/`) → `libs/Weave`, `craft/Craft` (sin su `libs/`) → `libs/Craft`.
3. Si `Craft.toc` ganó o perdió archivos, regenerar el bloque de Craft del `.toc` en el mismo
   orden.
4. Actualizar esta tabla (versión, commit, fecha) y la fila de AGENTS.md §4.
