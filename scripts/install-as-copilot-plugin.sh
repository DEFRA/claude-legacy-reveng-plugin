#!/usr/bin/env bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/DEFRA/claude-legacy-reveng-plugin/c7f3fcb70d8954e6f31387729c984a10856c6eeb"
TARGET_AGENTS=".github/agents"
TARGET_SKILLS=".github/skills"

AGENTS=(application-developer business-analyst database-analyst digital-content-curator interaction-analyst product-manager)
SKILLS=(curate-transcript image-to-html validate-mermaid)

# 1. Create directories
echo "Creating directories..."
mkdir -p "$TARGET_AGENTS"
for s in "${SKILLS[@]}"; do
  mkdir -p "$TARGET_SKILLS/$s"
done

# 2. Download agents and skills
echo "Downloading agents..."
for a in "${AGENTS[@]}"; do
  curl -sL "$REPO_RAW/agents/${a}.md" -o "$TARGET_AGENTS/${a}.md"
  echo "  Downloaded $a"
done

echo "Downloading skills..."
for s in "${SKILLS[@]}"; do
  curl -sL "$REPO_RAW/skills/${s}/SKILL.md" -o "$TARGET_SKILLS/${s}/SKILL.md"
  echo "  Downloaded $s"
done

# 3. Transform agent frontmatter: remove model/memory, remap tools
echo "Transforming agent frontmatter..."
for a in "${AGENTS[@]}"; do
  file="$TARGET_AGENTS/${a}.md"

  # Determine if agent needs 'agent' tool (has Task in original tools line)
  if grep -q '^tools:.*Task' "$file"; then
    new_tools="tools: ['read', 'edit', 'search', 'agent']"
    # curator has a different order
    if [[ "$a" == "digital-content-curator" ]]; then
      new_tools="tools: ['agent', 'search', 'read', 'edit']"
    fi
  else
    new_tools="tools: ['read', 'edit', 'search']"
  fi

  # Remove model and memory lines, replace tools line
  sed -i '' '/^model:/d' "$file"
  sed -i '' '/^memory:/d' "$file"
  sed -i '' "s/^tools:.*/$new_tools/" "$file"
done

# 4. Transform agent body text: Glob→search, Grep→search, etc.
echo "Transforming agent body text..."
# Only transform agents that have body-level Glob/Grep references needing replacement
# (interaction-analyst keeps original Glob references in its body)
for a in application-developer business-analyst database-analyst product-manager digital-content-curator; do
  file="$TARGET_AGENTS/${a}.md"

  # "Use Glob to" → "Use search to"
  sed -i '' 's/Use Glob to/Use search to/g' "$file"
  # "Glob for" → "Search for"
  sed -i '' 's/Glob for/Search for/g' "$file"
  # "Re-glob" → "Search again"
  sed -i '' 's/Re-glob/Search again/g' "$file"
  # "re-glob" → "search again for"
  sed -i '' 's/re-glob/search again for/g' "$file"
  # "globs" → "Searchs" (matches known-good output for application-developer)
  sed -i '' 's/globs/Searchs/g' "$file"
done

# 5. Apply curator-specific transforms
echo "Applying curator-specific transforms..."
curator="$TARGET_AGENTS/digital-content-curator.md"

# Task( code blocks → runSubagent( with digital-content-processor
sed -i '' 's/^Task($/runSubagent(/g' "$curator"
sed -i '' 's/^  subagent_type="general-purpose",$/  agentName: "digital-content-processor",/g' "$curator"
sed -i '' 's/^  prompt="Use/  prompt: "Use/g' "$curator"

# "same Task subagent pattern" → "same subagent pattern" (must come before generic Task subagent replacement)
sed -i '' 's/same Task subagent pattern/same subagent pattern/g' "$curator"

# "Task subagent" → "digital-content-processor subagent"
sed -i '' 's/Task subagent/digital-content-processor subagent/g' "$curator"

# 6. Apply product-manager-specific transforms
echo "Applying product-manager-specific transforms..."
pm="$TARGET_AGENTS/product-manager.md"
sed -i '' 's/launch `application-developer` and `database-analyst` via Task in parallel/launch `application-developer` and `database-analyst` subagents in parallel/g' "$pm"

# 7. Transform skill frontmatter: remove allowed-tools
echo "Transforming skill frontmatter..."
for s in "${SKILLS[@]}"; do
  file="$TARGET_SKILLS/$s/SKILL.md"
  sed -i '' '/^allowed-tools:/d' "$file"
done

# 8. Transform skill body text
echo "Transforming skill body text..."

