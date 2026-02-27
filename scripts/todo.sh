#!/usr/bin/env bash
# todo.sh — CLI helper for the todo-tracking OpenClaw skill
# Operates on markdown files in DATA_DIR (~/.openclaw/todo-tracker/)
set -euo pipefail

DATA_DIR="${TODO_DATA_DIR:-$HOME/.openclaw/todo-tracker}"
TRACKER="$DATA_DIR/TRACKER.md"

# ── Helpers ──────────────────────────────────────────────────────────────────

today() { date +%Y-%m-%d; }
now()   { date "+%Y-%m-%d %H:%M"; }

die() { echo "ERROR: $*" >&2; exit 1; }

ensure_tracker() {
  [[ -f "$TRACKER" ]] || die "TRACKER.md not found. Run: $0 init"
}

# Read the next counter for a given type prefix (Q, P, R) and increment it.
next_id() {
  local prefix="$1"
  local type_key
  case "$prefix" in
    Q) type_key="quick" ;;
    P) type_key="project" ;;
    R) type_key="recurring" ;;
    *) die "Unknown prefix: $prefix" ;;
  esac

  local current
  current=$(grep -E "^- ${type_key}: " "$TRACKER" | head -1 | sed "s/^- ${type_key}: //")
  [[ -z "$current" ]] && current=1

  local id
  id=$(printf "%s-%03d" "$prefix" "$current")

  local next=$(( current + 1 ))
  sed -i "s/^- ${type_key}: ${current}$/- ${type_key}: ${next}/" "$TRACKER"

  echo "$id"
}

# ── Commands ─────────────────────────────────────────────────────────────────

cmd_init() {
  echo "Initializing todo-tracker data directory at $DATA_DIR ..."
  mkdir -p "$DATA_DIR/projects"
  mkdir -p "$DATA_DIR/recurring"
  mkdir -p "$DATA_DIR/archive"

  if [[ ! -f "$TRACKER" ]]; then
    # Find the templates directory relative to this script
    local script_dir
    script_dir="$(cd "$(dirname "$0")" && pwd)"
    local template_dir="$script_dir/../templates"

    if [[ -f "$template_dir/TRACKER.md" ]]; then
      cp "$template_dir/TRACKER.md" "$TRACKER"
    else
      # Inline fallback template
      cat > "$TRACKER" <<'TMPL'
# Todo Tracker

## Counters
- quick: 1
- project: 1
- recurring: 1

## Active Todos

## Completed Todos
TMPL
    fi
    echo "Created $TRACKER"
  else
    echo "$TRACKER already exists, skipping."
  fi
  echo "Done."
}

cmd_add() {
  ensure_tracker
  local type="${1:-}"
  local title="${2:-}"
  local priority="medium"
  local schedule=""

  [[ -z "$type" ]]  && die "Usage: $0 add <quick|project|recurring> \"title\" [--priority P] [--schedule S]"
  [[ -z "$title" ]] && die "Usage: $0 add $type \"title\" [--priority P] [--schedule S]"

  shift 2
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --priority) priority="${2:-medium}"; shift 2 ;;
      --schedule) schedule="${2:-}"; shift 2 ;;
      *) shift ;;
    esac
  done

  local prefix id
  case "$type" in
    quick)     prefix="Q" ;;
    project)   prefix="P" ;;
    recurring) prefix="R" ;;
    *) die "Unknown type: $type. Use: quick, project, or recurring." ;;
  esac

  id=$(next_id "$prefix")

  # Build the entry
  local entry=""
  case "$type" in
    quick)
      entry=$(cat <<EOF

### [$id] $title
- **Type**: quick
- **Status**: open
- **Created**: $(today)
- **Priority**: $priority
EOF
      )
      ;;
    project)
      local project_dir="$DATA_DIR/projects/$id"
      mkdir -p "$project_dir/data"

      # Create plan.md from template or inline
      local script_dir
      script_dir="$(cd "$(dirname "$0")" && pwd)"
      local template_dir="$script_dir/../templates"

      if [[ -f "$template_dir/project-plan.md" ]]; then
        sed "s/{{ID}}/$id/g; s/{{TITLE}}/$title/g; s/{{DATE}}/$(today)/g" \
          "$template_dir/project-plan.md" > "$project_dir/plan.md"
      else
        cat > "$project_dir/plan.md" <<PLAN
