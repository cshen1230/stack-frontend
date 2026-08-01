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

`check` is offline and only proves a directory exists — it cannot tell you the code in it is
the code being executed. **`sync.sh diff` is the one that answers that**, and it's the one to
run before believing a change took effect. `sync.sh deploy [fn…]` pushes local source up;
`sync.sh pull` overwrites local source with production's. All but `check` need the Supabase
CLI and `supabase login`.

There is no CI that deploys these. Committing an edge function change to git does not ship it —
until `sync.sh deploy` runs, the app still hits the old build. Equally, editing a function in
the Supabase dashboard without pulling it back here re-opens the gap.
