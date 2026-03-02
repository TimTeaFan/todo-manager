# Todo-Tracking Skill for OpenClaw

A task-tracking skill that manages three types of todos:

- **Quick** — single-session tasks, executed immediately
- **Project** — multi-session tasks with subtask breakdown and checkpoints
- **Recurring** — scheduled periodic tasks with deduplication

Designed for mid-tier LLMs — all instructions are explicit, step-by-step, and deterministic.

## Repository Structure

```
todo-manager/
├── SKILL.md                    # Skill definition (main entry point)
├── scripts/
│   └── todo.sh                 # CLI helper for CRUD operations
├── templates/
│   ├── TRACKER.md              # Master todo tracker template
│   ├── project-plan.md         # Project subtask breakdown template
│   ├── recurring-config.md     # Recurring task config template
│   └── daily-log.md            # Daily execution log template
└── references/
    └── workflow-guide.md       # Decision tree + worked examples
```

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/TimTeaFan/todo-manager.git
```

### 2. Register the skill in your OpenClaw config

Add the following entry to your `~/.openclaw/settings.json` under the `skills` array:

```json
{
  "skills": [
    {
      "name": "todo-tracking",
      "path": "/absolute/path/to/todo-manager"
    }
  ]
}
```

Replace `/absolute/path/to/todo-manager` with the actual path where you cloned the repo.

### 3. Initialize the data directory

On first use, the skill will automatically create `~/.openclaw/todo-tracker/` via:

```bash
bash /path/to/todo-manager/scripts/todo.sh init
```

You can also run this manually to set up the data directory before first use.

## Usage

Once installed, invoke the skill in an OpenClaw session:

```
/todo-tracking
```

The agent will then track todos for you. Examples:

- *"Add a task to refactor the auth module"* — creates a quick or project todo
- *"Remind me to check server logs every Monday"* — creates a recurring todo
- *"What's on my todo list?"* — shows current state from `TRACKER.md`

## Requirements

- `bash` (used by `scripts/todo.sh`)

## How It Works

- All runtime data is stored in `~/.openclaw/todo-tracker/` and persists across sessions.
- `SKILL.md` contains the full agent instructions — the agent reads and follows them directly.
- `scripts/todo.sh` handles CRUD operations (add, update, complete, list, archive).
- `templates/` provides initial file structures that get copied into the data directory.
- `references/workflow-guide.md` contains worked examples and the decision tree logic.
