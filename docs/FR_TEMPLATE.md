# FR-NNN — <Componente>: <título corto del cambio pedido>

**Solicitante:** <addon consumidor> · <pantalla/flujo> · <yyyy-mm-dd>
**Build vendoreado del solicitante:** <Lib vX.Y.Z (build N, sha) — la copia en la que se vio el bug o la carencia>
**Componente:** `<ruta del archivo en la lib>`
**Tipo:** Feature Request / Bug
**Prioridad:** <Alta/Media/Baja> — <a quién afecta y cuánto>
**No bloquea:** apaño <cuál: qué hace hoy el consumidor, marcado en su código con `-- FR-NNN: apaño, retirar`>
**Estado:** 🟡 Pendiente <!-- 🟡 Pendiente → 🔨 Implementado (sin verificar) → ✅ Cerrado: SOLO tras verificar in-game -->

---

## Problema

<Qué falta o qué está roto, con el comportamiento actual exacto.>

## Caso de uso (<consumidor>)

<El flujo real del consumidor que lo necesita, concreto: qué hace el usuario y qué se rompe.>

## Solución propuesta

### API
```lua
-- firma(s) propuesta(s), retrocompatibles si es posible
```

### Comportamiento
<Reglas del comportamiento nuevo, incluyendo defaults y edge cases.>

## Workaround actual (<consumidor>)

<El fallback que usa el consumidor mientras tanto — y por qué es frágil (p. ej. lee
internos `_privados`). Al implementarse el FR y re-vendorear, este workaround SE ELIMINA.>

## Criterio de aceptación

<Qué se tiene que ver o poder hacer, comprobable in-game en el addon de demo — una línea por
condición. Sin esto el FR no se puede cerrar: «parece que va» no es un criterio. Si es un bug,
el botón de repro de la demo reproduce la secuencia y deja de fallar.>

## Impacto

- **Breaking:** <sí/no — si cambia una firma pública o comportamiento existente>.
- **Superficie:** <API pública nueva / solo interno / tokens visuales>.

---

## Resolución

<!-- SE RELLENA AL CIERRE, en este MISMO archivo (patrón craft: problema→propuesta→decisión
     real quedan juntos, sin doc aparte). Cambia el Estado del encabezado a ✅ Resuelto. -->

**Estado:** ✅ Cerrado, released en `v<X.Y.Z>` (build <N>, commit `<hash>`), **verificado in-game** · **Fecha:** <yyyy-mm-dd>
<!-- Cerrar SOLO tras verificar el criterio de aceptación en el cliente; implementado ≠ cerrado. -->

- **Qué se implementó** y en qué se desvió de la propuesta (y por qué):
- **API pública final** (si cambió respecto a la propuesta):
- **Re-vendoreo:** consumidor actualizado al build `v<X.Y.Z>` (anotar en sus docs). Formato del
  commit en el consumidor: `chore(libs): re-vendorear <Lib> vX.Y.Z (<sha>): FR-NNN, <otros FRs>`;
  el apaño se retira en un `refactor` propio (`quita el apaño de FR-NNN`).
- **FRs hermanos:** <«Sigue a FR-NNN» si es continuación; una cola de FRs de un consumidor se
  cierra por lotes>.

---
Proceso: el FR se crea en `docs/requests/` del repo de la LIB (numeración correlativa).
El consumidor NO edita la lib: pausa/fallback hasta que el owner implementa, releasea y
se re-vendorea el build (anotando versión/commit).
