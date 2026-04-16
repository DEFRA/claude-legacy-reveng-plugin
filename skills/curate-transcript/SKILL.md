---
name: curate-transcript
description: Curates a stakeholder interview transcript by removing off-topic content (incumbent team agenda, feature requests, distractions) while preserving application walkthrough and domain knowledge verbatim.
user-invocable: true
allowed-tools: Read, Edit, Bash(mkdir*;cp*)
argument-hint: [transcript-path]
---

You are curating a Defra LAP stakeholder interview transcript. Your job is to remove off-topic passages. All kept text is preserved mechanically — you never write or rewrite any transcript content.

## Input

The transcript file path is: `$ARGUMENTS`

## Steps

1. **Derive the output path** by taking the filename, replacing the `.txt` extension with `_curated.txt`, and placing it under `output/transcripts/`. For example:
   - `transcripts/interview-1.txt` → `output/transcripts/interview-1_curated.txt`
   - `transcripts/deep-dive.txt` → `output/transcripts/deep-dive_curated.txt`

2. **Ensure the output directory exists** by running `mkdir -p output/transcripts`.

3. **Copy the original file** to the output path using `cp`. This creates an exact mechanical copy that preserves all text verbatim.

4. **Read the output file** using the Read tool.

5. **Identify passages to remove.** Classify content into two categories:

   **Keep** — content directly about the application or its domain:
   - Application walkthrough content: screen descriptions, user flows, functionality explanations, how the system behaves
   - Domain knowledge: business rules, terminology, processes, regulations that the application implements
   - Technical details about the application: architecture, data flows, infrastructure it runs on
   - Integrations and dependencies: third-party systems, external services, APIs, data exchanges, upstream/downstream applications the system connects to

   **Remove** — everything else, including but not limited to:
   - The incumbent modernisation team's agenda, plans, opinions, or approach discussions
   - Stakeholder feature requests or wishlists for new functionality
   - Project management discussions: team structure, suppliers, contracts, timelines, staffing, resourcing, delivery plans
   - Meeting logistics and scheduling: arranging follow-ups, calendar availability, session housekeeping
   - Personal context about individuals: career history, background, role introductions beyond job title
   - Technical tangents unrelated to the application itself: DPIA processes, data protection policy, procurement procedures, programme governance
   - Social pleasantries, small talk, greetings, sign-offs, thanks, and chitchat
   - Meta-discussion about the interview process itself
   - Tangential conversation not related to the current application or its domain

   **When in doubt, remove** — but never remove content that describes how the application behaves, what it connects to, or what domain rules it implements. These transcripts are typically recordings of sessions where third-party vendors explored legacy applications as part of a migration engagement. We are not interested in the vendors' migration plans, modernisation approach, or opinions — only the as-is state of the application they were examining. The test is: does this passage describe what the application does today, or what someone planned to do with it? Keep the former, remove the latter.

6. **Remove each identified passage** using the Edit tool on the output file. For each passage:
   - Set `old_string` to the **exact text** of the passage to remove (copy it precisely, including whitespace, timestamps and line breaks)
   - Set `new_string` to an empty string `""`
   - If removing a passage leaves adjacent blank lines, make a follow-up Edit to collapse them to a single blank line

7. **Return a confirmation message** containing:
   - The output file path
   - A brief summary of what categories of content were removed, with approximate counts (e.g. "Removed: 3 passages discussing the incumbent team's migration timeline, 2 feature requests for a new reporting dashboard")
   - If nothing was removed, state that the transcript contained no off-topic material
