# reveng CLI — Specification

## Overview

`reveng` is a standalone bash CLI that wraps the existing claude-legacy-reveng-plugin, providing a command-driven developer experience for reverse engineering legacy applications within Defra's Legacy Application Programme (LAP).

It is a companion to [ralph](https://github.com/DEFRA/ralph) (the autonomous AI coding agent loop runner used in the re-engineering phase). Ralph handles re-engineering (`ralph plan`, `ralph build`); reveng handles reverse engineering (`reveng curate`, `reveng analyse`, `reveng synthesise`, `reveng decompose`). The two tools share conventions but are independently installable.

## Design Principles

- **Headless by default** — commands run non-interactively end-to-end and produce output files
- **Sensible defaults, escape hatches for power users** — works out of the box for newcomers, with flags for model selection, verbosity, and backend control
- **Mirror ralph's conventions** — single bash script, `cmd_<name>` functions, similar flag style, same installation layout pattern
- **Warn outside containers** — prints a safety warning when `--dangerously-skip-permissions` is used outside a devcontainer (like ralph does)

## Target Audience

Mixed teams: some developers familiar with Claude Code internals, others encountering it for the first time. The CLI abstracts away `--plugin-dir`, model flags, and permission flags behind simple commands, but exposes them as options for those who need control.

## Repository

Lives in the existing `claude-legacy-reveng-plugin` repo. The repo gains:

```
claude-legacy-reveng-plugin/
├── reveng                    # CLI script (new)
├── install.sh                # Installer (new)
├── specs/
│   └── reveng-cli.md         # This spec
├── .claude-plugin/
│   └── plugin.json
├── skills/
├── agents/
├── hooks/
├── scripts/                  # Existing batch curation script etc.
├── CLAUDE.md
└── README.md
```

## Installation

### Layout

`install.sh` copies files to:

| Source | Destination |
|--------|------------|
| `reveng` | `~/.local/bin/reveng` |
| `skills/`, `agents/`, `hooks/`, `.claude-plugin/`, `CLAUDE.md` | `~/.config/reveng/plugin/` |

Override with `REVENG_BIN_DIR` and `REVENG_CONFIG_DIR` environment variables.

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed and authenticated
- Bash 4+
- `jq` (for parsing Claude output in headless mode)

### Install

```bash
git clone https://github.com/DEFRA/claude-legacy-reveng-plugin
cd claude-legacy-reveng-plugin
./install.sh
```

### Uninstall

```bash
rm ~/.local/bin/reveng
rm -rf ~/.config/reveng
```

## Commands

### `reveng curate`

Prepares raw screenshots and interview transcripts into structured, analysis-ready outputs.

**What it runs**: The `digital-content-curator` agent via Claude Code, which in turn invokes the `image-to-html` and `curate-transcript` skills.

**Inputs** (from current working directory):
- `screenshots/*.{png,jpg,jpeg,gif,bmp,webp}`
- `transcripts/*.txt`

**Outputs**:
- `output/html/*.html` — semantic HTML mockups of each screenshot
- `output/transcripts/*_curated.txt` — transcripts with off-topic content removed

**Options**:
| Flag | Default | Description |
|------|---------|-------------|
| `-m, --model MODEL` | `sonnet` | Claude model to use |
| `--batch` | off | Process files individually in a loop (one Claude session per file) instead of via the agent. Resumable — skips files that already have output. Recommended for large file sets (50+). |
| `-v, --verbose` | off | Show Claude commands and raw output |
| `--dry-run` | off | Print what would be executed without running |

**Example**:
```bash
reveng curate
reveng curate --batch -m opus
reveng curate --dry-run
```

### `reveng analyse`

Runs the four analysis agents that examine curated content and source code.

**What it runs**: Four agents, each as a separate Claude session:
1. `business-analyst` — reads curated transcripts + HTML mockups → `output/domain-analysis.md`
2. `interaction-analyst` — reads HTML mockups + curated transcripts → `output/interaction-analysis.md`
3. `application-developer` — reads source code under `src/` → `output/application-analysis.md`
4. `database-analyst` — reads source code under `src/` → `output/database-analysis.md`

**Prerequisites**: Curated content must exist (run `reveng curate` first). The command validates this before proceeding.

**Inputs**:
- `output/html/*.html`
- `output/transcripts/*_curated.txt`
- `src/` (legacy source code)

**Outputs**:
- `output/domain-analysis.md`
- `output/interaction-analysis.md`
- `output/application-analysis.md`
- `output/database-analysis.md`

**Options**:
| Flag | Default | Description |
|------|---------|-------------|
| `-m, --model MODEL` | `opus` | Claude model to use |
| `--only ANALYST` | all | Run only a specific analyst: `domain`, `interaction`, `app`, `db` |
| `-v, --verbose` | off | Show Claude commands and raw output |
| `--dry-run` | off | Print what would be executed without running |

**Example**:
```bash
reveng analyse
reveng analyse --only domain
reveng analyse --only app -m sonnet
```

### `reveng synthesise`

Synthesises all analysis outputs into a Product Requirements Document.

**What it runs**: The `product-manager` agent.

**Prerequisites**: All four analysis files must exist in `output/`. The command validates this before proceeding.

**Inputs**:
- `output/domain-analysis.md`
- `output/interaction-analysis.md`
- `output/application-analysis.md`
- `output/database-analysis.md`

**Outputs**:
- `output/PRD.md`

**Options**:
| Flag | Default | Description |
|------|---------|-------------|
| `-m, --model MODEL` | `opus` | Claude model to use |
| `-v, --verbose` | off | Show Claude commands and raw output |
| `--dry-run` | off | Print what would be executed without running |

**Example**:
```bash
reveng synthesise
reveng synthesise -m sonnet --verbose
```

### `reveng decompose`

Decomposes the PRD into individually deliverable feature specifications.

**What it runs**: The `prd-to-features` agent, which spawns parallel `feature-writer` sub-agents.

**Prerequisites**: `output/PRD.md` must exist. The command validates this before proceeding.

**Inputs**:
- `output/PRD.md`

**Outputs**:
- `output/features/FT-XXX-*.md` — individual feature specifications

**Options**:
| Flag | Default | Description |
|------|---------|-------------|
| `-m, --model MODEL` | `opus` | Claude model to use |
| `-v, --verbose` | off | Show Claude commands and raw output |
| `--dry-run` | off | Print what would be executed without running |

**Example**:
```bash
reveng decompose
```

### `reveng init`

Scaffolds the expected directory structure and `.gitignore` entries in the current working directory.

**Creates**:
```
screenshots/
transcripts/
src/
output/
```

**Adds to `.gitignore`**:
```
output/html/
output/transcripts/*_curated.txt
```

**Options**:
| Flag | Default | Description |
|------|---------|-------------|
| (none) | | |

**Example**:
```bash
mkdir my-legacy-app && cd my-legacy-app
git init
reveng init
```

### `reveng version`

Prints the version and exits.

```bash
$ reveng version
reveng 0.1.0
```

### `reveng help`

Prints usage information.

## Global Options

These flags are accepted by all commands that invoke Claude:

| Flag | Default | Description |
|------|---------|-------------|
| `-m, --model MODEL` | varies by command | Claude model to use |
| `-v, --verbose` | off | Show Claude commands and raw output |
| `--dry-run` | off | Print what would be executed without running |
| `-h, --help` | | Show help |

## Invocation Mechanism

Each command shells out to Claude Code in headless mode:

```bash
claude -p "/agent-name" \
  --plugin-dir "$CONFIG_DIR/plugin" \
  --dangerously-skip-permissions \
  --output-format stream-json \
  --model "$model"
```

The `--plugin-dir` flag points to the installed plugin content at `~/.config/reveng/plugin/`, which contains the skills, agents, hooks, and `CLAUDE.md` from the repo.

For the `--batch` mode of `reveng curate`, each file is processed in its own Claude session:

```bash
claude -p "/image-to-html screenshots/foo.png" \
  --plugin-dir "$CONFIG_DIR/plugin" \
  --dangerously-skip-permissions \
  --model "$model" \
  --allowedTools "Read,Write,Bash(mkdir*)"
```

### Safety Warning

When `DEVCONTAINER` is not set to `true`, the CLI prints a warning to stderr (mirroring ralph's behaviour):

```
⚠️  WARNING: Running with --dangerously-skip-permissions outside a container.
⚠️  Claude will have unrestricted access to tools (file writes, shell commands, etc).
⚠️  For safer execution, use a devcontainer or container sandbox.
```

## Script Structure

The CLI is a single bash script following ralph's conventions:

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION="0.1.0"
CONFIG_DIR="${REVENG_CONFIG_DIR:-$HOME/.config/reveng}"
PLUGIN_DIR="$CONFIG_DIR/plugin"

# Default models per command
CURATE_DEFAULT_MODEL="sonnet"
ANALYSE_DEFAULT_MODEL="opus"
SYNTHESISE_DEFAULT_MODEL="opus"
DECOMPOSE_DEFAULT_MODEL="opus"

usage()          { ... }
cmd_version()    { ... }
cmd_init()       { ... }
cmd_curate()     { ... }
cmd_analyse()    { ... }
cmd_synthesise() { ... }
cmd_decompose()  { ... }

# Shared helpers
run_claude()     { ... }  # Builds and executes the claude command
warn_permissions() { ... }  # Prints container safety warning
validate_inputs()  { ... }  # Checks prerequisite files exist

# Main dispatch
case "${1:-}" in
    curate)      shift; cmd_curate "$@" ;;
    analyse)     shift; cmd_analyse "$@" ;;
    synthesise)  shift; cmd_synthesise "$@" ;;
    decompose)   shift; cmd_decompose "$@" ;;
    init)        shift; cmd_init "$@" ;;
    version)     cmd_version ;;
    -h|--help)   usage ;;
    "")          usage ;;
    *)           echo "Error: unknown command '$1'" >&2; exit 1 ;;
