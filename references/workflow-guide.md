# Workflow Guide — Todo Tracking Skill

This document provides worked examples and decision guidance for the todo-tracking skill.
Read this when you are unsure how to handle a task.

## Quick Reference — File Paths

| File | Path | Purpose |
|------|------|---------|
| Master tracker | `~/.openclaw/todo-tracker/TRACKER.md` | Single source of truth for all todos |
| Project plan | `~/.openclaw/todo-tracker/projects/<id>/plan.md` | Subtask breakdown |
| Project checkpoints | `~/.openclaw/todo-tracker/projects/<id>/checkpoint.md` | Progress log |
| Project data | `~/.openclaw/todo-tracker/projects/<id>/data/` | Collected files |
| Recurring config | `~/.openclaw/todo-tracker/recurring/<id>/config.md` | Task configuration |
| Recurring history | `~/.openclaw/todo-tracker/recurring/<id>/history.md` | Dedup data |
| Daily logs | `~/.openclaw/todo-tracker/recurring/<id>/logs/YYYY-MM-DD.md` | Execution logs |
| Archive | `~/.openclaw/todo-tracker/archive/` | Completed todos |

## Worked Example 1 — Quick Todo: Web Search

**User request**: "Search the web for the latest trends in InsurTech in Germany and send me a summary with sources."

### What the agent does:

```
1. Classify: Can this be done in one session? YES → type = quick.

2. Run: bash <skill-path>/scripts/todo.sh add quick "Web search: InsurTech trends Germany" --priority medium
   Output: "Added: [Q-001] Web search: InsurTech trends Germany"

3. Execute the task:
   - Search the web for "InsurTech trends Germany 2026"
   - Read top 5-10 results
   - Take notes on key trends

4. Run: bash <skill-path>/scripts/todo.sh done Q-001
   Output: "Completed: [Q-001] Web search: InsurTech trends Germany"

5. Compose result:
   "Subject: InsurTech Trends Germany — Summary

    Key trends:
    1. Embedded insurance is growing, especially in e-commerce (Source: ...)
    2. AI-driven claims processing adoption up 35% (Source: ...)
    3. ...

    Sources:
    - [Article 1 title](URL)
    - [Article 2 title](URL)"

6. Send via notification channel (agentmail or other).

DONE. No "I'm working on it" email was sent. Only the result.
```

## Worked Example 2 — Project Todo: Market Analysis

**User request**: "Create a competitive analysis of the German insurance market. Collect annual reports from the major insurers (2018-2024), GDV data, and build a CSV with customer counts, contract volumes, and premium income by line of business."

### What the agent does:

```
1. Classify: Multiple phases? Lots of data? Multiple sessions? YES → type = project.

2. Run: bash <skill-path>/scripts/todo.sh add project "Competitive analysis: German insurance market" --priority high
   Output: "Added: [P-001] Competitive analysis: German insurance market"

3. Break down into subtasks. Write to projects/P-001/plan.md:

   | # | Subtask | Status | Deliverable | Depends on |
   |---|---------|--------|-------------|------------|
   | 1 | Find and download Allianz annual reports 2018-2024 | pending | data/allianz/ | — |
   | 2 | Find and download Munich Re annual reports 2018-2024 | pending | data/munich-re/ | — |
   | 3 | Find and download ERGO annual reports 2018-2024 | pending | data/ergo/ | — |
   | 4 | Find and download HUK-Coburg annual reports 2018-2024 | pending | data/huk-coburg/ | — |
   | 5 | Find and download GDV statistical yearbook data | pending | data/gdv/ | — |
   | 6 | Extract Allianz key metrics to CSV | pending | data/allianz-metrics.csv | 1 |
   | 7 | Extract Munich Re key metrics to CSV | pending | data/munich-re-metrics.csv | 2 |
   | 8 | Extract ERGO key metrics to CSV | pending | data/ergo-metrics.csv | 3 |
   | 9 | Extract HUK-Coburg key metrics to CSV | pending | data/huk-coburg-metrics.csv | 4 |
   | 10 | Merge all data into master CSV and write summary | pending | data/market-overview.csv + summary.md | 5,6,7,8,9 |

4. Send notification: "Project 'Competitive analysis: German insurance market' created
   with 10 subtasks. Starting with: Find and download Allianz annual reports."

5. Start subtask 1:
   - Update subtask 1 status → "in_progress"
   - Search for Allianz annual reports
   - Download/save PDFs to data/allianz/
   - Write checkpoint: "Downloaded Allianz Geschäftsberichte 2018-2024 (7 PDFs, saved to data/allianz/)"
   - Update subtask 1 status → "done"
   - Update TRACKER.md: "Subtasks: 1/10 done"

6. Continue with subtask 2, 3, 4, 5 (collection phase)...
   After each subtask: write checkpoint, update plan.md, update TRACKER.md.

7. If session ends during subtask 3:
   - The agent stops.
   - Next session: reads TRACKER.md → sees P-001 is in_progress.
   - Reads checkpoint.md → last entry was subtask 2.
   - Reads plan.md → subtask 3 is still "pending".
   - Resumes: "Resuming project: 'Competitive analysis'. Last checkpoint: Downloaded ERGO reports. Next: Find HUK-Coburg reports."

8. After subtask 10 (final merge):
   - Read all checkpoints.
   - Write summary.
   - Run: bash <skill-path>/scripts/todo.sh done P-001
   - Send final notification with summary and link to deliverables.
```

