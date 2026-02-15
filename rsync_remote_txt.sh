#!/bin/bash
set -euo pipefail

# Script directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_PATH="$SCRIPT_DIR/.env"
LIST_PATH="$SCRIPT_DIR/backup_list.txt"
LOG_FILE="$SCRIPT_DIR/backup.log"

# 1. Validate files exist
[[ ! -f "$ENV_PATH" ]] && { echo "❌ Error: .env not found"; exit 1; }
[[ ! -f "$LIST_PATH" ]] && { echo "❌ Error: backup_list.txt not found"; exit 1; }

# 2. Load variables
set -a
source "$ENV_PATH"
set +a

# 3. Configure dynamic flags
EXTRA_FLAGS=""
if [[ "${1:-}" == "--dry-run" || "${DRY_RUN:-false}" == "true" ]]; then
  EXTRA_FLAGS="--dry-run"
  echo "⚠️  DRY-RUN MODE ACTIVATED: No real changes will be applied."
fi

[[ -t 1 ]] && EXTRA_FLAGS="$EXTRA_FLAGS --human-readable --progress"

# 4. Execute with Logging
{
  echo "-----------------------------------------------------"
  echo "📅 Date: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "🚀 Starting synchronization to ${REMOTE_IP}..."

  # Read the file line by line
  while read -r src dest || [[ -n "$src" ]]; do
    # Skip empty lines or comments
    [[ -z "$src" || "$src" =~ ^# ]] && continue

    echo "🔄 Syncing: $src ➡️  $dest"
    
    # Execute rsync for each pair
    # Note: Creates the destination directory if it doesn't exist using --rsync-path
    rsync -avz $EXTRA_FLAGS \
      -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=accept-new" \
      --rsync-path="mkdir -p $dest && rsync" \
      "$src" \
      "${REMOTE_USER}@${REMOTE_IP}:$dest"

  done < "$LIST_PATH"

  # 5. Remote cleanup (Global or per paths)
  # Here we maintain the cleanup on REMOTE_BACKUPS_PATH from .env as a "root" general
  if [[ -n "${DELETE_AFTER_DAYS:-}" && "$EXTRA_FLAGS" != *"--dry-run"* ]]; then
    echo "🧹 Cleaning files older than $DELETE_AFTER_DAYS days..."
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new "${REMOTE_USER}@${REMOTE_IP}" \
      "find ${REMOTE_BACKUPS_PATH} -type f -mtime +${DELETE_AFTER_DAYS} -delete"
    echo "🗑️ Cleanup finished."
  fi

  echo "✅ Process completed."
} 2>&1 | tee -a "$LOG_FILE"
