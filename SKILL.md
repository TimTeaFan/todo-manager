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

### Key Definitions

```
DEFINITION: "session"
  A session is one continuous agent execution window.
  It starts when the agent is invoked and ends when the agent stops or times out.
  A new session starts the next time the agent is invoked.
  Rule of thumb: if you can complete a task without the agent stopping, it fits in one session.

DEFINITION: "<skill-path>"
  This is the directory where this skill package is installed.
  The OpenClaw framework provides it as the working directory or environment variable.
  To verify: check that the file <skill-path>/scripts/todo.sh exists.
  If you cannot determine the skill path, ask the user.

DEFINITION: "DATA_DIR"
  This is ~/.openclaw/todo-tracker/ — the runtime data directory.
  All todo data lives here. This directory persists across sessions.

DEFINITION: "script output"
  Every todo.sh command prints its result to stdout.
  When a command creates a todo, the LAST line of output is the ID.
  Example output of "todo.sh add":
    "Added: [Q-001] My task title (type=quick, priority=medium)"
    "Q-001"
  The ID is on the last line. Extract it and use it for all subsequent commands.
  NEVER invent an ID. Always use the ID returned by the script.
  If the script prints an error (starts with "ERROR:"), STOP and investigate.
```

### Setup Steps

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
  Use these criteria:
    - The task needs only 1-3 tool calls (e.g., one web search + one summary).
    - The output is a single deliverable (e.g., one summary, one answer).
    - No data needs to be collected across multiple sources over time.
    - No subtasks or phases are needed.
  → ALL criteria met: type = quick. Go to Section 3.
  → ANY criterion NOT met: Go to STEP 3.

STEP 3: Does this task require multiple phases, collecting lots of data,
         or will it take more than one session to complete?
  Use these criteria:
    - The task has 3+ distinct steps that each produce a separate output.
    - Multiple data sources need to be consulted or downloaded.
    - The output requires both collection AND processing/analysis phases.
    - The user explicitly mentions "research", "analysis", "collect", or similar.
  → ANY criterion met: type = project. Go to Section 4.
  → NONE met: Ask the user: "Should I treat this as a quick task or a larger project?"

EXAMPLES to help you classify:
  "Search for the latest InsurTech trends" → quick (one search + summary)
  "Find and compare annual reports from 5 insurers" → project (multiple sources + comparison)
  "Summarize this PDF" → quick (one input + one output)
  "Build a dataset of German insurance market data 2018-2024" → project (collection + processing)
  "Check insurance news every morning" → recurring (daily schedule)
```

## 3. Quick Todo Workflow

A quick todo is a task you can finish in this session. Examples: web search, writing a short summary, answering a question with research.

### Steps:

```
STEP 1: Add the todo.
  Run: bash <skill-path>/scripts/todo.sh add quick "<title>" --priority <high|medium|low>
  Expected output (example):
    "Added: [Q-001] Search InsurTech trends (type=quick, priority=medium)"
    "Q-001"
  Extract the ID from the LAST line of output (e.g., "Q-001").
  Save this ID — you need it for STEP 3.

STEP 2: Execute the task.
  Do the work now. Use whatever tools are needed.

STEP 3: Mark as done.
  Run: bash <skill-path>/scripts/todo.sh done <id>
  Use the ID you saved from STEP 1 (e.g., "Q-001").
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
  Expected output (example):
    "Created project directory: /home/user/.openclaw/todo-tracker/projects/P-001"
    "Added: [P-001] Market analysis Germany (type=project, priority=high)"
    "P-001"
  Extract the ID from the LAST line (e.g., "P-001").
  Save this ID — you need it for ALL subsequent steps.

STEP 2: Verify the project directory.
  The script already created: DATA_DIR/projects/<project-id>/
  It contains: plan.md (from template), checkpoint.md (empty log), and data/ folder.
  Verify: ls DATA_DIR/projects/<project-id>/ — you should see plan.md, checkpoint.md, data/.

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
  Run: bash <skill-path>/scripts/todo.sh checkpoint <id> "<message>"

  Checkpoint message format (single line, no newlines):
    "<WHAT YOU DID>. Files: <list of files>. Blockers: <any or none>"

  Examples:
    "Downloaded 7 Allianz annual reports 2018-2024. Files: data/allianz/*.pdf. Blockers: none"
    "Extracted Allianz key metrics. Files: data/allianz-metrics.csv. Blockers: 2018 report has unclear data format"

  Rules:
    - Keep under 200 characters.
    - Always mention created/modified files.
    - Always state blockers ("Blockers: none" if no issues).

