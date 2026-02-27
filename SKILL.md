---
name: todo-tracking
description: >
  Track and manage todos of three types:
  quick (single-session tasks), project (multi-session with subtask breakdown),
  and recurring (scheduled periodic tasks with deduplication).
  Use when the user assigns a task, asks about pending work,
  or the heartbeat triggers a scheduled check.
emoji: 📋
user-invocable: true
requires:
  bins:
    - bash
---

# Todo Tracking Skill

You are a task-tracking assistant. You manage three types of todos: **quick**, **project**, and **recurring**. Follow these instructions exactly. Do not skip steps. Do not improvise.

## 1. Initialization

Before doing anything else, run these steps:

1. Check if the directory `~/.openclaw/todo-tracker/` exists.
2. If it does NOT exist, run: `bash <skill-path>/scripts/todo.sh init`
3. Read the file `~/.openclaw/todo-tracker/TRACKER.md` to load the current state.
4. If the file is empty or missing, copy `<skill-path>/templates/TRACKER.md` to `~/.openclaw/todo-tracker/TRACKER.md`.

From now on, `DATA_DIR` refers to `~/.openclaw/todo-tracker/`.

## 2. Decision Tree — Classify the Todo Type

When the user gives you a new task, follow this decision tree to determine the type:

```
STEP 1: Is this a task that repeats on a schedule (daily, weekly, etc.)?
  → YES: type = recurring. Go to Section 5.
  → NO: Go to STEP 2.

STEP 2: Can this task be completed right now, in this session, in a few steps?
  → YES: type = quick. Go to Section 3.
  → NO: Go to STEP 3.

STEP 3: Does this task require multiple phases, collecting lots of data,
         or will it take more than one session to complete?
  → YES: type = project. Go to Section 4.
  → NO: Ask the user: "Should I treat this as a quick task or a larger project?"
```

## 3. Quick Todo Workflow

A quick todo is a task you can finish in this session. Examples: web search, writing a short summary, answering a question with research.

### Steps:

```
STEP 1: Add the todo.
  Run: bash <skill-path>/scripts/todo.sh add quick "<title>" --priority <high|medium|low>
  This creates an entry in TRACKER.md with status "open".

STEP 2: Execute the task.
  Do the work now. Use whatever tools are needed.

STEP 3: Mark as done.
  Run: bash <skill-path>/scripts/todo.sh done <id>
  This moves the entry to the "Completed" section with a timestamp.

STEP 4: Send the result.
  Compose the result (summary, answer, deliverable).
  Follow Section 8 (Notification) to deliver it to the user.

IMPORTANT: Do NOT send a "working on it" message for quick todos.
           Just do the work and send the result.
```

## 4. Project Todo Workflow

A project todo is a large task requiring multiple steps across multiple sessions. Examples: market research, building a dataset, comprehensive analysis.

### Phase 1 — Planning

```
STEP 1: Add the todo.
  Run: bash <skill-path>/scripts/todo.sh add project "<title>" --priority <high|medium|low>
  This creates an entry in TRACKER.md with status "planning".

STEP 2: Create the project directory.
  The script already created: DATA_DIR/projects/<project-id>/
  It contains: plan.md, checkpoint.md, and data/ folder.

STEP 3: Break the goal into subtasks.
  Open DATA_DIR/projects/<project-id>/plan.md.
  Write 3 to 10 subtasks. Each subtask MUST have:
    - A number (1, 2, 3, ...)
    - A clear, specific title
    - A deliverable (what file or output it produces)
    - A status: "pending"
    - Dependencies (which subtask must be done first, if any)

  Rules for good subtasks:
    - Each subtask must be completable in ONE session.
    - Each subtask must produce something concrete (a file, a dataset, a summary).
    - Order them by dependency: what must come first?
    - If you are unsure how to break it down, ask the user for guidance.

STEP 4: Update TRACKER.md.
  Run: bash <skill-path>/scripts/todo.sh update <id> --status planning

STEP 5: Send notification.
  Tell the user: "Project '<title>' created with N subtasks. Starting with: <first subtask title>."
  Follow Section 8 (Notification).

STEP 6: Begin Phase 2 immediately with the first subtask.
```

### Phase 2 — Execution (repeat for each subtask)

```
STEP 1: Find the next subtask.
  Read DATA_DIR/projects/<project-id>/plan.md.
  Find the first subtask with status "pending".
  If no pending subtasks remain, go to Phase 3.

STEP 2: Start working.
  Update the subtask status to "in_progress" in plan.md.
  Update TRACKER.md:
    Run: bash <skill-path>/scripts/todo.sh update <id> --status in_progress

STEP 3: Execute the subtask.
  Do the work. Save any output files to DATA_DIR/projects/<project-id>/data/.

STEP 4: Write a checkpoint.
  Run: bash <skill-path>/scripts/todo.sh checkpoint <id> "<what you did>"
  This appends to checkpoint.md with:
    - Date and time
    - What was accomplished
    - What files were created or modified
    - Any blockers or open questions

STEP 5: Mark subtask as done.
  Update the subtask status to "done" in plan.md.

STEP 6: Check progress.
  Count: how many subtasks are "done" vs total?
  Update TRACKER.md subtask counter (e.g., "3/8 done").

STEP 7: Continue or pause.
  - If there are more pending subtasks AND you have capacity → go to STEP 1.
  - If the session is ending → stop here. The next session will resume from STEP 1.
```

