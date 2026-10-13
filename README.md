# Claude Engineering System

Sistema personal de ingeniería de software para Claude Code. Una única fuente versionada que despliega configuración global en `~/.claude/` para que esté disponible en todos los proyectos.

## Componentes desplegados

| Componente | Fuente (repo) | Destino global | Estado |
|-----------|--------------|----------------|--------|
| Principios globales | `global/CLAUDE.md` | `~/.claude/CLAUDE.md` | ✅ Verificado |
| Agente architect | `agents/architect.md` | `~/.claude/agents/architect.md` | ✅ Verificado |
| Agente security | `agents/security.md` | `~/.claude/agents/security.md` | ✅ Verificado |
| Agente performance | `agents/performance.md` | `~/.claude/agents/performance.md` | ✅ Verificado |
| Agente reviewer | `agents/reviewer.md` | `~/.claude/agents/reviewer.md` | ✅ Verificado |
| Permisos globales | `global/settings.json` | `~/.claude/settings.json` (merge) | ✅ Verificado |
| Comando audit-module | `.claude/commands/audit-module.md` | `~/.claude/commands/audit-module.md` | ⚠️ Pendiente verificación global |
| Comando investigate-bug | `.claude/commands/investigate-bug.md` | `~/.claude/commands/investigate-bug.md` | ⚠️ Pendiente verificación global |
| Comando safe-refactor | `.claude/commands/safe-refactor.md` | `~/.claude/commands/safe-refactor.md` | ⚠️ Pendiente verificación global |
| Comando pre-commit-review | `.claude/commands/pre-commit-review.md` | `~/.claude/commands/pre-commit-review.md` | ⚠️ Pendiente verificación global |

> **Nota sobre commands globales**: `~/.claude/commands/` como ubicación global no está confirmada en la documentación oficial de Claude Code 2.1.87. Los comandos funcionan con certeza desde `.claude/commands/` en el directorio del proyecto. La verificación global requiere abrir una sesión desde otro proyecto y comprobar si aparecen como skills.

## Instalación inicial (WSL2)

```bash
git clone git@github.com:DaniSick/claude-engineering-system.git ~/claude-engineering-system
cd ~/claude-engineering-system
bash scripts/setup.sh
```

### Verificar el despliegue

```bash
bash scripts/setup.sh --verify
```

Salida esperada: todos los archivos en estado `OK`.

### Verificación manual de agents (desde otro proyecto)

1. Abre Claude Code en cualquier otro directorio
2. Escribe `@architect` — debe responder como analista de arquitectura
3. Si no responde, los agentes están ausentes o hay un problema de carga

### Verificación manual de commands globales (pendiente)

1. Abre Claude Code en un directorio **diferente** a este repositorio
2. Escribe `/audit-module` — si aparece como skill disponible, `~/.claude/commands/` funciona globalmente
3. Si no aparece, los commands solo funcionan desde este repositorio

## Actualización desde GitHub

```bash
cd ~/claude-engineering-system
git pull
# Revisar cambios recibidos antes de desplegar:
git log --oneline -5
git diff HEAD~1
# Desplegar si los cambios son correctos:
bash scripts/setup.sh
```

> El instalador no hace `git pull` automáticamente. Revisa siempre los cambios antes de desplegar.

## Reinstalación segura

```bash
bash scripts/setup.sh
```

El instalador es idempotente: omite archivos sin cambios, hace backup antes de sobrescribir y nunca elimina archivos globales sin ser explícito.

## Backups y restauración

Los backups se almacenan en `~/.claude/backups/ces/` con timestamp:

```
~/.claude/backups/ces/
├── root/           # CLAUDE.md backups
├── agents/         # agent file backups
├── commands/       # command file backups
├── settings/       # settings.json backups
└── manifest.json   # archivos gestionados por este sistema
```

Para restaurar un archivo específico:

```bash
# Ejemplo: restaurar CLAUDE.md desde el backup más reciente
ls ~/.claude/backups/ces/root/
cp ~/.claude/backups/ces/root/CLAUDE.md.20261013_102327 ~/.claude/CLAUDE.md
```

## Estructura del repositorio

