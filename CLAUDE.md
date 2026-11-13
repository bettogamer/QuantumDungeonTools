# QuantumDungeonTools — Claude Code

> Leer **`AGENTS.md`** — fuente de verdad única (reglas, arquitectura, stack, guardrails) — y
> `docs/LECCIONES.md` para los bugs ya pagados. Este archivo es un PUNTERO FINO (≤ ~60 líneas):
> no es una segunda casa para lecciones, estado ni changelog.
> Las instrucciones globales de `~/.claude/CLAUDE.md` (taint/secret values, vendoring de
> Craft) aplican y tienen prioridad.

## Comandos rápidos

```bash
luac -p <archivo>                                  # sintaxis, tras cada edición (lua local 5.4: solo sintaxis; el target es 5.1)
lua tests/run.lua                                  # mini-runner (descubre tests/**/*_spec.lua), desde el root
luacheck QuantumDungeonTools/Config.lua QuantumDungeonTools/core/Format.lua <...> --config .luacheckrc  # lint — cero warnings nuevos (sin lfs: archivos EXPLÍCITOS, no carpetas)
npx taintlint QuantumDungeonTools/ --min-severity warning # re-run local tras tocar código sensible a secrets; en CI corre SIEMPRE (sin npx: node <ruta>/taintlint/dist/cli.js QuantumDungeonTools.toc)
powershell -File scripts/deploy-local.ps1          # espejar a Interface\AddOns (lo corre el agente antes de pedir prueba in-game, ver AGENTS.md §7)
```
<!-- Verificar estas invocaciones al crear el proyecto y dejar aquí las REALES de la máquina
     (rutas, caveats) — lección Weave: la cadena entera debe FUNCIONAR antes del primer commit. -->

## Subagentes del proyecto (`.claude/agents/`)

- **addon-scout** (Sonnet, read-only) — localizar código/patrones, investigar API WoW.
- **error-triager** (Sonnet, read-only) — diagnosticar errores Lua de BugSack.
- Política de modelos: lectura/diagnóstico → Sonnet; escritura sensible → agente principal.
  Ediciones mecánicas con modelos baratos SOLO en archivos sin código a mano (ver
  AddonTemplate/docs/04-proceso.md).

## Disciplina de tokens

<!-- Lección real medida (Coffer, 2026-07-04): 46% del presupuesto de una sesión en un día de
     investigación, por acumular informes en el hilo principal. Detalle: doc 04 §Disciplina. -->

1. **Los agentes de investigación ESCRIBEN su output a `docs/` ellos mismos** y devuelven ≤20
   líneas + la ruta. Devolver el informe completo se paga dos veces (recibirlo + re-escribirlo)
   y se queda en contexto para siempre.
2. **Una sesión por hito/fase.** Al cerrar una fase, sesión nueva: AGENTS.md + <!-- nivel M+ -->el
   plan de hito + <!-- -->la memoria recargan el estado barato. Arrastrar 150k tokens de
   investigación multiplica el coste de CADA tool call posterior.
3. Bursts de scaffolding → al **INICIO** de una sesión fresca, no al final de una pesada.
4. Lookups en `related-addons/` → `addon-scout`, nunca Reads en el hilo principal.
5. **Datos masivos (volcados, SavedVariables, logs): reductor o subagente, nunca `Read` directo.**
6. **Avisar cuando la sesión se pone grande** (~50 %, al cerrar un hito, antes de un trabajo
   caro) y proponer sesión nueva con el **handoff ya escrito** en `docs/` o memoria — nunca solo
   en el chat.
7. **`/code-review` en `high` cuesta ~60 % de una sesión** (Coffer): por defecto, el diff propio
   inline o `low`; `high` solo acotado o si el owner lo pide.
8. **No crear ADR/FR/plan/docs que no se pidieron**: «documenta» sin formato = nota en el doc
   existente, o preguntar. Las decisiones «del owner» se le preguntan, no se cierran.
9. **La memoria del agente guarda reglas y feedback, no historial** (eso es CHANGELOG + FR); se
   poda al cerrar cada hito. «Faltan N por pushear» no se anota: `git ls-remote`.

## Agentes nuevos

Un `.claude/agents/*.md` creado a mitad de sesión **no se activa hasta la siguiente**: créalos
antes de usarlos, o invoca `general-purpose` diciéndole que lea el `.md`.

## Notas específicas de Claude Code

<!-- Solo lo que no cabe en AGENTS.md: p. ej. límites de gasto, qué probar tras cada fase,
     bugs de producción encontrados con su patrón correcto (estilo craft/CLAUDE.md). -->

- **Commits: el agente puede commitear sin preguntar** cuando lo necesite (owner, 2026-11-13):
  en `main`, Conventional Commits en español, tras luac/luacheck/tests en verde y revisando
  `git diff --cached --name-only`. **Push: solo si el owner lo pide.**