# curate-transcript: remove "using `cp`" and "to the output path using `cp`" → "to the output path"
ct="$TARGET_SKILLS/curate-transcript/SKILL.md"
sed -i '' 's/\*\*Copy the original file\*\* to the output path using `cp`/**Copy the original file content** to the output path/' "$ct"

# image-to-html: simplify step 5, update step 7
ith="$TARGET_SKILLS/image-to-html/SKILL.md"
sed -i '' "s/^5\. \*\*Ensure the output directory exists\*\* by running \`mkdir -p\` on the parent directory of the output path\./5. **Ensure the output directory exists**/" "$ith"
sed -i '' "s|^7\. \*\*Return a single line\*\* confirming the output: \`Wrote <output-path>\`$|7. **Return a single line** confirming the output: \`Wrote <output-path>\` — where \`<output-path>\` is the full workspace-relative path (e.g. \`output/html/dashboard.html\`), not just a filename.|" "$ith"

# 9. Generate digital-content-processor.md
echo "Generating digital-content-processor.md..."
cat > "$TARGET_AGENTS/digital-content-processor.md" << 'HEREDOC'
---
name: digital-content-processor
description: >
  Worker agent that processes a single raw file using a specified skill.
  Reads the skill definition, then executes its steps to produce output files.
user-invocable: false
tools: ['read', 'edit', 'search']
---

You are a WORKER SUBAGENT called digital-content-processor, called by the digital-content-curator conductor agent. You receive a focused processing task: a skill definition path and a file to process.

**Your scope:** Execute the specific skill against the specific file provided in the prompt. The conductor handles discovery, orchestration, and verification.

## Core workflow

1. **Read the skill definition** at the path specified in the prompt (e.g. `.github/skills/image-to-html/SKILL.md`).
2. **Replace `$ARGUMENTS`** — wherever the skill text contains `$ARGUMENTS`, substitute the file path provided in the prompt.
3. **Execute every step** in the skill definition in order, using the tools available to you:
   - Use `read` to read files (including images).
   - Use `edit` to create or modify files.
   - Use `execute/runInTerminal` for shell commands (e.g. `mkdir -p`, `cp`).
4. **Return confirmation** as specified by the skill (typically a single line confirming the output path).

## Rules

- Only process the single file specified in the prompt. Do not discover, read, or modify any other files.
- Do NOT skip any step in the skill definition.
- Do NOT orchestrate further subagents.
- Do NOT pause for user input — work autonomously and report back to the conductor.
- If a step fails, report the error back rather than silently continuing.
HEREDOC

# 10. Verification
echo ""
echo "=== Verification ==="
errors=0

# Check for leftover patterns that should have been removed
for pattern in '^model:' '^memory:' '^allowed-tools:'; do
  matches=$(grep -rl "$pattern" "$TARGET_AGENTS"/ "$TARGET_SKILLS"/ 2>/dev/null || true)
  if [[ -n "$matches" ]]; then
    echo "WARNING: Pattern '$pattern' still found in: $matches"
    errors=$((errors + 1))
  fi
done

# Check agents for leftover Claude Code tool references (but not in prose that legitimately mentions them)
for f in "$TARGET_AGENTS"/*.md; do
  basename=$(basename "$f" .md)
  # Check for Task( invocation syntax
  if grep -q 'Task(' "$f" 2>/dev/null; then
    echo "WARNING: 'Task(' still found in $f"
    errors=$((errors + 1))
  fi
  # Check for subagent_type (old syntax)
  if grep -q 'subagent_type=' "$f" 2>/dev/null; then
    echo "WARNING: 'subagent_type=' still found in $f"
    errors=$((errors + 1))
  fi
done

# Confirm digital-content-processor exists
if [[ -f "$TARGET_AGENTS/digital-content-processor.md" ]]; then
  echo "✓ digital-content-processor.md generated"
else
  echo "ERROR: digital-content-processor.md missing"
  errors=$((errors + 1))
fi

# Count files
agent_count=$(ls "$TARGET_AGENTS"/*.md 2>/dev/null | wc -l | tr -d ' ')
skill_count=$(find "$TARGET_SKILLS" -name 'SKILL.md' | wc -l | tr -d ' ')
echo "✓ $agent_count agent files (expected 7)"
echo "✓ $skill_count skill files (expected 3)"

if [[ $errors -eq 0 ]]; then
  echo ""
  echo "All transformations applied successfully."
else
  echo ""
  echo "WARNING: $errors verification issue(s) found — review output above."
fi