# Project Plan: $title
**ID**: $id
**Created**: $(today)

## Goal
<!-- Describe the goal of this project -->

## Subtasks

| # | Subtask | Status | Deliverable | Depends on |
|---|---------|--------|-------------|------------|
| 1 | | pending | | — |

## Notes
PLAN
      fi

      # Create empty checkpoint.md
      cat > "$project_dir/checkpoint.md" <<CKPT
# Checkpoints: [$id] $title

<!-- Append checkpoints below. Do not edit existing entries. -->
CKPT

      entry=$(cat <<EOF

### [$id] $title
- **Type**: project
- **Status**: planning
- **Created**: $(today)
- **Priority**: $priority
- **Subtasks**: 0/0 done
- **Last checkpoint**: —
- **Next step**: Break down into subtasks
EOF
      )
      echo "Created project directory: $project_dir"
      ;;
    recurring)
      [[ -z "$schedule" ]] && die "Recurring todos require --schedule. Example: --schedule daily"

      local rec_dir="$DATA_DIR/recurring/$id"
      mkdir -p "$rec_dir/logs"

      # Create config.md from template or inline
      local script_dir
      script_dir="$(cd "$(dirname "$0")" && pwd)"
      local template_dir="$script_dir/../templates"

      if [[ -f "$template_dir/recurring-config.md" ]]; then
        sed "s/{{ID}}/$id/g; s/{{TITLE}}/$title/g; s/{{SCHEDULE}}/$schedule/g; s/{{DATE}}/$(today)/g" \
          "$template_dir/recurring-config.md" > "$rec_dir/config.md"
      else
        cat > "$rec_dir/config.md" <<CONF
# Recurring Task: $title
**ID**: $id
**Schedule**: $schedule
**Created**: $(today)

## Instructions
<!-- What exactly should be done each run? -->

## Sources
<!-- Where to look (URLs, search terms, etc.) -->

## Dedup Rules
**Method**: match-by-title
<!-- Options: match-by-title, match-by-url, match-by-title-and-source -->

## Notification Format
<!-- What should the summary look like? -->
CONF
      fi

      # Create empty history.md
      cat > "$rec_dir/history.md" <<HIST
# History: [$id] $title

<!-- Previous findings are appended below. Entries older than 30 days are removed. -->
HIST

      # Calculate next run
      local next_run
      case "$schedule" in
        daily)    next_run=$(today) ;;
        weekly)   next_run=$(date -d "+7 days" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d) ;;
        weekdays) next_run=$(today) ;;
        monthly)  next_run=$(date -d "+1 month" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d) ;;
        *)        next_run=$(today) ;;
      esac

      entry=$(cat <<EOF

### [$id] $title
- **Type**: recurring
- **Status**: active
- **Schedule**: $schedule
- **Created**: $(today)
- **Last run**: —
- **Next run**: $next_run
EOF
      )
      echo "Created recurring directory: $rec_dir"
      ;;
  esac

  # Insert entry before "## Completed Todos" using awk (sed breaks on multiline)
  local tmpfile
  tmpfile=$(mktemp)
  awk -v entry="$entry" '/^## Completed Todos$/{print entry; print ""}1' "$TRACKER" > "$tmpfile"
  mv "$tmpfile" "$TRACKER"

  echo "Added: [$id] $title (type=$type, priority=$priority)"
  echo "$id"
}

