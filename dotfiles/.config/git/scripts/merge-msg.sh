#!/bin/sh

COMMIT_MSG_FILE="$1"
COMMIT_SOURCE="$2"

if [ "$COMMIT_SOURCE" = "merge" ]; then
    # Extract branch name without parentheses
    MERGED_BRANCH=$(sed -n "s/^Merge branch '\([^']*\)'.*/\1/p" "$COMMIT_MSG_FILE")

    # Fallback to MERGE_HEAD if sed didn't find a standard header
    if [ -z "$MERGED_BRANCH" ]; then
        MERGED_BRANCH=$(cat "$(git rev-parse --git-dir)/MERGE_HEAD" 2>/dev/null | git name-rev --name-only --stdin 2>/dev/null | tr -d '()')
    fi

    TARGET_BRANCH=$(git branch --show-current)

    cat <<EOF > "$COMMIT_MSG_FILE"
Merge branch '${MERGED_BRANCH:-unknown}' into '${TARGET_BRANCH}'
EOF
fi