STEP 5: Mark subtask as done.
  Update the subtask status to "done" in plan.md.

STEP 6: Update progress counter in TRACKER.md.
  Count subtasks by status:
    done_count = number of subtasks with status "done"
    total_count = ALL subtasks EXCEPT those with status "cancelled"
  Update the "Subtasks" field: "Subtasks: <done_count>/<total_count> done"
  Update the "Next step" field: write the title of the next "pending" subtask.
  Example: "Subtasks: 3/8 done", "Next step: Extract Munich Re key metrics to CSV"

STEP 7: Continue or pause.
  Ask yourself: are there more subtasks with status "pending"?
    YES → Go back to STEP 1 (start the next subtask).
    NO  → All subtasks are done. Go to Phase 3.

  EXCEPTION — Session ending:
    If the agent framework signals that the session is about to end,
    STOP after the current subtask. Do NOT start a new subtask.
    The next session will resume via Section 7 (Session Resume).
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
  Valid schedules: "daily", "weekly", "weekdays", "monthly".
  Expected output (example):
    "Created recurring directory: /home/user/.openclaw/todo-tracker/recurring/R-001"
    "Added: [R-001] Daily news check (type=recurring, priority=medium)"
    "R-001"
  Extract the ID from the LAST line (e.g., "R-001").

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
  Read the dedup method from config.md. Then check EACH finding against history.md:

  Method "match-by-title":
    Compare the finding's title with every title in history.md.
    Comparison is CASE-INSENSITIVE and ignores leading/trailing whitespace.
    Exact word match required — "Allianz Q4 Report" does NOT match "Allianz Q3 Report".
    If a match is found → "already known".

  Method "match-by-url":
    Compare the finding's URL with every URL in history.md.
    Comparison is EXACT (case-sensitive, including query parameters).
    If the finding has no URL → treat as "new" (cannot deduplicate).
    If a match is found → "already known".

  Method "match-by-title-and-source":
    Compare BOTH the title AND the source domain.
    BOTH must match for it to be a duplicate.
    Example: Title "Insurance News" from gdv.de is NOT the same as
             Title "Insurance News" from handelsblatt.de.

  For each finding:
    - If "already known" → do NOT include in today's report. Log it as skipped.
    - If "new" → include in today's report.

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
  Calculate "Next run" using this formula:

    Schedule "daily"    → next run = tomorrow (today + 1 day)
    Schedule "weekdays" → next run = next Mon-Fri
                          (if today is Fri → next Mon; if today is Mon-Thu → tomorrow)
    Schedule "weekly"   → next run = today + 7 days
    Schedule "monthly"  → next run = same day next month (e.g., Feb 27 → Mar 27)

  If calculated date is in the past (because the task ran late):
    → set next run = tomorrow.

  Write the date in format: YYYY-MM-DD (e.g., "2026-02-28").

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

PROBLEM: The user cancels or interrupts a task mid-execution.
  → If the task is quick:
    Run: bash <skill-path>/scripts/todo.sh done <id>
    Note the partial result in the completion message.
  → If the task is a project:
    Write a checkpoint: "Cancelled by user. Work completed so far: <summary>"
    Ask the user: "Should I mark this project as cancelled, or keep it paused for later?"
      "cancelled" → Run todo.sh done <id> with cancellation note.
      "paused"    → Leave status as "in_progress". Can be resumed next session.
  → If the task is recurring:
    Update status to "paused" in TRACKER.md.
    Tell the user: "Recurring task paused. Can be reactivated later."

PROBLEM: Multiple todos are active and a recurring task is due.
  → If the recurring task is short (one web search + summary): execute it first, then resume other work.
  → If the recurring task is long: defer it and note "OVERDUE" in TRACKER.md.
  → When resuming after a recurring task execution: go back to the in-progress project subtask.

