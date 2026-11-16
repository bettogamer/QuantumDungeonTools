# CurseForge — Ficha del proyecto y checklist de subida

> En **español** (es para el owner y los agentes). Arriba, los datos del proyecto, que se escriben
> una vez. Abajo, la checklist de **cada** subida manual (ruta D, AddonTemplate doc 03 §7).
> Lo marcado _(no confirmado)_ no está en la documentación oficial de CurseForge: verificarlo en
> la primera subida y quitar la marca.

## Ficha del proyecto

| Dato | Valor |
|------|-------|
| URL pública | ✅ `https://www.curseforge.com/wow/addons/qdt` (slug `qdt`) |
| Project ID | ✅ `1801831` |
| Nombre | `Quantum Dungeon Tools` |
| Categoría principal + extra | ⬜ propuesta: `Dungeons & Raids` (+ `Map & Minimap`) |
| Licencia | ⬜ **decisión del owner**: el repo no tiene `LICENSE` todavía (CurseForge pide elegir una) |
| Logo | ⬜ no hay icono propio del addon (el del minimapa es provisional de Blizzard) |
| Flavors publicados | ⬜ WoW Forever (`## Interface: 16001`): comprobar que CurseForge lo ofrece en Supported Versions |
| Relations por defecto | Embedded Library: LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0 (Craft y Weave son libs propias, no están en CurseForge) |
| Textos | `description.md`, `summary.md` (199/256), `changelog.md` de esta carpeta |
| Primera publicación | ⬜ `0.1.0-beta.1` — subida el `<fecha>`, aprobada el `<fecha>` |

## Checklist de cada subida

Antes (en el repo):

- [ ] Ritual de release hecho (doc 04 §Release): CHANGELOG → commit → **tag local**.
- [ ] `docs/curseforge/changelog.md` **reescrito** para ESTA subida, en inglés, desde la última
      versión **publicada**.
- [ ] `powershell -ExecutionPolicy Bypass -File scripts/build-dist.ps1 -Version X.Y.Z[-beta.N]`
      en verde → `dist/QuantumDungeonTools-vX.Y.Z.zip`.

En el formulario (Upload File):

- [ ] **File**: el zip de `dist/`, sin re-zipear a mano.
- [ ] **Display Name**: `Quantum Dungeon Tools vX.Y.Z`.
- [ ] **Release Type**: `Beta` mientras la versión lleve `-beta.N` (los Beta solo los ve quien
      los activa: decirles a los amigos que activen «Beta» en su cliente/app de CurseForge).
- [ ] **Supported Versions**: marcar a mano la de WoW Forever.
- [ ] **Changelog**: pegar `docs/curseforge/changelog.md` (campo obligatorio).
- [ ] **Relations**: las por defecto de la ficha.

Después:

- [ ] El archivo queda **Under Review**; no resubir mientras está pendiente.
- [ ] Aprobado y visible → `git push origin vX.Y.Z` (el tag se pushea DESPUÉS; hoy el repo
      no tiene remote: crearlo antes del primer push).
- [ ] Estado del release anotado: commiteado / tag local / subido / aprobado / pusheado.
