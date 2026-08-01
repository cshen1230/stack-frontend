#!/usr/bin/env bash
#
# Keeps supabase/functions/ honest against what is actually deployed.
#
# The list of functions is derived from the Swift source every run rather than hardcoded, so
# it can't go stale: whatever the app calls is what this checks for and pulls.
#
#   ./supabase/functions/sync.sh check    # is every called function present here? (default)
#   ./supabase/functions/sync.sh diff      # does this source match what is RUNNING?
#   ./supabase/functions/sync.sh pull      # overwrite local source with production's
#   ./supabase/functions/sync.sh deploy [fn…]  # push local source to production
#
# `check` is cheap and offline, but it only proves a directory exists. It cannot tell you
# whether the code in it is the code being executed — editing a function here and committing
# leaves `check` perfectly happy while production runs the old build. `diff` is the one that
# answers that, and it is the one to run before believing anything about server behaviour.
#
# Everything but `check` needs the Supabase CLI and a login:
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

require_cli() {
    command -v supabase >/dev/null || {
        echo "Supabase CLI not found. brew install supabase/tap/supabase && supabase login" >&2
        exit 1
    }
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

    if [ -z "$gap" ]; then
        echo
        echo "Every function the app calls has source here."
        echo "This does NOT mean the source matches what is running — run 'sync.sh diff' for that."
    fi
    [ -n "$gap" ] && exit 1
    exit 0
    ;;

diff)
    require_cli

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT

    targets="$(present)"
    drifted=""
    unreachable=""

    for fn in $targets; do
        if ! (cd "$tmp" && supabase functions download "$fn" --project-ref "$PROJECT_REF" >/dev/null 2>&1); then
            unreachable="$unreachable $fn"
            continue
        fi
        if ! diff -rq "$FUNCTIONS_DIR/$fn" "$tmp/supabase/functions/$fn" >/dev/null 2>&1; then
            drifted="$drifted $fn"
        fi
    done

    if [ -n "$drifted" ]; then
        echo "DRIFTED — this repo and production disagree:"
        for fn in $drifted; do
            echo "  - $fn"
            diff -ru "$tmp/supabase/functions/$fn" "$FUNCTIONS_DIR/$fn" \
                | sed 's/^/      /' | head -40
        done
        echo
        echo "Left is production, right is this repo. If the repo is the one you want running,"
        echo "'sync.sh deploy <fn>'. If production is, 'sync.sh pull'."
    fi

    if [ -n "$unreachable" ]; then
        echo
        echo "Could not download (not deployed under that name, or no access):$unreachable"
    fi

    if [ -z "$drifted" ] && [ -z "$unreachable" ]; then
        echo "Every checked-in function matches what is deployed."
    fi

    [ -n "$drifted" ] && exit 1
    exit 0
    ;;

deploy)
    require_cli
    shift || true

    targets="${*:-}"
    [ -z "$targets" ] && targets="$(present)"

    failed=""
    for fn in $targets; do
        printf 'deploying %s… ' "$fn"
        if supabase functions deploy "$fn" --project-ref "$PROJECT_REF" >/dev/null 2>&1; then
            echo "ok"
        else
            echo "FAILED"
            failed="$failed $fn"
        fi
    done

    echo
    if [ -n "$failed" ]; then
        echo "Could not deploy:$failed"
        exit 1
    fi
    echo "Deployed. Run 'sync.sh diff' to confirm production now matches this repo."
    ;;

pull)
    require_cli

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
    echo "usage: $(basename "$0") [check|diff|pull|deploy [fn…]]" >&2
    exit 2
    ;;
esac
