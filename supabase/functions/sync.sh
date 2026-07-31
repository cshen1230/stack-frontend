#!/usr/bin/env bash
#
# Keeps supabase/functions/ honest against what is actually deployed.
#
# The list of functions is derived from the Swift source every run rather than hardcoded, so
# it can't go stale: whatever the app calls is what this checks for and pulls.
#
#   ./supabase/functions/sync.sh check    # report drift, change nothing (default)
#   ./supabase/functions/sync.sh pull     # download every deployed function into the repo
#
# `pull` needs the Supabase CLI and a login:
#   brew install supabase/tap/supabase && supabase login
#
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FUNCTIONS_DIR="$REPO_ROOT/supabase/functions"
PROJECT_REF="cmfjafuqfqfggzdwpvwo"
MODE="${1:-check}"

# Every name passed to functions.invoke("…") anywhere in the app.
invoked() {
    grep -rhzoP 'functions\.invoke\(\s*"[a-z-]+"' "$REPO_ROOT/StackPickleball" \
        | tr '\0' '\n' \
        | grep -oP '"[a-z-]+"' \
        | tr -d '"' \
        | sort -u
}

# Every function with source checked in.
present() {
    find "$FUNCTIONS_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '_shared' -exec basename {} \; | sort
}

missing() {
    comm -23 <(invoked) <(present)
}

# Source with no caller. Not necessarily dead — could be a webhook or a cron target — so this
# only reports.
orphaned() {
    comm -13 <(invoked) <(present)
}

case "$MODE" in
check)
    echo "Edge functions the app calls: $(invoked | wc -l | tr -d ' ')"
    echo "With source in this repo:     $(present | wc -l | tr -d ' ')"

    gap="$(missing)"
    if [ -n "$gap" ]; then
        echo
        echo "MISSING — deployed but not in the repo. Server behaviour here cannot be read,"
        echo "reviewed or changed from source. Run './supabase/functions/sync.sh pull'."
        echo "$gap" | sed 's/^/  - /'
    fi

    extra="$(orphaned)"
    if [ -n "$extra" ]; then
        echo
        echo "No caller in the app (may still be a webhook or scheduled job):"
        echo "$extra" | sed 's/^/  - /'
    fi

    [ -z "$gap" ] && echo && echo "In sync."
    [ -n "$gap" ] && exit 1
    exit 0
    ;;

pull)
    command -v supabase >/dev/null || {
        echo "Supabase CLI not found. brew install supabase/tap/supabase && supabase login" >&2
        exit 1
    }

    failed=""
    for fn in $(invoked); do
        printf 'downloading %s… ' "$fn"
        if supabase functions download "$fn" --project-ref "$PROJECT_REF" >/dev/null 2>&1; then
            echo "ok"
        else
            echo "FAILED"
            failed="$failed $fn"
        fi
    done

    echo
    if [ -n "$failed" ]; then
        echo "Could not download:$failed"
        echo "Usually means the function isn't deployed under that name."
    fi
    echo "Review 'git diff' before committing — a download overwrites local source with"
    echo "whatever production is running, which is the point, but check nothing local is lost."
    ;;

*)
    echo "usage: $(basename "$0") [check|pull]" >&2
    exit 2
    ;;
esac