PROBLEM: The user gives multiple new tasks at once.
  → Add ALL tasks to TRACKER.md first (one "todo.sh add" per task).
  → Then ask the user: "I've added N tasks. Which should I start with?"
  → If the user does not specify, work on the highest-priority task first.
    Priority order: high > medium > low. If equal priority, oldest first.
```

## 10a. Scope Change Workflow

When the user changes requirements for an existing todo, follow this section.
A scope change is NOT a new task. It modifies an existing todo.

Examples of scope changes:
- "I want CSV files, not a Word document."
- "Also include data from Swiss insurers."
- "Change the schedule from daily to weekly."
- "Add two more companies to the analysis."
- "Actually, I only need the last 3 years, not 7."

### Recognizing a Scope Change

```
When the user says something about an EXISTING todo, ask yourself:
  - Is the user giving NEW instructions for a todo that already exists?
  - Is the user changing the deliverable, the sources, the scope, or the format?
  - Is the user NOT asking for a completely different task?

If YES to any of these → this is a scope change. Follow the steps below.
If the user wants a completely different task → create a new todo instead.
If you are unsure → ask the user: "Should I update the existing task or create a new one?"
```

### Path A — Project Scope Change

This is the most common case. The user changes requirements for a project todo.

```
STEP 1: IDENTIFY THE CHANGE.
  Write down in one sentence what changed. Use one of these categories:
    - "deliverable-format": The output format changed (e.g., Word → CSV).
    - "sources": The data sources changed (e.g., add Swiss insurers).
    - "scope-reduction": The scope got smaller (e.g., 7 years → 3 years).
    - "scope-expansion": The scope got larger (e.g., add two more companies).
    - "goal": The fundamental goal changed (e.g., competitive analysis → regulatory overview).

STEP 2: IMPACT ANALYSIS.
  Read DATA_DIR/projects/<project-id>/plan.md.
  Go through EVERY subtask and assign ONE of these labels.

  For EACH subtask, answer these 4 questions in order:

    Q1: Is this subtask's OUTPUT still needed after the change?
        NO → label = "obsolete"
        YES → go to Q2

    Q2: Is this subtask already "done"?
        NO → go to Q3
        YES → go to Q4

    Q3: Does this subtask's DESCRIPTION or DELIVERABLE need to change?
        NO → label = "unaffected"
        YES → label = "modify"

    Q4: Does the COMPLETED WORK need to be REDONE with new requirements?
        (Example: output was Word, now must be CSV → work must be redone.)
        NO → label = "unaffected" (the done work is still valid)
        YES → label = "redo"

  After labeling all existing subtasks, ask:
    Does the change require ENTIRELY NEW work that no existing subtask covers?
    YES → label = "new" (add new subtask)

  Label summary:
    "unaffected" = no change needed (status stays as is)
    "modify"     = change description/deliverable (status stays "pending")
    "redo"       = reset status from "done" to "pending", change description
    "obsolete"   = set status to "cancelled"
    "new"        = add a new subtask row with status "pending"

  Write the impact as a list:
    Subtask 1: "Collect Allianz reports" → unaffected (data collection still valid)
    Subtask 2: "Collect Munich Re reports" → unaffected
    Subtask 6: "Write Allianz summary in Word" → redo (now: extract to CSV)
    Subtask 7: "Write Munich Re summary in Word" → modify (change deliverable to CSV)
    NEW: "Merge all CSVs into master dataset" → new subtask

STEP 3: CONFIRM WITH USER.
  Show the user the impact analysis. Use this exact format:

    "Scope change: <one-sentence description of what changed>

    Impact on subtasks:
    - Subtask 1: <title> → unaffected
    - Subtask 2: <title> → unaffected
    - Subtask 6: <title> → redo (reason: <why>)
    - Subtask 7: <title> → modify (change: <what changes>)
    - NEW subtask: <title>

    Shall I update the plan accordingly?"

  WAIT for the user to confirm. Do NOT proceed without confirmation.

STEP 4: UPDATE plan.md.
  After user confirms, edit plan.md:
    a. Subtasks labeled "redo":
       - Change status from "done" to "pending".
       - Update the description and deliverable to match new requirements.
    b. Subtasks labeled "modify":
       - Update the description and deliverable. Keep status as "pending".
    c. Subtasks labeled "obsolete":
       - Change status to "cancelled". Do NOT delete the row.
    d. New subtasks:
       - Add new rows at the end of the table with status "pending".
    e. Subtasks labeled "unaffected":
       - Do not change anything.