### Phase 3 — Completion

```
STEP 1: Create a final summary.
  Read all entries in checkpoint.md.
  Write a summary that covers:
    - What was the goal
    - What was accomplished (list of deliverables)
    - Key findings or results
    - Location of output files

STEP 2: Mark as done.
  Run: bash <skill-path>/scripts/todo.sh done <id>

STEP 3: Send notification.
  Send the final summary to the user.
  Follow Section 8 (Notification).
```

## 5. Recurring Todo Workflow

A recurring todo is a task that runs on a schedule. Examples: daily news monitoring, weekly report generation, periodic data checks.

### Setup (first time only)

```
STEP 1: Add the todo.
  Run: bash <skill-path>/scripts/todo.sh add recurring "<title>" --schedule <schedule>
  Valid schedules: "daily", "weekly", "weekdays", "monthly", or cron-like "every N hours".
  This creates an entry in TRACKER.md with status "active".

STEP 2: Create the configuration.
  The script already created: DATA_DIR/recurring/<task-id>/
  Open DATA_DIR/recurring/<task-id>/config.md and fill in:
    - Schedule: when to run (copied from step 1)
    - Instructions: what exactly to do each time (be very specific)
    - Sources: where to look (URLs, search terms, etc.)
    - Dedup rules: how to detect if a finding was already reported
      Options: "match-by-title", "match-by-url", "match-by-title-and-source"
    - Notification format: what the summary should look like

STEP 3: Create empty history file.
  The script already created an empty history.md.

STEP 4: Send notification.
  Tell the user: "Recurring task '<title>' configured. Schedule: <schedule>. First run: <when>."
  Follow Section 8 (Notification).
```

### Execution (each scheduled run)

```
STEP 1: Read configuration.
  Open DATA_DIR/recurring/<task-id>/config.md.
  Read the instructions, sources, and dedup rules.

STEP 2: Load previous findings.
  Read DATA_DIR/recurring/<task-id>/history.md.
  This contains findings from previous runs (title + URL + date found).

STEP 3: Execute the task.
  Follow the instructions from config.md exactly.
  For each finding, record: title, URL/source, short summary.

STEP 4: Deduplicate.
  For each finding from STEP 3:
    - Check if it exists in history.md (using the dedup rule from config.md).
    - If YES: mark as "already known" — do NOT include in today's report.
    - If NO: mark as "new" — include in today's report.

STEP 5: Update history.
  Append all NEW findings to history.md with today's date.
  If history.md has entries older than 30 days, remove them.
  Format per entry:
    - **Title**: <title>
    - **URL**: <url>
    - **Found**: <date>

STEP 6: Write daily log.
  Create file: DATA_DIR/recurring/<task-id>/logs/YYYY-MM-DD.md
  Use the template from <skill-path>/templates/daily-log.md.
  Fill in: timestamp, sources checked, new findings, skipped items, summary.

STEP 7: Update TRACKER.md.
  Update "Last run" to today's date.
  Update "Next run" based on schedule.

STEP 8: Send notification.
  Compose a summary with ONLY the new findings.
  Include: title, source URL, and one-sentence summary for each.
  Follow Section 8 (Notification).
  If there are NO new findings, send: "No new findings for '<title>' today."
```

## 6. Heartbeat Integration

When triggered by a heartbeat (periodic agent wake-up), follow these steps:

```
STEP 1: Read TRACKER.md.

STEP 2: Check for overdue quick todos.
  Find all quick todos with status "open" created more than 24 hours ago.
  For each: flag as "OVERDUE".

STEP 3: Check for stalled projects.
  Find all project todos with status "in_progress".
  Read their checkpoint.md. If the last checkpoint is older than 48 hours:
  flag as "STALLED".

STEP 4: Check for due recurring tasks.
  Find all recurring todos with status "active".
  Compare "Next run" date with today.
  If "Next run" is today or in the past: flag as "DUE".

STEP 5: Take action.
  - For each OVERDUE quick todo: add a note to TRACKER.md — "OVERDUE since <date>".
  - For each STALLED project: add a note — "STALLED: no progress since <date>".
  - For each DUE recurring task: execute it now (follow Section 5, Execution).

STEP 6: Send summary (if any flags found).
  Compose a heartbeat summary:
    "Heartbeat Check — <date>
     Overdue: <count> quick todo(s)
     Stalled: <count> project(s)
     Due: <count> recurring task(s)
     Actions taken: <list>"
  Follow Section 8 (Notification).
  If nothing is flagged, do NOT send a notification.
```

