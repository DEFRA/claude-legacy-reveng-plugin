# reveng CLI — Specification

## Overview

`reveng` is a standalone bash CLI that wraps the existing claude-legacy-reveng-plugin, providing a command-driven developer experience for reverse engineering legacy applications within Defra's Legacy Application Programme (LAP).

It is a companion to [ralph](https://github.com/DEFRA/ralph) (the autonomous AI coding agent loop runner used in the re-engineering phase). Ralph handles re-engineering (`ralph plan`, `ralph build`); reveng handles reverse engineering (`reveng curate`, `reveng synthesise`, `reveng decompose`). Both tools provide their own `sandbox` command for running inside a devcontainer. The two tools share conventions but are independently installable.

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
├── container/                # Devcontainer for `reveng sandbox` (new)
│   ├── Dockerfile
│   └── devcontainer.json
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
| `container/Dockerfile`, `container/devcontainer.json` | `~/.config/reveng/container/` |

Override with `REVENG_BIN_DIR` and `REVENG_CONFIG_DIR` environment variables.

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed and authenticated
- Bash 4+
- `jq` (for parsing Claude output in headless mode)
- For `reveng sandbox` only: Docker and the [`devcontainer` CLI](https://github.com/devcontainers/cli) (`npm install -g @devcontainers/cli`)

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
| `-v, --verbose` | off | Show Claude commands and raw output |
| `--dry-run` | off | Print what would be executed without running |

**Example**:
```bash
reveng curate
reveng curate -m opus
reveng curate --dry-run
```

### `reveng synthesise`

Runs the four analysis agents (where their outputs are missing) and synthesises the results into a Product Requirements Document.

**What it runs**: The `product-manager` agent. Internally, product-manager launches any missing analyst agents (`business-analyst`, `interaction-analyst`, `application-developer`, `database-analyst`) via Task before producing the PRD. Existing analysis files are reused; analysts only run for missing outputs.

**Prerequisites**: Curated content must exist (run `reveng curate` first). The command validates this before proceeding.

**Inputs**:
- `output/html/*.html`
- `output/transcripts/*_curated.txt`
- `src/` (legacy source code, optional — drives the code analysts)
- `output/domain-analysis.md`, `output/interaction-analysis.md`, `output/application-analysis.md`, `output/database-analysis.md` (reused if present, generated otherwise)

**Outputs**:
- `output/domain-analysis.md`
- `output/interaction-analysis.md`
- `output/application-analysis.md`
- `output/database-analysis.md`
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

### `reveng sandbox`

Starts (or reuses) a devcontainer for the current working directory and drops the user into a `zsh` shell inside it. The container provides a clean, network-isolated environment where Claude Code can run with `--dangerously-skip-permissions` safely.

**What it runs**: `devcontainer up` followed by `devcontainer exec ... zsh`, using the devcontainer config installed at `~/.config/reveng/container/devcontainer.json`.

**Subcommands**:
- `reveng sandbox` — start or attach to the project's container
- `reveng sandbox --rebuild` — rebuild the container image from scratch (`--remove-existing-container --build-no-cache`)
- `reveng sandbox clean` — remove the project's container (looks up by `devcontainer.local_folder=$PWD` label and runs `docker rm -f`)

**Container contents** (defined in `container/Dockerfile`):
- Node 20 base image
- Claude Code (`@anthropic-ai/claude-code`) preinstalled globally
- Standard dev tools: `git`, `gh`, `jq`, `zsh`, `ripgrep`, `fzf`, `bat`, `neovim`, `curl`
- Non-root `node` user with passwordless sudo
- `DEVCONTAINER=true` env set so the safety warning is suppressed inside

**Mounts** (set up at `devcontainer up` time):
| Mount | Purpose |
|-------|---------|
| `$PWD` → `/workspace` | The project (workspace folder) |
| `$(command -v reveng)` → `/usr/local/bin/reveng` | The CLI itself, so `reveng curate`/`synthesise`/`decompose` work inside |
| `~/.config/reveng` → `/home/node/.config/reveng` | Plugin content, container config |
| `~/.claude` → `/home/node/.claude` | Claude Code credentials and settings |
| `~/.ssh` (if exists) → `/home/node/.ssh` | Git SSH access |
| `~/.config/gh` (if exists) → `/home/node/.config/gh` | GitHub CLI auth |
| `$SSH_AUTH_SOCK` (if set) → `/tmp/ssh-agent.sock` | SSH agent forwarding |
| `ralph-history-<workspace-hash>` volume → `/commandhistory` | Persistent shell history per workspace |

**Env passthrough** (forwarded with `--remote-env` if set on the host):
- `SSH_AUTH_SOCK` (rewritten to the mounted socket path)
- `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY`

Both `SSH_AUTH_SOCK` unset and `SSH_AUTH_SOCK=""` must be treated the same: no mount, no `--remote-env`. Use `[[ -n "${SSH_AUTH_SOCK:-}" ]]` for the guard. When expanding the resulting `--remote-env` array into the `devcontainer up`/`exec` command, use the `${ssh_env[@]+"${ssh_env[@]}"}` pattern rather than `"${ssh_env[@]}"` — this is required for bash 3.2 (macOS system bash) under `set -u`, where expanding an empty array as `"${arr[@]}"` raises "unbound variable". This mirrors the fix applied in ralph.

**Prerequisites**:
- `devcontainer` CLI on `PATH`
- `docker` running
- Current directory is inside a git repository
- `~/.config/reveng/container/devcontainer.json` exists (installed by `install.sh`)

**Options**:
| Flag | Default | Description |
|------|---------|-------------|
| `--rebuild` | off | Rebuild the container image from scratch |

**Example**:
```bash
cd my-legacy-app
reveng sandbox
# inside the container:
node@sandbox:/workspace$ reveng curate
node@sandbox:/workspace$ exit

reveng sandbox --rebuild   # force fresh build
reveng sandbox clean       # remove the project's container
```

### `reveng init`

Scaffolds the expected directory structure and `.gitignore` entries in the current working directory. Does not overwrite directories if they already exist.

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

Each command shells out to Claude Code in headless mode, passing a natural-language prompt that asks Claude to run the relevant agent. We do **not** use slash-command invocation (`/agent-name`) because the user-facing pattern documented in the [Defra AI Modernisation Playbook](https://github.com/DEFRA/defra-ai-modernisation-playbook) is to ask the agent by name in plain English. Mirroring that pattern keeps the CLI's behaviour identical to interactive use, so users get the same result whether they run `reveng curate` or paste the prompt into a `claude` session by hand.

```bash
claude -p "$prompt" \
  --plugin-dir "$CONFIG_DIR/plugin" \
  --dangerously-skip-permissions \
  --output-format stream-json \
  --model "$model"
```

The `--plugin-dir` flag points to the installed plugin content at `~/.config/reveng/plugin/`, which contains the skills, agents, hooks, and `CLAUDE.md` from the repo. With the plugin loaded, Claude can resolve agent names mentioned in the prompt and dispatch to them via the Task tool.

### Prompts per command

Each `cmd_*` function passes a fixed, one-line prompt. These are taken verbatim from the playbook examples where available:

| Command | Prompt |
|---------|--------|
| `curate` | `` Please could you run the `digital-content-curator` agent to prepare all the screenshots and transcripts for analysis? Thank you. `` |
| `synthesise` | `` Please could you run the `product-manager` agent to analyse the application and produce the PRD? Thank you. `` |
| `decompose` | `` Please could you run the `prd-to-features` agent to decompose the PRD into individual feature specifications? Thank you. `` |

The prompts are short and stable, so they live as string literals in the bash script rather than in template files. If a prompt grows or needs templating (e.g. `{{GOAL}}` substitution like ralph), it should be moved to `~/.config/reveng/prompts/<command>.md` and resolved via a `resolve_prompt` helper — but this is not required for the initial implementation.

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
SYNTHESISE_DEFAULT_MODEL="opus"
DECOMPOSE_DEFAULT_MODEL="opus"

usage()          { ... }
cmd_version()    { ... }
cmd_init()       { ... }
cmd_curate()     { ... }
cmd_synthesise() { ... }
cmd_decompose()  { ... }
cmd_sandbox()    { ... }  # devcontainer up + exec zsh; handles --rebuild and `clean` subcommand
sandbox_clean()  { ... }  # docker rm -f the container labelled with this workspace

# Shared helpers
run_claude()     { ... }  # Builds and executes the claude command
warn_permissions() { ... }  # Prints container safety warning
validate_inputs()  { ... }  # Checks prerequisite files exist

# Main dispatch
case "${1:-}" in
    curate)      shift; cmd_curate "$@" ;;
    synthesise)  shift; cmd_synthesise "$@" ;;
    decompose)   shift; cmd_decompose "$@" ;;
    sandbox)     shift; cmd_sandbox "$@" ;;
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
| `synthesise` | At least one file in `output/html/` and at least one file in `output/transcripts/*_curated.txt` (the product-manager agent enforces the same prerequisite internally) |
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
| Sandbox | Built-in devcontainer (`ralph sandbox`) | Built-in devcontainer (`reveng sandbox`) — Claude-only image, no codex |
| Script style | Single bash script, `cmd_*` functions | Same |
| Flag conventions | `-m`, `-v`, `--dry-run`, `-h` | Same |

## Out of Scope

- **Pipeline orchestration**: No `reveng run` command that chains all stages. Users run commands individually and inspect outputs between stages.
- **Re-engineering commands**: No wrapping of ralph. The two CLIs are independent.
- **Interactive mode**: All commands run headlessly. For interactive use, run `claude --plugin-dir ~/.config/reveng/plugin/` directly (or open a `reveng sandbox` shell and invoke `claude` from there).

## Open Questions

1. **Should the CLI capture and store Claude session logs?** Useful for debugging but adds complexity. Could write to `.reveng/logs/`.
    Answer: No, but errors should be surfaced up the the user appropriately if hit.
2. **Should `install.sh` support an `--update` mode** that overwrites existing installed files without prompting, for easy upgrades?
    Answer: Yes
