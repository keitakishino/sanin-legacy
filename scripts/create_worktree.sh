#!/bin/bash
# Script to create and setup a new git worktree with isolated Docker ports
# Usage:
#   create_worktree.sh --issue <number> --branch <branch-name>
#   create_worktree.sh --branch <branch-name>

set -e

WORKTREES_BASE_DIR="/home/pepo2/worktrees"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPTS_DIR")"

# Parse arguments
ISSUE_NUMBER=""
BRANCH_NAME=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --issue)
      ISSUE_NUMBER="$2"
      shift 2
      ;;
    --branch)
      BRANCH_NAME="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--issue <number>] --branch <branch-name>"
      exit 1
      ;;
  esac
done

# Validate branch name is provided
if [ -z "$BRANCH_NAME" ]; then
  echo "Error: --branch argument is required"
  echo "Usage: $0 [--issue <number>] --branch <branch-name>"
  exit 1
fi

# Derive worktree directory name from branch name
WORKTREE_DIR_NAME=$(echo "$BRANCH_NAME" | sed 's/[^a-zA-Z0-9._-]/-/g')
WORKTREE_PATH="$WORKTREES_BASE_DIR/$WORKTREE_DIR_NAME"

# Check if worktree already exists
if [ -d "$WORKTREE_PATH" ]; then
  echo "Error: Worktree already exists at $WORKTREE_PATH"
  exit 1
fi

# Create the git worktree
echo "Creating git worktree: $WORKTREE_PATH"
cd "$PROJECT_ROOT"
git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" origin/main

if [ ! -d "$WORKTREE_PATH" ]; then
  echo "Error: Failed to create git worktree"
  exit 1
fi

# Allocate ports using the Ruby script
echo "Allocating Docker ports..."
PORTS_JSON=$(ruby "$SCRIPTS_DIR/setup_worktree.rb" "$WORKTREE_DIR_NAME")

if ! command -v jq &> /dev/null; then
  # Fallback if jq is not available - parse JSON manually
  DB_PORT=$(echo "$PORTS_JSON" | grep -o '"DB_PORT":[0-9]*' | cut -d: -f2)
  APP_PORT=$(echo "$PORTS_JSON" | grep -o '"APP_PORT":[0-9]*' | cut -d: -f2)
else
  DB_PORT=$(echo "$PORTS_JSON" | jq -r '.DB_PORT')
  APP_PORT=$(echo "$PORTS_JSON" | jq -r '.APP_PORT')
fi

if [ -z "$DB_PORT" ] || [ -z "$APP_PORT" ]; then
  echo "Error: Failed to allocate ports"
  echo "Debug: PORTS_JSON = $PORTS_JSON"
  # Clean up the worktree since setup failed
  git worktree remove "$WORKTREE_PATH"
  exit 1
fi

# Copy .env.example to .env in the worktree
echo "Generating .env file..."
cp "$PROJECT_ROOT/.env.example" "$WORKTREE_PATH/.env"

# Append port configuration to .env
{
  echo ""
  echo "# Docker Compose Port Configuration"
  echo "# Automatically configured for worktree isolation"
  echo "DB_PORT=$DB_PORT"
  echo "APP_PORT=$APP_PORT"
} >> "$WORKTREE_PATH/.env"

# Success message
echo ""
echo "=========================================="
echo "Worktree setup completed successfully!"
echo "=========================================="
echo "Worktree path:     $WORKTREE_PATH"
echo "Branch name:       $BRANCH_NAME"
echo "DB port:           $DB_PORT"
echo "APP port:          $APP_PORT"
echo ""
echo "Next steps:"
echo "  1. cd $WORKTREE_PATH"
echo "  2. docker compose up -d"
echo "  3. docker compose exec web bundle exec rails server"
echo ""
if [ -n "$ISSUE_NUMBER" ]; then
  echo "Issue #$ISSUE_NUMBER"
fi
echo "=========================================="
