-- Fallout from 20260731_invite_approval.sql.
--
-- That migration gave game_participants two more foreign keys into users — invited_by and
-- approved_by — alongside the user_id it already had. PostgREST resolves `users(…)` by finding
-- the one relationship between the two tables, so from the moment those columns existed there
-- were three, and every embed that had worked for months started returning:
--
--     Could not embed because more than one relationship was found for
--     'game_participants' and 'users'
--
-- which surfaced in the app as a session showing "1/4 spots filled" above "Players (0)". The
-- roster query was failing outright; the count came from games.spots_filled and so kept working,
-- which is what made it look like a display bug rather than a broken query.
--
-- The fix on the client is to name which relationship it means: `users!<constraint>(…)`. That
-- puts a constraint name in application code, so the schema should be the thing that guarantees
-- it rather than leaving it to whatever the table happened to be created with — the original
-- game_participants definition isn't in this repo, so its generated name is not something to
-- take on faith.
--
-- Renaming a constraint touches no data and no index.

do $$
declare
    v_name text;
begin
    select con.conname
      into v_name
      from pg_constraint con
      join pg_class      rel on rel.oid = con.conrelid
      join pg_namespace  nsp on nsp.oid = rel.relnamespace
      join pg_attribute  att on att.attrelid = rel.oid
                            and att.attnum = con.conkey[1]
     where nsp.nspname = 'public'
       and rel.relname = 'game_participants'
       and con.contype = 'f'
       and array_length(con.conkey, 1) = 1
       and att.attname = 'user_id';

    if v_name is null then
        raise exception
            'No foreign key found on public.game_participants(user_id) — schema is not what this migration expects';
    end if;

    if v_name <> 'game_participants_user_id_fkey' then
        execute format(
            'alter table public.game_participants rename constraint %I to game_participants_user_id_fkey',
            v_name
        );
        raise notice 'Renamed % to game_participants_user_id_fkey', v_name;
    end if;
end $$;

-- Same treatment for the two columns 20260731 added, so all three names are predictable and a
-- future embed can point at any of them.
do $$
declare
    r record;
begin
    for r in
        select con.conname, att.attname
          from pg_constraint con
          join pg_class      rel on rel.oid = con.conrelid
          join pg_namespace  nsp on nsp.oid = rel.relnamespace
          join pg_attribute  att on att.attrelid = rel.oid
                                and att.attnum = con.conkey[1]
         where nsp.nspname = 'public'
           and rel.relname = 'game_participants'
           and con.contype = 'f'
           and array_length(con.conkey, 1) = 1
           and att.attname in ('invited_by', 'approved_by')
    loop
        if r.conname <> 'game_participants_' || r.attname || '_fkey' then
            execute format(
                'alter table public.game_participants rename constraint %I to %I',
                r.conname,
                'game_participants_' || r.attname || '_fkey'
            );
        end if;
    end loop;
end $$;