cmd_list() {
  ensure_tracker
  local filter_type=""
  local filter_status=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type)   filter_type="$2"; shift 2 ;;
      --status) filter_status="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  echo "=== Active Todos ==="
  local in_active=0
  local in_completed=0
  local current_id="" current_title="" current_type="" current_status=""
  local show_current=0

  while IFS= read -r line; do
    if [[ "$line" == "## Active Todos" ]]; then
      in_active=1; in_completed=0; continue
    fi
    if [[ "$line" == "## Completed Todos" ]]; then
      # Print last active entry if needed
      if [[ $show_current -eq 1 && -n "$current_id" ]]; then
        echo "  [$current_id] $current_title ($current_type, $current_status)"
      fi
      in_active=0; in_completed=1
      current_id=""; show_current=0
      echo ""
      echo "=== Completed Todos ==="
      continue
    fi

    if [[ $in_active -eq 1 || $in_completed -eq 1 ]]; then
      if [[ "$line" =~ ^###\ \[([A-Z]-[0-9]+)\]\ (.+)$ ]]; then
        # Print previous entry if it matched filters
        if [[ $show_current -eq 1 && -n "$current_id" ]]; then
          echo "  [$current_id] $current_title ($current_type, $current_status)"
        fi
        current_id="${BASH_REMATCH[1]}"
        current_title="${BASH_REMATCH[2]}"
        current_type=""
        current_status=""
        show_current=0
      elif [[ "$line" =~ ^\-\ \*\*Type\*\*:\ (.+)$ ]]; then
        current_type="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^\-\ \*\*Status\*\*:\ (.+)$ ]]; then
        current_status="${BASH_REMATCH[1]}"
        # Apply filters
        show_current=1
        if [[ -n "$filter_type" && "$current_type" != "$filter_type" ]]; then
          show_current=0
        fi
        if [[ -n "$filter_status" && "$current_status" != "$filter_status" ]]; then
          show_current=0
        fi
      fi
    fi
  done < "$TRACKER"

  # Print last entry
  if [[ $show_current -eq 1 && -n "$current_id" ]]; then
    echo "  [$current_id] $current_title ($current_type, $current_status)"
  fi
}

cmd_show() {
  ensure_tracker
  local id="${1:-}"
  [[ -z "$id" ]] && die "Usage: $0 show <id>"

  local found=0
  local printing=0

  while IFS= read -r line; do
    if [[ "$line" =~ ^###\ \[$id\] ]]; then
      found=1; printing=1
      echo "$line"
      continue
    fi
    if [[ $printing -eq 1 ]]; then
      if [[ "$line" =~ ^###\  || "$line" =~ ^##\  ]]; then
        break
      fi
      echo "$line"
    fi
  done < "$TRACKER"

  [[ $found -eq 0 ]] && die "Todo $id not found."

  # Show additional files for projects and recurring
  local prefix="${id%%-*}"
  case "$prefix" in
    P)
      if [[ -d "$DATA_DIR/projects/$id" ]]; then
        echo ""
        echo "=== Project Plan ==="
        cat "$DATA_DIR/projects/$id/plan.md"
        echo ""
        echo "=== Checkpoints ==="
        cat "$DATA_DIR/projects/$id/checkpoint.md"
      fi
      ;;
    R)
      if [[ -d "$DATA_DIR/recurring/$id" ]]; then
        echo ""
        echo "=== Configuration ==="
        cat "$DATA_DIR/recurring/$id/config.md"
        echo ""
        echo "=== Recent History ==="
        tail -30 "$DATA_DIR/recurring/$id/history.md" 2>/dev/null || echo "(empty)"
      fi
      ;;
  esac
}

cmd_update() {
  ensure_tracker
  local id="${1:-}"
  local new_status=""

  [[ -z "$id" ]] && die "Usage: $0 update <id> --status <new-status>"
  shift

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status) new_status="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [[ -z "$new_status" ]] && die "Usage: $0 update <id> --status <new-status>"

  if ! grep -q "^### \[$id\]" "$TRACKER"; then
    die "Todo $id not found."
  fi

  # Update the status line for this specific todo block
  # Strategy: find the line range for this todo, then update the Status line within it
  local start_line end_line
  start_line=$(grep -n "^### \[$id\]" "$TRACKER" | head -1 | cut -d: -f1)

  # Find the next section header after the start line
  end_line=$(tail -n +"$((start_line + 1))" "$TRACKER" | grep -n "^###\|^##" | head -1 | cut -d: -f1)
  if [[ -n "$end_line" ]]; then
    end_line=$((start_line + end_line - 1))
  else
    end_line=$(wc -l < "$TRACKER")
  fi

  # Update status within the block
  sed -i "${start_line},${end_line}s/^\(- \*\*Status\*\*: \).*/\1${new_status}/" "$TRACKER"

  echo "Updated [$id] status → $new_status"
}

cmd_checkpoint() {
  ensure_tracker
  local id="${1:-}"
  local message="${2:-}"

  [[ -z "$id" ]]      && die "Usage: $0 checkpoint <id> \"message\""
  [[ -z "$message" ]]  && die "Usage: $0 checkpoint <id> \"message\""

  local prefix="${id%%-*}"
  [[ "$prefix" != "P" ]] && die "Checkpoints are only for project todos (P-NNN)."

  local project_dir="$DATA_DIR/projects/$id"
  [[ ! -d "$project_dir" ]] && die "Project directory not found: $project_dir"

  local ckpt_file="$project_dir/checkpoint.md"

  # Append checkpoint
  cat >> "$ckpt_file" <<EOF

### $(now)
$message
EOF

  # Update "Last checkpoint" in TRACKER.md
  local start_line end_line
  start_line=$(grep -n "^### \[$id\]" "$TRACKER" | head -1 | cut -d: -f1)
  end_line=$(tail -n +"$((start_line + 1))" "$TRACKER" | grep -n "^###\|^##" | head -1 | cut -d: -f1)
  if [[ -n "$end_line" ]]; then
    end_line=$((start_line + end_line - 1))
  else
    end_line=$(wc -l < "$TRACKER")
  fi

  # Truncate message for the tracker summary
  local short_msg="${message:0:80}"
  sed -i "${start_line},${end_line}s|^\(- \*\*Last checkpoint\*\*: \).*|\1$(today) — ${short_msg}|" "$TRACKER"

  echo "Checkpoint added to [$id]: $short_msg"
}

cmd_done() {
  ensure_tracker
  local id="${1:-}"
  [[ -z "$id" ]] && die "Usage: $0 done <id>"

  if ! grep -q "^### \[$id\]" "$TRACKER"; then
    die "Todo $id not found."
  fi

  # Extract the full block
  local start_line end_line block
  start_line=$(grep -n "^### \[$id\]" "$TRACKER" | head -1 | cut -d: -f1)
  end_line=$(tail -n +"$((start_line + 1))" "$TRACKER" | grep -n "^###\|^##" | head -1 | cut -d: -f1)
  if [[ -n "$end_line" ]]; then
    end_line=$((start_line + end_line - 1))
  else
    end_line=$(wc -l < "$TRACKER")
  fi

  block=$(sed -n "${start_line},${end_line}p" "$TRACKER")

  # Remove the block from active section
  sed -i "${start_line},${end_line}d" "$TRACKER"

  # Extract title for the completed entry
  local title
  title=$(echo "$block" | head -1 | sed 's/^### \[.*\] //')

  # Append a compact entry to "## Completed Todos"
  cat >> "$TRACKER" <<EOF

### [$id] $title
- **Completed**: $(today)
- **Result**: (completed)
EOF

  # Archive project data if applicable
  local prefix="${id%%-*}"
  if [[ "$prefix" == "P" && -d "$DATA_DIR/projects/$id" ]]; then
    if [[ ! -d "$DATA_DIR/archive" ]]; then
      mkdir -p "$DATA_DIR/archive"
    fi
    cp -r "$DATA_DIR/projects/$id" "$DATA_DIR/archive/$id"
    echo "Project data archived to $DATA_DIR/archive/$id"
  fi

  echo "Completed: [$id] $title"
}

cmd_next() {
  ensure_tracker

  # Find the first active todo by priority (high > medium > low)
  local best_id="" best_title="" best_type="" best_priority="" best_rank=99

  local current_id="" current_title="" current_type="" current_priority=""
  local in_active=0

  while IFS= read -r line; do
    [[ "$line" == "## Active Todos" ]] && { in_active=1; continue; }
    [[ "$line" == "## Completed Todos" ]] && break

    if [[ $in_active -eq 1 ]]; then
      if [[ "$line" =~ ^###\ \[([A-Z]-[0-9]+)\]\ (.+)$ ]]; then
        # Evaluate previous entry
        if [[ -n "$current_id" ]]; then
          local rank=2
          case "$current_priority" in high) rank=0 ;; medium) rank=1 ;; low) rank=2 ;; esac
          if [[ $rank -lt $best_rank ]]; then
            best_id="$current_id"; best_title="$current_title"
            best_type="$current_type"; best_priority="$current_priority"
            best_rank=$rank
          fi
        fi
        current_id="${BASH_REMATCH[1]}"
        current_title="${BASH_REMATCH[2]}"
        current_type=""; current_priority=""
      elif [[ "$line" =~ ^\-\ \*\*Type\*\*:\ (.+)$ ]]; then
        current_type="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^\-\ \*\*Priority\*\*:\ (.+)$ ]]; then
        current_priority="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^\-\ \*\*Status\*\*:\ (.+)$ ]]; then
        local status="${BASH_REMATCH[1]}"
        # Skip items that are already done or active (recurring)
        if [[ "$status" == "done" ]]; then
          current_id=""
        fi
      fi
    fi
  done < "$TRACKER"

  # Check last entry
  if [[ -n "$current_id" ]]; then
    local rank=2
    case "$current_priority" in high) rank=0 ;; medium) rank=1 ;; low) rank=2 ;; esac
    if [[ $rank -lt $best_rank ]]; then
      best_id="$current_id"; best_title="$current_title"
      best_type="$current_type"; best_priority="$current_priority"
    fi
  fi

  if [[ -n "$best_id" ]]; then
    echo "Next: [$best_id] $best_title (type=$best_type, priority=$best_priority)"
  else
    echo "No pending todos."
  fi
}

