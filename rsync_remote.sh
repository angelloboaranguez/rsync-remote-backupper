#!/bin/bash
set -euo pipefail

# Script directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_PATH="$SCRIPT_DIR/.env"
LIST_PATH="$SCRIPT_DIR/config/backup_list.json"
LOG_FILE="$SCRIPT_DIR/backup.log"

# 1. Dependency check (jq)
if ! command -v jq &> /dev/null; then
    echo "📦 'jq' not found. Installing..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y jq
    elif command -v yum &> /dev/null; then
        sudo yum install -y jq
    else
        echo "❌ Error: Could not install 'jq'. Please install it manually."
        exit 1
    fi
fi

# 2. Validate files
[[ ! -f "$ENV_PATH" ]] && { echo "❌ Error: .env not found"; exit 1; }
[[ ! -f "$LIST_PATH" ]] && { echo "❌ Error: backup_list.json not found"; exit 1; }

# 3. Load variables
set -a
source "$ENV_PATH"
set +a

# 4. Configure dynamic flags
EXTRA_FLAGS=""
if [[ "${1:-}" == "--dry-run" || "${DRY_RUN:-false}" == "true" ]]; then
  EXTRA_FLAGS="--dry-run"
  echo "⚠️  DRY-RUN MODE ACTIVATED."
fi

[[ -t 1 ]] && EXTRA_FLAGS="$EXTRA_FLAGS --human-readable --progress"

# 5. Execute with Logging
{
  echo "-----------------------------------------------------"
  echo "📅 Date: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "🚀 Starting synchronization to ${REMOTE_IP}..."

  # Process the JSON with jq
  # We use base64 to avoid problems with spaces in the paths
  for row in $(jq -r '.[] | @base64' "$LIST_PATH"); do
    _jq() {
      echo "${row}" | base64 --decode | jq -r "${1}"
    }

    src=$(_jq '.source')
    dest=$(_jq '.target')
    days=$(_jq '.retention_days')

    echo "🔄 Syncing: $src ➡️  $dest (Retention: $days days)"
    
    # Rsync synchronization
    rsync -avz $EXTRA_FLAGS \
      -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=accept-new" \
      --rsync-path="mkdir -p $dest && rsync" \
      "$src" \
      "${REMOTE_USER}@${REMOTE_IP}:$dest"

    # Remote cleanup specific to each path
    if [[ "$EXTRA_FLAGS" != *"--dry-run"* && "$days" != "null" ]]; then
      ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new "${REMOTE_USER}@${REMOTE_IP}" \
        "find $dest -type f -mtime +$days -delete 2>/dev/null || true"
    fi
  done

  echo "✅ Process completed."
} 2>&1 | tee -a "$LOG_FILE"