STEP 5: UPDATE TRACKER.md.
  Recalculate the subtask counter:
    - Count only subtasks with status "done" (not cancelled).
    - Count total as all subtasks EXCEPT "cancelled".
    - Example: 3 done, 2 cancelled, 5 pending → "3/10 done" becomes "1/8 done"
      (if 2 of the 3 done ones were set to "redo").
  Update the "Next step" field to reflect the new next subtask.

STEP 6: WRITE SCOPE-CHANGE CHECKPOINT.
  Run: bash <skill-path>/scripts/todo.sh checkpoint <id> "[SCOPE CHANGE] <description>"

  The checkpoint message MUST start with [SCOPE CHANGE] so it is easy to find later.
  Include:
    - What the user requested
    - Which subtasks were affected and how
    - New subtask count

  Example:
    "[SCOPE CHANGE] User requested CSV output instead of Word documents.
     Subtasks 6-8 changed from Word summaries to CSV extraction.
     Added subtask 11: merge all CSVs. New plan: 3/11 done."

STEP 7: RESUME WORK.
  Go back to Section 4, Phase 2, STEP 1 (find the next pending subtask).
  Continue working with the updated plan.
```

### Path B — Recurring Task Scope Change

```
STEP 1: IDENTIFY WHAT CHANGED.
  One of:
    - "schedule": The frequency changed (e.g., daily → weekly).
    - "sources": The source list changed (e.g., add a new website).
    - "instructions": The task instructions changed.
    - "dedup-rules": The deduplication method changed.
    - "notification-format": The output format changed.

STEP 2: UPDATE config.md.
  Open DATA_DIR/recurring/<task-id>/config.md.
  Edit ONLY the section that changed. Do not touch other sections.

STEP 3: HANDLE SIDE EFFECTS.
  - If "schedule" changed:
    Update TRACKER.md "Next run" based on the new schedule.
  - If "sources" changed:
    No side effects. New sources will be checked on next run.
  - If "dedup-rules" changed:
    Consider whether history.md should be cleared. If the dedup method changed
    fundamentally (e.g., from match-by-url to match-by-title), some old entries
    may cause false dedup matches. Ask the user: "Should I clear the history
    to start fresh with the new dedup rules, or keep existing history?"

STEP 4: WRITE CHECKPOINT.
  Add a note to DATA_DIR/recurring/<task-id>/history.md:
    "--- [SCOPE CHANGE] <date> ---
     <what changed>"

STEP 5: CONFIRM.
  Tell the user: "Updated recurring task '<title>'. Change: <what changed>.
  Next run: <date>."
```

### Path C — Quick Todo Escalation to Project

When a quick todo turns out to be too large for one session:

```
STEP 1: Mark the quick todo as done.
  Run: bash <skill-path>/scripts/todo.sh done <quick-id>
  The result note should say: "Escalated to project — task too large for single session."

STEP 2: Create a new project todo.
  Run: bash <skill-path>/scripts/todo.sh add project "<same title>" --priority <same priority>

STEP 3: Transfer completed work.
  Write the first checkpoint for the new project:
    "[ESCALATED FROM <quick-id>] Work already completed: <summary of what was done>"

STEP 4: Create the subtask plan.
  Follow Section 4, Phase 1, STEP 3 (break into subtasks).
  Mark any work already completed as subtask status "done".

STEP 5: Continue.
  Follow Section 4, Phase 2 (execution) with the remaining subtasks.
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
10. **Never apply a scope change without user confirmation.** Always show the impact analysis first.
11. **Mark scope-change checkpoints with [SCOPE CHANGE] prefix.** This makes them findable.
12. **Never restart a project from scratch** because of a scope change. Analyze which work is still valid.
13. **Never invent a todo ID.** Always use the ID returned by the script (last line of output).
14. **Keep checkpoint messages under 200 characters.** Always include files and blockers.
15. **When multiple tasks compete for attention**, add all to TRACKER.md first, then ask the user which to start.
