# Todo-Tracking Skill for OpenClaw — Implementation Plan

## Overview

A comprehensive todo-tracking skill for OpenClaw that supports three distinct todo types:
- **Quick**: Single-session tasks executed immediately
- **Project**: Multi-session tasks broken into structured subtasks
- **Recurring**: Scheduled periodic tasks with state tracking and deduplication

The skill is designed for agents running on mid-tier LLMs (like Kimi 2.5) — instructions are
explicit, step-by-step, and deterministic. No open-ended reasoning required.

---

## 1. Skill Package Structure (this repo)

```
todo-manager/
├── SKILL.md                              # Main skill definition
├── scripts/
│   └── todo.sh                           # CLI helper for CRUD operations
├── templates/
│   ├── TRACKER.md                        # Master todo tracker template
│   ├── project-plan.md                   # Project subtask breakdown template
│   ├── recurring-config.md               # Recurring task config template
│   └── daily-log.md                      # Daily execution log template
└── references/
    └── workflow-guide.md                 # Decision tree + worked examples
```

## 2. Runtime Data Structure (`~/.openclaw/todo-tracker/`)

```
~/.openclaw/todo-tracker/
├── TRACKER.md                            # Master todo list (single source of truth)
├── projects/
│   └── <project-id>/
│       ├── plan.md                       # Subtask breakdown with status
│       ├── checkpoint.md                 # Session-by-session progress log
│       └── data/                         # Collected files, CSVs, etc.
├── recurring/
│   └── <task-id>/
│       ├── config.md                     # Schedule + instructions + dedup rules
│       ├── history.md                    # Previous findings (for dedup comparison)
│       └── logs/
│           └── YYYY-MM-DD.md             # Daily execution logs
└── archive/
    └── <todo-id>.md                      # Archived completed todos
```

---

## 3. SKILL.md Design

### 3.1 Frontmatter

```yaml
---
name: todo-tracking
description: >
  Track and manage todos of three types:
  quick (single-session), project (multi-session with subtask breakdown),
  and recurring (scheduled periodic tasks with deduplication).
  Use when the user assigns a task, asks about pending work,
  or the heartbeat triggers a check.
emoji: 📋
user-invocable: true
requires:
  bins:
    - bash
---
```

### 3.2 Instruction Sections (Body of SKILL.md)

The SKILL.md body will be structured as follows:

#### Section 1: Initialization
- Check if `~/.openclaw/todo-tracker/` exists
- If not, create directory structure using `todo.sh init`
- Read `TRACKER.md` to load current state

#### Section 2: Decision Tree — "What type of todo is this?"
A deterministic flowchart the agent follows:

```
NEW TASK RECEIVED:
├── Can it be completed in THIS session, in a few steps?
│   └── YES → type: quick
├── Does it require collecting lots of data, multiple phases, or will take multiple sessions?
│   └── YES → type: project
├── Does it need to be repeated on a schedule (daily, weekly)?
│   └── YES → type: recurring
└── UNSURE → Ask the user to clarify
```

#### Section 3: Quick Todo Workflow
```
1. Add todo to TRACKER.md with status "open" and type "quick"
2. Execute the task immediately
3. Update TRACKER.md status to "done" with completion timestamp
4. Send result to user via notification channel
5. DO NOT send a "working on it" notification — just deliver the result
```

#### Section 4: Project Todo Workflow
```
PHASE 1 — PLANNING:
1. Add todo to TRACKER.md with status "planning" and type "project"
2. Create projects/<project-id>/plan.md
3. Break the goal into 3-10 numbered subtasks
4. Each subtask must be:
   - Specific enough to complete in one session
   - Have a clear deliverable (file, data, summary)
   - Be ordered by dependency (what must come first?)
5. Write subtasks into plan.md with status "pending"
6. Send notification: "Project created with N subtasks. Starting with: [first subtask]"

PHASE 2 — EXECUTION (repeat for each subtask):
1. Read plan.md to find the next "pending" subtask
2. Update subtask status to "in_progress"
3. Execute the subtask
4. Write checkpoint to checkpoint.md:
   - Date/time
   - What was done
   - What files were created/modified
   - Any blockers or open questions
5. Update subtask status to "done" in plan.md
6. If ALL subtasks are done → go to PHASE 3
7. If session is ending → save state, agent will resume next session

PHASE 3 — COMPLETION:
1. Update TRACKER.md status to "done"
2. Create final summary from all checkpoints
3. Send notification with summary and deliverables
4. Move todo to archive/
```

#### Section 5: Recurring Todo Workflow
```
SETUP (first time):
1. Add todo to TRACKER.md with status "active" and type "recurring"
2. Create recurring/<task-id>/config.md with:
   - Schedule (e.g., "daily", "every Monday", "every 6 hours")
   - Search instructions (what to look for, which sources)
   - Dedup rules (how to compare with previous findings)
   - Notification format (what the summary should contain)
3. Create empty history.md
4. Send notification: "Recurring task set up. First execution: [next scheduled time]"

EXECUTION (each scheduled run):
1. Read config.md for instructions
2. Read history.md for previous findings
3. Execute the task (e.g., search news)
4. Compare results with history.md:
   - If finding already in history → mark as "already known", skip
   - If finding is new → add to today's results
5. Write new findings to history.md (append, keep last 30 days)
6. Write daily log to logs/YYYY-MM-DD.md
7. Send notification with today's new findings only
```