```
.
├── global/                    # → ~/.claude/
│   ├── CLAUDE.md              # principios globales de ingeniería
│   └── settings.json          # referencia de permisos (merge aditivo)
├── agents/                    # → ~/.claude/agents/
│   ├── architect.md           # análisis de arquitectura (solo lectura)
│   ├── security.md            # auditoría de seguridad (solo lectura)
│   ├── performance.md         # análisis de rendimiento (solo lectura)
│   └── reviewer.md            # revisión de cambios (solo lectura)
├── templates/
│   └── project-CLAUDE.md      # plantilla genérica para proyectos
├── hooks/
│   └── README.md              # diseño de hooks (pendiente WSL2)
├── docs/
│   ├── audit-baseline.md      # auditoría del estado inicial
│   ├── architecture.md        # decisiones de diseño
│   └── agents-inventory.md    # guía de uso de agentes
├── scripts/
│   └── setup.sh               # instalador idempotente
└── .claude/
    ├── settings.json          # permisos del proyecto (este repo)
    └── commands/              # → ~/.claude/commands/ (y uso local)
        ├── audit-module.md
        ├── investigate-bug.md
        ├── safe-refactor.md
        └── pre-commit-review.md
```

## Uso de agentes

Disponibles en cualquier sesión de Claude Code:

```
@architect analiza la estructura de módulos en src/
@security revisa el directorio de autenticación
@performance encuentra queries redundantes en la capa de acceso a datos
@reviewer revisa el diff actual antes de hacer commit
```

## Uso de comandos/skills

**Desde este repositorio** (confirmado):
```
/audit-module
/investigate-bug
/safe-refactor
/pre-commit-review
```

**Desde otros proyectos** (pendiente verificación global — ver nota arriba).

## Configurar un proyecto

Copia la plantilla a la raíz del proyecto y completa las secciones:

```bash
cp ~/claude-engineering-system/templates/project-CLAUDE.md ~/mi-proyecto/CLAUDE.md
```

Los principios globales se cargan automáticamente. El `CLAUDE.md` del proyecto agrega contexto local (stack, arquitectura, restricciones).

## Añadir nuevas capacidades

| Capacidad | Ubicación en el repo | Acción |
|-----------|---------------------|--------|
| Nuevo agente global | `agents/<nombre>.md` | Añadir frontmatter `name:` y `description:`, ejecutar `setup.sh` |
| Nuevo comando | `.claude/commands/<nombre>.md` | Añadir frontmatter `description:`, ejecutar `setup.sh` |
| Nuevo permiso global | `global/settings.json` → `permissions.allow` | Ejecutar `setup.sh` (merge aditivo) |
| Nuevo hook | `hooks/<nombre>.sh` | Implementar, probar en WSL2, ejecutar `setup.sh` |

## Diagnóstico

**Agente no detectado:**
```bash
ls ~/.claude/agents/
bash scripts/setup.sh --verify
```

**Skill/comando no aparece:**
- Desde este repositorio: el comando debe aparecer con `/nombre`
- Desde otro repositorio: `~/.claude/commands/` puede no estar soportado en 2.1.87

**settings.json corrompido:**
```bash
python3 -m json.tool ~/.claude/settings.json
# Si falla, restaurar desde backup:
ls ~/.claude/backups/ces/settings/
cp ~/.claude/backups/ces/settings/settings.json.<timestamp> ~/.claude/settings.json
```

**Ejecutar setup.sh desde cualquier directorio:**
```bash
bash ~/claude-engineering-system/scripts/setup.sh
```

## Limitaciones conocidas

- `~/.claude/commands/` como ubicación global: **no verificado** en Claude Code 2.1.87
- Hooks: no desplegados — el comportamiento en WSL2 (binario Windows) está sin confirmar
- Skills del marketplace (`~/.claude/skills/synced/`): sincronizadas por Claude Code, no gestionadas por este sistema
- Los backups de settings se hacen solo cuando hay cambios reales en `permissions.allow`

## Requisitos

- Claude Code >= 2.1.87
- Linux / macOS / WSL2
- `bash`, `git`, `python3`, `sha256sum`