## Worked Example 3 — Recurring Todo: Daily News Monitoring

**User request**: "Every day, search for insurance industry news in Germany. Find relevant articles, make sure you don't report the same news twice, and send me a daily summary email."

### What the agent does:

```
1. Classify: Repeats daily? YES → type = recurring.

2. Run: bash <skill-path>/scripts/todo.sh add recurring "Daily insurance news Germany" --schedule daily
   Output: "Added: [R-001] Daily insurance news Germany"

3. Fill in recurring/R-001/config.md:

   Instructions:
   1. Search Google News for "Versicherung Deutschland" (last 24 hours).
   2. Search handelsblatt.com/finanzen/versicherungen/ for new articles.
   3. Check gdv.de/medien/medieninformationen for new press releases.
   4. Check versicherungsbote.de for new articles.
   5. For each finding: record title, URL, source, one-sentence summary.
   6. Compare with history.md using dedup rules.
   7. Write new findings to daily log.

   Sources:
   - Google News: "Versicherung Deutschland"
   - https://www.handelsblatt.com/finanzen/versicherungen/
   - https://www.gdv.de/gdv/medien/medieninformationen
   - https://www.versicherungsbote.de/

   Dedup Rules:
   Method: match-by-title-and-source

   Notification Format:
   Subject: Insurance News Germany — YYYY-MM-DD
   Body: bullet list of new findings with title, source, URL, summary.

4. Send notification: "Recurring task configured. Schedule: daily. First run: today."

5. First execution (and every day after):
   - Read config.md for instructions.
   - Read history.md for previous findings.
   - Check each source:
     - Google News → 5 articles found.
     - Handelsblatt → 2 articles found.
     - GDV → 1 press release found.
     - Versicherungsbote → 3 articles found.
   - Total: 11 findings.
   - Dedup against history: 4 were already reported yesterday → skip.
   - New findings: 7.
   - Append 7 new entries to history.md.
   - Write daily log: recurring/R-001/logs/2026-02-27.md
   - Update TRACKER.md: Last run = 2026-02-27, Next run = 2026-02-28.
   - Send email:
     "Subject: Insurance News Germany — 2026-02-27
      7 new findings today:
      1. Allianz reports record Q4 profits — handelsblatt.com — [URL] — ...
      2. GDV publishes new cyber insurance guidelines — gdv.de — [URL] — ...
      ..."
```

## Decision Tree — What To Do When Stuck

```
PROBLEM: I don't know what type of todo this is.
  → Ask the user: "Should I treat this as a quick task, a larger project,
    or a recurring task?"

PROBLEM: A project has too many subtasks (>10).
  → Group related subtasks into phases.
  → Create 3-5 high-level subtasks, each representing a phase.
  → Within each subtask's checkpoint, track the detailed steps.

PROBLEM: A subtask is blocked.
  → Set subtask status to "blocked" in plan.md.
  → Write a checkpoint describing the blocker.
  → Move to the next non-blocked subtask.
  → Notify the user about the blocker.

PROBLEM: A recurring task finds no results.
  → This is normal. Write a daily log with "No new findings."
  → Send notification: "No new findings for '<title>' today."
  → Do NOT skip the daily log or notification.

PROBLEM: A recurring task's history.md is very large (>500 entries).
  → Remove entries older than 30 days.
  → Keep the 30-day window to prevent re-reporting recent news.

PROBLEM: I resumed a session but the TRACKER.md seems outdated.
  → Read checkpoint.md or the latest daily log to understand actual state.
  → Update TRACKER.md to match reality.
  → Add a checkpoint: "Reconciled TRACKER.md with actual progress."

PROBLEM: The user changed their mind about a task.
  → If they want to cancel: run todo.sh done <id> and note "Cancelled by user" in the result.
  → If they want to change the type: complete the old todo, create a new one of the correct type.
  → If they want to modify the scope: update plan.md or config.md, add a checkpoint.

PROBLEM: Multiple todos are active and I don't know which to work on.
  → Run: bash <skill-path>/scripts/todo.sh next
  → This returns the highest-priority item.
  → If priorities are equal, work on the oldest one first.
```

## Common Mistakes to Avoid

1. **Forgetting to read TRACKER.md at session start.**
   Always read it first. It is the source of truth.

2. **Not writing checkpoints for project subtasks.**
   Every subtask completion MUST have a checkpoint. Without checkpoints,
   the next session cannot resume properly.

3. **Skipping dedup for recurring tasks.**
   Always compare with history.md. Sending duplicate findings wastes the user's time.

4. **Sending "working on it" for quick tasks.**
   Quick tasks should only produce one notification: the result.

5. **Creating too many subtasks.**
   Keep it to 3-10 per project. If you need more, group them into phases.

6. **Not updating TRACKER.md after status changes.**
   After every status change, the tracker must reflect the current state.

7. **Forgetting to update "Next run" for recurring tasks.**
   After each execution, always calculate and write the next run date.

8. **Not cleaning up old history entries.**
   Remove findings older than 30 days from history.md to keep it manageable.