esac
```

## Prerequisite Validation

Commands that depend on prior stages validate inputs before invoking Claude:

| Command | Validates |
|---------|-----------|
| `curate` | At least one file in `screenshots/` or `transcripts/` |
| `analyse` | At least one file in `output/html/` or `output/transcripts/*_curated.txt` (for content analysts), at least one file in `src/` (for code analysts) |
| `synthesise` | All four analysis files exist in `output/` |
| `decompose` | `output/PRD.md` exists |

Validation failures print a clear message pointing to the prerequisite command:

```
Error: no curated content found.
Run 'reveng curate' first to prepare screenshots and transcripts.
```

## Output Parsing

Claude's `--output-format stream-json` output is parsed with jq (same filter as ralph's claude backend):

```bash
jq -r 'select(.type == "result") | .result // empty'
```

The final result text is printed to stdout. In `--verbose` mode, the full stream-json output is also printed to stderr.

## Relationship to ralph

| Concern | ralph | reveng |
|---------|-------|--------|
| Phase | Re-engineering | Reverse engineering |
| Installed to | `~/.local/bin/ralph` | `~/.local/bin/reveng` |
| Config at | `~/.config/ralph/` | `~/.config/reveng/` |
| Backend | Pluggable (claude, codex) | Claude only |
| Loop | Iterative plan/build loops | Single-shot agent invocations |
| Sandbox | Built-in devcontainer management | Not included (use ralph's sandbox or your own container) |
| Script style | Single bash script, `cmd_*` functions | Same |
| Flag conventions | `-m`, `-v`, `--dry-run`, `-h` | Same |

## Out of Scope

- **Pipeline orchestration**: No `reveng run` command that chains all stages. Users run commands individually and inspect outputs between stages.
- **Re-engineering commands**: No wrapping of ralph. The two CLIs are independent.
- **Sandbox management**: Use ralph's `ralph sandbox` or your own container setup.
- **Interactive mode**: All commands run headlessly. For interactive use, run `claude --plugin-dir ~/.config/reveng/plugin/` directly.

## Open Questions

1. **Should `reveng analyse` run analysts in parallel (background processes) or sequentially?** Parallel is faster but produces interleaved output. Sequential is simpler to debug. Could default to sequential with a `--parallel` flag.
2. **Should the CLI capture and store Claude session logs?** Useful for debugging but adds complexity. Could write to `.reveng/logs/`.
3. **Should `install.sh` support an `--update` mode** that overwrites existing installed files without prompting, for easy upgrades?