#### Section 6: Heartbeat Integration
```
ON HEARTBEAT:
1. Read TRACKER.md
2. Check for:
   a. Quick todos older than 24 hours still "open" → flag as overdue
   b. Projects with no checkpoint in >48 hours → flag as stalled
   c. Recurring tasks due for execution → execute now
3. If any flags: send summary notification
4. If recurring tasks are due: execute them (follow Section 5 EXECUTION)
```

#### Section 7: Session Resume
```
AT SESSION START:
1. Read TRACKER.md
2. Check for any "in_progress" items from previous session
3. If found:
   a. Read the corresponding checkpoint.md or daily log
   b. Display: "Resuming: [task title]. Last checkpoint: [summary]"
   c. Continue from where the last session ended
```

#### Section 8: Notification Abstraction
```
WHEN SENDING A NOTIFICATION:
1. Compose the message content first
2. Determine the channel:
   - If agentmail skill is available → use agentmail to send email
   - If slack skill is available → post to configured channel
   - If no channel available → write to TRACKER.md as a note
3. Log the notification in the todo's checkpoint/log
```

#### Section 9: TRACKER.md Format Specification
```markdown
# Todo Tracker

## Active Todos

### [Q-001] Web search: Topic X
- **Type**: quick
- **Status**: open
- **Created**: 2026-02-27
- **Priority**: medium

### [P-001] Market analysis: German insurance
- **Type**: project
- **Status**: in_progress
- **Created**: 2026-02-20
- **Subtasks**: 3/8 done
- **Last checkpoint**: 2026-02-26 — Collected Allianz annual reports 2018-2024
- **Next step**: Download Munich Re annual reports

### [R-001] Daily insurance news monitoring
- **Type**: recurring
- **Status**: active
- **Schedule**: daily
- **Last run**: 2026-02-26
- **Next run**: 2026-02-27

## Completed Todos
(moved here when done, with completion date)
```

---

## 4. Scripts — `todo.sh`

A bash script providing CLI operations for the agent:

| Command | Description |
|---------|-------------|
| `todo.sh init` | Create data directory structure at `~/.openclaw/todo-tracker/` |
| `todo.sh add quick "title" [--priority P]` | Add a quick todo |
| `todo.sh add project "title" [--priority P]` | Add a project todo |
| `todo.sh add recurring "title" --schedule S` | Add a recurring todo |
| `todo.sh list [--type T] [--status S]` | List todos with optional filters |
| `todo.sh show <id>` | Show full details of a todo |
| `todo.sh update <id> --status S` | Update todo status |
| `todo.sh checkpoint <id> "message"` | Add checkpoint to project |
| `todo.sh done <id>` | Mark todo as completed, archive it |
| `todo.sh heartbeat` | Run heartbeat checks, return action items |
| `todo.sh next` | Show the next actionable item |

The script operates purely on markdown files — no database needed. This keeps
everything human-readable and debuggable.

---

## 5. Templates

### 5.1 `templates/TRACKER.md`
Pre-formatted master tracker with sections for active and completed todos,
ID generation scheme (Q-NNN, P-NNN, R-NNN), and formatting rules.

### 5.2 `templates/project-plan.md`
Template for project subtask breakdown:
- Goal statement
- Numbered subtask list with status, deliverable, and dependencies
- Notes section for blockers

### 5.3 `templates/recurring-config.md`
Template for recurring task configuration:
- Schedule definition
- Source list (where to search)
- Dedup rules (match by title? URL? content hash?)
- Notification format template

### 5.4 `templates/daily-log.md`
Template for daily execution logs:
- Execution timestamp
- Sources checked
- New findings (with URLs)
- Skipped (already known) items
- Summary for notification

---

## 6. References — `workflow-guide.md`

A reference document for the agent containing:
- Three worked examples (one per todo type) based on the user's insurance domain
- Common mistakes and how to avoid them
- "What to do when stuck" decision tree
- File path reference table

---

## 7. Implementation Order

1. **SKILL.md** — Core skill definition with all instructions
2. **scripts/todo.sh** — CLI helper script
3. **templates/** — All four templates
4. **references/workflow-guide.md** — Worked examples and decision trees
5. **Testing** — Manual walkthrough of each workflow

---

## 8. Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Storage format | Markdown files | Human-readable, works with any LLM, easy to debug |
| State management | File-based (no DB) | Simpler for mid-tier LLMs, no dependencies |
| Notification | Abstracted channel | Works with agentmail today, extensible to Slack etc. |
| Language | English (instructions) | OpenClaw ecosystem standard, better cross-model compatibility |
| Todo IDs | Prefixed counters (Q-001) | Type-identifiable, simple to generate in bash |
| Dedup strategy | Title + URL matching | Simple, effective for news monitoring use case |
| Heartbeat integration | Built-in | Essential for recurring tasks, overdue detection |
| Subtask depth | Single level only | Keeps complexity manageable for smaller LLMs |
