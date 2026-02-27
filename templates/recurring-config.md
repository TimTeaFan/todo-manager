# Recurring Task: {{TITLE}}

**ID**: {{ID}}
**Schedule**: {{SCHEDULE}}
**Created**: {{DATE}}

## Instructions

<!-- What exactly should the agent do on each run? Be very specific. -->
<!-- Write step-by-step instructions that any agent can follow. -->
<!--
Example:
1. Search Google News for "Versicherung Deutschland" filtered to last 24 hours.
2. Search handelsblatt.de for insurance-related articles.
3. Check gdv.de for new publications.
4. For each finding, record: title, URL, source, one-sentence summary.
5. Compare with history.md to remove duplicates.
6. Write new findings to daily log.
-->

## Sources

<!-- List all sources the agent should check. One per line. -->
<!--
Example:
- Google News: "Versicherung Deutschland"
- https://www.handelsblatt.com/finanzen/versicherungen/
- https://www.gdv.de/gdv/medien/medieninformationen
- https://www.versicherungsbote.de/
-->

## Dedup Rules

**Method**: match-by-title

<!-- How to detect if a finding was already reported: -->
<!-- match-by-title: Skip if the title is very similar to a previous finding. -->
<!-- match-by-url: Skip if the exact URL was already reported. -->
<!-- match-by-title-and-source: Skip if same title from the same source. -->

## Notification Format

<!-- What should the daily summary look like? -->
<!--
Example:
Subject: Daily Insurance News — YYYY-MM-DD
Body:
- N new findings today.
- For each: title, source, URL, one-sentence summary.
- If no new findings: "No new findings today."
-->