## 7. Session Resume

At the start of every new session, follow these steps:

```
STEP 1: Read TRACKER.md.

STEP 2: Look for in-progress items.
  Find any todo with status "in_progress".

STEP 3: If found, resume work.
  For each in-progress item:
    a. If type = project:
       Read DATA_DIR/projects/<project-id>/checkpoint.md.
       Find the last checkpoint entry.
       Display: "Resuming project: '<title>'. Last checkpoint: <summary>. Next subtask: <next>."
       Continue with Section 4, Phase 2, STEP 1.

    b. If type = quick:
       Display: "Found unfinished quick todo: '<title>'. Completing now."
       Continue with Section 3, STEP 2.

STEP 4: If no in-progress items, check for pending work.
  Run: bash <skill-path>/scripts/todo.sh next
  If there is a next item, display: "Next todo: '<title>' (<type>, <priority>)."
  Ask the user: "Should I work on this now?"
```

## 8. Notification Abstraction

When any section says "send notification" or "follow Section 8", do this:

```
STEP 1: Compose the message.
  Write the full message content first. Do not send yet.

STEP 2: Choose the channel.
  Check which communication tools are available:
    a. If the agentmail skill is available → use it to send an email.
    b. If a slack skill is available → post to the configured channel.
    c. If a telegram skill is available → send a message.
    d. If no communication skill is available → write the message to
       DATA_DIR/notifications.md with a timestamp.
       Display the message in the chat.

STEP 3: Log the notification.
  Append to the todo's checkpoint or log file:
    "[NOTIFICATION SENT] <date> via <channel>: <first 100 chars of message>"
```

## 9. TRACKER.md Format

The master tracker file uses this exact format. Do not deviate.

```markdown
# Todo Tracker

## Counters
- quick: <next-number>
- project: <next-number>
- recurring: <next-number>

## Active Todos

### [<ID>] <Title>
- **Type**: quick | project | recurring
- **Status**: open | planning | in_progress | active | done
- **Created**: YYYY-MM-DD
- **Priority**: high | medium | low
<!-- project-only fields: -->
- **Subtasks**: <done>/<total> done
- **Last checkpoint**: YYYY-MM-DD — <summary>
- **Next step**: <what comes next>
<!-- recurring-only fields: -->
- **Schedule**: daily | weekly | weekdays | monthly | every N hours
- **Last run**: YYYY-MM-DD
- **Next run**: YYYY-MM-DD

## Completed Todos

### [<ID>] <Title>
- **Completed**: YYYY-MM-DD
- **Result**: <one-line summary or link to deliverable>
```

### ID Format
- Quick todos: `Q-001`, `Q-002`, `Q-003`, ...
- Project todos: `P-001`, `P-002`, `P-003`, ...
- Recurring todos: `R-001`, `R-002`, `R-003`, ...

The counter section in TRACKER.md tracks the next available number for each type.

## 10. Error Handling

If something goes wrong, follow these rules:

```
PROBLEM: TRACKER.md is missing or corrupted.
  → Run: bash <skill-path>/scripts/todo.sh init
  → Copy template to DATA_DIR/TRACKER.md.
  → Notify user: "Todo tracker was reset. Previous data may be lost."

PROBLEM: A project's plan.md or checkpoint.md is missing.
  → Recreate from template.
  → Add checkpoint: "Files were missing. Recreated from template. Previous progress may be lost."
  → Notify user.

PROBLEM: A recurring task's config.md is missing.
  → Set status to "paused" in TRACKER.md.
  → Notify user: "Recurring task '<title>' paused — configuration file is missing."

PROBLEM: You are unsure how to classify a task.
  → Ask the user. Do not guess.

PROBLEM: A subtask is blocked and you cannot proceed.
  → Write a checkpoint with the blocker description.
  → Set subtask status to "blocked" in plan.md.
  → Move to the next non-blocked subtask.
  → Notify user about the blocker.
```

## 11. Important Reminders

Read these before every action:

1. **Always read TRACKER.md first** before creating, updating, or completing a todo.
2. **Always write a checkpoint** after completing a project subtask.
3. **Never skip the dedup step** for recurring tasks.
4. **Never send "working on it" notifications** for quick todos.
5. **Always update TRACKER.md** after any status change.
6. **Use the exact ID format** (Q-NNN, P-NNN, R-NNN). Do not invent new formats.
7. **One subtask at a time** for projects. Complete one before starting the next.
8. **Keep history.md clean** for recurring tasks. Remove entries older than 30 days.
9. **If you are unsure, ask the user.** Do not assume.
