---
name: image-to-html
description: Converts a UI screenshot of a legacy application into semantic, unstyled mockup HTML. Use this when you need to extract the information structure from a screenshot so downstream agents can reason about the UI without expensive image tokens.
user-invocable: true
allowed-tools: Read, Write, Bash(mkdir*)
argument-hint: [image-path]
---

You are converting a legacy application screenshot into semantic, unstyled mockup HTML.

## Input

The image file path is: `$ARGUMENTS`

## Steps

1. **Read the image** using the Read tool. The path is relative to the project root.

2. **Analyse the UI** shown in the screenshot. Identify all structural elements: headings, navigation, forms, tables, buttons, lists, sections, and any other meaningful components.

3. **Produce semantic HTML** following these rules strictly:
   - Use appropriate semantic elements: `<header>`, `<nav>`, `<main>`, `<section>`, `<form>`, `<table>`, `<fieldset>`, `<legend>`, `<label>`, `<button>`, `<h1>`–`<h6>`, `<ul>`/`<ol>`, `<footer>`, `<aside>`, `<article>`, `<details>`, `<summary>`, etc.
   - Do NOT include any `<style>` tags, inline styles, or CSS classes used for visual purposes.
   - Use `aria-label` or similar attributes only where they convey meaningful information not already present in the text content.
   - Preserve all visible text content exactly as shown in the screenshot, **except** for personally identifiable information (PII) — replace any real names, email addresses, phone numbers, national insurance numbers, addresses, or other identifying details with realistic fake equivalents (e.g. "John Smith" → "Jane Cooper", "john.smith@defra.gov.uk" → "jane.cooper@defra.gov.uk"). Keep the fake data consistent within a single file (i.e. the same real name always maps to the same fake name).
   - Represent form fields with appropriate input types (`text`, `email`, `date`, `checkbox`, `radio`, `select`, etc.).
   - Use `<table>` with `<thead>`, `<tbody>`, `<th>`, and `<td>` for tabular data.
   - Add HTML comments to describe non-text visual elements (icons, charts, images, logos) that carry meaning — e.g. `<!-- Bar chart showing monthly revenue -->`.
   - Wrap the content in a minimal HTML5 document structure (`<!DOCTYPE html>`, `<html lang="en">`, `<head>`, `<body>`).
   - Set the `<title>` to something descriptive derived from the page content.

4. **Derive the output path** by replacing `screenshots/` with `output/html/` in the input path and changing the file extension to `.html`. For example:
   - `screenshots/dashboard.png` → `output/html/dashboard.html`
   - `screenshots/sub/form.jpg` → `output/html/sub/form.html`

5. **Ensure the output directory exists** by running `mkdir -p` on the parent directory of the output path.

6. **Write the HTML mockup** to the derived output path using the Write tool.

7. **Return a single line** confirming the output: `Wrote <output-path>`