cmd_heartbeat() {
  ensure_tracker

  local overdue_count=0
  local stalled_count=0
  local due_count=0
  local actions=""
  local today_stamp
  today_stamp=$(today)

  local current_id="" current_type="" current_status="" current_created=""
  local current_schedule="" current_next_run="" current_last_checkpoint=""
  local in_active=0

  while IFS= read -r line; do
    [[ "$line" == "## Active Todos" ]] && { in_active=1; continue; }
    [[ "$line" == "## Completed Todos" ]] && {
      # Process last entry
      if [[ -n "$current_id" ]]; then
        _heartbeat_check
      fi
      break
    }

    if [[ $in_active -eq 1 ]]; then
      if [[ "$line" =~ ^###\ \[([A-Z]-[0-9]+)\]\ (.+)$ ]]; then
        # Process previous entry
        if [[ -n "$current_id" ]]; then
          _heartbeat_check
        fi
        current_id="${BASH_REMATCH[1]}"
        current_type=""; current_status=""; current_created=""
        current_schedule=""; current_next_run=""; current_last_checkpoint=""
      elif [[ "$line" =~ ^\-\ \*\*Type\*\*:\ (.+)$ ]]; then
        current_type="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^\-\ \*\*Status\*\*:\ (.+)$ ]]; then
        current_status="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^\-\ \*\*Created\*\*:\ (.+)$ ]]; then
        current_created="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^\-\ \*\*Schedule\*\*:\ (.+)$ ]]; then
        current_schedule="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^\-\ \*\*Next\ run\*\*:\ (.+)$ ]]; then
        current_next_run="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^\-\ \*\*Last\ checkpoint\*\*:\ (.+)$ ]]; then
        current_last_checkpoint="${BASH_REMATCH[1]}"
      fi
    fi
  done < "$TRACKER"

  echo "=== Heartbeat Check — $today_stamp ==="
  echo "Overdue quick todos: $overdue_count"
  echo "Stalled projects: $stalled_count"
  echo "Due recurring tasks: $due_count"
  if [[ -n "$actions" ]]; then
    echo ""
    echo "Actions needed:"
    echo "$actions"
  else
    echo ""
    echo "No actions needed."
  fi
}

_heartbeat_check() {
  local today_epoch
  today_epoch=$(date -d "$(today)" +%s 2>/dev/null || date +%s)

  case "$current_type" in
    quick)
      if [[ "$current_status" == "open" && -n "$current_created" ]]; then
        local created_epoch
        created_epoch=$(date -d "$current_created" +%s 2>/dev/null || echo 0)
        local age_hours=$(( (today_epoch - created_epoch) / 3600 ))
        if [[ $age_hours -ge 24 ]]; then
          overdue_count=$((overdue_count + 1))
          actions="${actions}  - OVERDUE: [$current_id] open since $current_created
"
        fi
      fi
      ;;
    project)
      if [[ "$current_status" == "in_progress" ]]; then
        local ckpt_date=""
        if [[ "$current_last_checkpoint" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
          ckpt_date="${BASH_REMATCH[1]}"
        fi
        if [[ -n "$ckpt_date" ]]; then
          local ckpt_epoch
          ckpt_epoch=$(date -d "$ckpt_date" +%s 2>/dev/null || echo 0)
          local stale_hours=$(( (today_epoch - ckpt_epoch) / 3600 ))
          if [[ $stale_hours -ge 48 ]]; then
            stalled_count=$((stalled_count + 1))
            actions="${actions}  - STALLED: [$current_id] no checkpoint since $ckpt_date
"
          fi
        fi
      fi
      ;;
    recurring)
      if [[ "$current_status" == "active" && -n "$current_next_run" ]]; then
        if [[ "$current_next_run" != "—" ]]; then
          local next_epoch
          next_epoch=$(date -d "$current_next_run" +%s 2>/dev/null || echo 999999999999)
          if [[ $today_epoch -ge $next_epoch ]]; then
            due_count=$((due_count + 1))
            actions="${actions}  - DUE: [$current_id] scheduled for $current_next_run
"
          fi
        fi
      fi
      ;;
  esac
}

# ── Main dispatch ────────────────────────────────────────────────────────────

usage() {
  cat <<EOF
Usage: $0 <command> [arguments]

Commands:
  init                                    Initialize data directory
  add <quick|project|recurring> "title"   Add a new todo
      [--priority high|medium|low]
      [--schedule daily|weekly|...]       (required for recurring)
  list [--type T] [--status S]            List todos
  show <id>                               Show todo details
  update <id> --status <status>           Update todo status
  checkpoint <id> "message"               Add checkpoint (projects only)
  done <id>                               Mark todo as completed
  next                                    Show next actionable todo
  heartbeat                               Run heartbeat checks
EOF
}

cmd="${1:-}"
shift 2>/dev/null || true

case "$cmd" in
  init)       cmd_init ;;
  add)        cmd_add "$@" ;;
  list)       cmd_list "$@" ;;
  show)       cmd_show "$@" ;;
  update)     cmd_update "$@" ;;
  checkpoint) cmd_checkpoint "$@" ;;
  done)       cmd_done "$@" ;;
  next)       cmd_next ;;
  heartbeat)  cmd_heartbeat ;;
  help|--help|-h|"") usage ;;
  *)          die "Unknown command: $cmd. Run: $0 help" ;;
esac
