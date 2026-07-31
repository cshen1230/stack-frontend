# StackPickleball

## Git

Work directly on `main` and push there — commit and push to `main` for every change.
Do not create feature branches, and do not open pull requests unless asked.
(The default branch is named `main`; there is no `master`.)

## Edge functions

`supabase/functions/` must mirror what is deployed. When it doesn't, server behaviour can't
be read or changed from source, and errors surface with no explanation in the codebase — a
403 on create-game and a "DUPR verification required" rejection both came from functions
whose deployed source was never checked in.

Run `./supabase/functions/sync.sh check` before reasoning about server behaviour; it derives
the expected list from `functions.invoke(…)` calls in the Swift source, so it can't go stale.
`sync.sh pull` downloads the deployed source (needs the Supabase CLI and `supabase login`).

Editing a function in the Supabase dashboard without pulling it back here re-opens the gap.
