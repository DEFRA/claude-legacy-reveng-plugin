# `reveng` CLI — Implementation Plan

## Context

The `claude-legacy-reveng-plugin` repo is currently a pure Claude Code plugin (skills + agents + hooks, no runnable entrypoint). `reveng-cli.md` at the repo root specifies a new standalone bash CLI that wraps the plugin so mixed-skill teams can drive the full reverse-engineering pipeline (curate → analyse → synthesise → decompose) without knowing Claude Code's internal flags. It mirrors the conventions of Defra's sister tool `ralph` (re-engineering loop runner), and is independently installable.

This plan covers building that CLI end-to-end in this repo, plus aligning the spec with the actual code (the spec's paths lag recent refactors to `output/html/` and `output/transcripts/`).

## Scope — files to create / change

| Path | Action |
|---|---|
| `specs/reveng-cli.md` | **Move** from repo root + **correct** stale paths (see §"Spec corrections") |
| `reveng` (repo root) | **New** — single bash script, ralph-style `cmd_*` functions |
| `install.sh` (repo root) | **New** — copies CLI to `~/.local/bin/`, plugin assets to `~/.config/reveng/plugin/` |
| `README.md` | **Update** — add a "Install the `reveng` CLI" section above "Running the plugin locally"; cross-link `specs/reveng-cli.md` |

Do **not** touch: any file under `skills/`, `agents/`, `hooks/`, `.claude-plugin/`, or `scripts/`. The CLI is a pure wrapper.

## Key design decisions

1. **Agent invocation uses the Task tool via prompt** (user-confirmed). The CLI sends a natural-language prompt that names the agent, e.g.:
   ```bash
   claude -p "Use the digital-content-curator agent to curate screenshots/ and transcripts/." \
     --plugin-dir "$PLUGIN_DIR" --dangerously-skip-permissions \
     --output-format stream-json --model "$MODEL"
   ```
   Claude picks up the agent via its metadata in `agents/*.md` and dispatches through the Task tool. The spec's `claude -p "/agent-name"` literal is incorrect and must be updated.

2. **Skills in `--batch` mode use bare slash commands** (matches the current README's Troubleshooting loop): `claude -p "/image-to-html screenshots/foo.png" --plugin-dir …`. No `defra-legacy-reveng:` namespace prefix needed when loaded via `--plugin-dir`.

3. **Paths align with the current code**, not the stale spec: `output/html/`, `output/transcripts/*_curated.txt`.

4. **Sequential, not parallel** — v0.1 runs the four analysts one after another. `--parallel` deferred.

5. **No log capture, no `install.sh --update`** — both deferred (spec's own Open Questions).

## Implementation order (small, testable slices)

1. **`reveng` scaffold** — shebang, `set -euo pipefail`, `VERSION`, `CONFIG_DIR`/`PLUGIN_DIR`, `usage()`, `cmd_version`, dispatch `case`. Manual test: `./reveng version`, `./reveng help`, `./reveng bogus` (exit 1).
2. **`reveng init`** — no Claude dependency. Creates `screenshots/ transcripts/ src/ output/`; idempotently appends `output/html/` and `output/transcripts/` to `.gitignore` (guard with `grep -Fxq`). Test in `mktemp -d`.
3. **Shared helpers** — `warn_permissions`, `validate_inputs`, `run_claude`, `parse_common_flags` (see §Shared helpers). Exercise via `--dry-run`.
4. **`install.sh`** — copies `reveng` → `${REVENG_BIN_DIR:-$HOME/.local/bin}`, and `skills/ agents/ hooks/ .claude-plugin/ CLAUDE.md` → `${REVENG_CONFIG_DIR:-$HOME/.config/reveng}/plugin/`. Chmod +x. Warn if `$REVENG_BIN_DIR` not on `PATH`. Idempotent (plain `cp -R`).
5. **`cmd_curate` (non-batch)** — prompt-invokes `digital-content-curator` agent. Verify first with `--dry-run`, then one real input pair.
6. **`cmd_curate --batch`** — port the README's Troubleshooting bash loop into the function; honour `--model` and skip-if-exists resume logic; `--dry-run` lists which files would be processed.
7. **`cmd_analyse`** — loops sequentially over the four analyst agents; `--only domain|interaction|app|db` selects one. Validation per §Prereq validation.
8. **`cmd_synthesise`** — single agent invocation of `product-manager`.
9. **`cmd_decompose`** — single agent invocation of `prd-to-features`.
10. **Move + correct `reveng-cli.md`** → `specs/reveng-cli.md` (§Spec corrections).
11. **README update** — install instructions, quick-start, cross-link.

## Shared helpers (rough shapes)

```bash
# Resolve installed plugin dir; fall back to repo-local for in-tree dev
plugin_dir() { … }

# stderr warning when DEVCONTAINER != "true"
warn_permissions() { … }

# $1 label; remaining args are glob patterns — at least one must match.
# On failure prints the exact "Run 'reveng <prev>' first…" message and exits 1.
validate_inputs() { … }

# Builds argv into a bash array; honours $DRY_RUN (prints argv via printf '%q ' and returns 0),
# $VERBOSE (tees raw stream-json to stderr). Always pipes stdout through
# `jq -r 'select(.type=="result") | .result // empty'`.
run_claude() { … }

parse_common_flags() {
  # Mutates MODEL, VERBOSE, DRY_RUN, plus EXTRA (e.g. --only value, --batch flag).
  # Accepts -m/--model, -v/--verbose, --dry-run, -h/--help, --only, --batch.
}
```

Prerequisite binaries: check `command -v claude` and `command -v jq` at script start; fail fast with a clear message if either is missing.

## Prerequisite validation per command

| Command | Check | Failure message |
|---|---|---|
| `curate` | at least one of `screenshots/*.{png,jpg,jpeg,gif,bmp,webp}` or `transcripts/*.txt` (excluding `*_curated.txt`) | "Error: no inputs found. Place files in `screenshots/` or `transcripts/`, or run `reveng init` first." |
| `analyse` (domain/interaction) | at least one `output/html/*.html` or `output/transcripts/*_curated.txt` | "Error: no curated content. Run `reveng curate` first." |
| `analyse` (app/db) | at least one file under `src/` (`find src -type f -print -quit`) | "Error: no source under `src/`. Place legacy source there." |
| `synthesise` | all four of `output/{domain,interaction,application,database}-analysis.md` | "Error: missing analysis files: <list>. Run `reveng analyse` first." |
| `decompose` | `output/PRD.md` | "Error: `output/PRD.md` not found. Run `reveng synthesise` first." |

## Spec corrections (when moving to `specs/reveng-cli.md`)

1. `reveng curate` Outputs: `html/*.html` → `output/html/*.html`; `transcripts/*_curated.txt` → `output/transcripts/*_curated.txt`.
2. `reveng analyse` Inputs: same two path fixes.
3. Prerequisite Validation table: same two path fixes.
4. `reveng init` `.gitignore` block: replace with `output/html/` and `output/transcripts/` (matches README's "Output management" guidance).
5. Invocation Mechanism: replace `claude -p "/agent-name"` with the prompt-the-Task-tool shape shown in §Key design decisions. Clarify that skills (`/image-to-html …`) remain direct slash invocations in `--batch` mode.
6. Repository layout: drop "Existing batch curation script etc." — the batch loop lives in `README.md`, not `scripts/`.

## Reused existing assets (no changes needed)

- `agents/digital-content-curator.md` — `curate` prompts this agent by name.
- `agents/business-analyst.md`, `interaction-analyst.md`, `application-developer.md`, `database-analyst.md` — `analyse`.
- `agents/product-manager.md` — `synthesise`.
- `agents/prd-to-features.md` (which internally spawns `feature-writer.md`) — `decompose`.
- `skills/image-to-html/SKILL.md`, `skills/curate-transcript/SKILL.md` — invoked directly by `curate --batch`.
- README Troubleshooting bash loop — the reference implementation for `curate --batch`.

## Verification

1. **Dry-run every command** — `./reveng <cmd> --dry-run` prints the composed `claude …` argv. Assert plugin-dir, model, prompt are correct. No Claude calls, no cost.
2. **`reveng init`** — run in `mktemp -d`, confirm expected tree and `.gitignore` content; re-run and confirm idempotency.
3. **Install/uninstall** — `REVENG_BIN_DIR=/tmp/b REVENG_CONFIG_DIR=/tmp/c ./install.sh`; run `/tmp/b/reveng version`; then `rm -rf /tmp/{b,c}`.
4. **End-to-end smoke (manual, one small fixture)** — drop one PNG and one short `.txt` into a scratch dir, `reveng curate -m sonnet`, verify `output/html/*.html` and `output/transcripts/*_curated.txt` exist. Skip `synthesise`/`decompose` from automated runs; test manually.
5. **Prereq failures** — run each command with prerequisites missing; confirm exit 1 and the exact documented error text.
6. **`--verbose`** — confirm raw stream-json appears on stderr, final result text on stdout.

## Out of scope (do NOT build)

- `reveng run` pipeline orchestrator.
- Sandbox / devcontainer management — just the stderr warning.
- Interactive mode — always headless.
- Parallel analyst execution (defer; spec's Open Question #1).
- Session log capture to `.reveng/logs/` (defer; Open Question #2).
- `install.sh --update` mode (defer; Open Question #3).
- Any ralph wrapping — the CLIs are independent.
- Changes to skills/agents/hooks — CLI is a pure wrapper.
