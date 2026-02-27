-- ============================================================
-- Group Chats: tables, RLS policies, and RPC function
-- ============================================================

-- 1. group_chats
create table if not exists public.group_chats (
    id          uuid primary key default gen_random_uuid(),
    name        text not null,
    created_by  uuid not null references public.users(id) on delete cascade,
    game_id     uuid references public.games(id) on delete set null,
    avatar_url  text,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);

create index idx_group_chats_game_id on public.group_chats(game_id) where game_id is not null;

-- 2. group_chat_members
create table if not exists public.group_chat_members (
    id              uuid primary key default gen_random_uuid(),
    group_chat_id   uuid not null references public.group_chats(id) on delete cascade,
    user_id         uuid not null references public.users(id) on delete cascade,
    role            text not null default 'member' check (role in ('admin', 'member')),
    joined_at       timestamptz not null default now(),
    unique (group_chat_id, user_id)
);

create index idx_group_chat_members_user on public.group_chat_members(user_id);
create index idx_group_chat_members_chat on public.group_chat_members(group_chat_id);

-- 3. group_chat_messages
create table if not exists public.group_chat_messages (
    id              uuid primary key default gen_random_uuid(),
    group_chat_id   uuid not null references public.group_chats(id) on delete cascade,
    user_id         uuid not null references public.users(id) on delete cascade,
    content         text not null,
    message_type    text not null default 'text' check (message_type in ('text', 'session_share', 'system')),
    shared_game_id  uuid references public.games(id) on delete set null,
    created_at      timestamptz not null default now()
);

create index idx_group_chat_messages_chat on public.group_chat_messages(group_chat_id, created_at desc);

-- ============================================================
-- RLS Policies
-- ============================================================

alter table public.group_chats enable row level security;
alter table public.group_chat_members enable row level security;
alter table public.group_chat_messages enable row level security;

-- group_chats: members can read their group chats
create policy "Members can view their group chats"
    on public.group_chats for select
    using (
        exists (
            select 1 from public.group_chat_members
            where group_chat_members.group_chat_id = group_chats.id
              and group_chat_members.user_id = auth.uid()
        )
    );

-- group_chats: creator/admin can update
create policy "Admin can update group chat"
    on public.group_chats for update
    using (
        exists (
            select 1 from public.group_chat_members
            where group_chat_members.group_chat_id = group_chats.id
              and group_chat_members.user_id = auth.uid()
              and group_chat_members.role = 'admin'
        )
    );

-- group_chats: creator/admin can delete (non-session-linked only)
create policy "Admin can delete group chat"
    on public.group_chats for delete
    using (
        game_id is null
        and exists (
            select 1 from public.group_chat_members
            where group_chat_members.group_chat_id = group_chats.id
              and group_chat_members.user_id = auth.uid()
              and group_chat_members.role = 'admin'
        )
    );

-- group_chat_members: members can view members of their chats
create policy "Members can view chat members"
    on public.group_chat_members for select
    using (
        exists (
            select 1 from public.group_chat_members as self_member
            where self_member.group_chat_id = group_chat_members.group_chat_id
              and self_member.user_id = auth.uid()
        )
    );

-- group_chat_members: admins can insert new members
create policy "Admin can add members"
    on public.group_chat_members for insert
    with check (
        exists (
            select 1 from public.group_chat_members as admin_check
            where admin_check.group_chat_id = group_chat_members.group_chat_id
              and admin_check.user_id = auth.uid()
              and admin_check.role = 'admin'
        )
    );

-- group_chat_members: users can delete themselves (leave)
create policy "Users can leave group chats"
    on public.group_chat_members for delete
    using (user_id = auth.uid());

-- group_chat_members: admins can remove members
create policy "Admin can remove members"
    on public.group_chat_members for delete
    using (
        exists (
            select 1 from public.group_chat_members as admin_check
            where admin_check.group_chat_id = group_chat_members.group_chat_id
              and admin_check.user_id = auth.uid()
              and admin_check.role = 'admin'
        )
    );

-- group_chat_messages: members can read messages
create policy "Members can read messages"
    on public.group_chat_messages for select
    using (
        exists (
            select 1 from public.group_chat_members
            where group_chat_members.group_chat_id = group_chat_messages.group_chat_id
              and group_chat_members.user_id = auth.uid()
        )
    );

-- group_chat_messages: members can insert messages
create policy "Members can send messages"
    on public.group_chat_messages for insert
    with check (
        user_id = auth.uid()
        and exists (
            select 1 from public.group_chat_members
            where group_chat_members.group_chat_id = group_chat_messages.group_chat_id
              and group_chat_members.user_id = auth.uid()
        )
    );

-- ============================================================
-- RPC: my_group_chats
-- Returns group chats for a user, ordered by last activity,
-- with member count, last message preview, and member avatar URLs.
-- ============================================================

create or replace function public.my_group_chats(p_user_id uuid)
returns table (
    id                          uuid,
    name                        text,
    created_by                  uuid,
    game_id                     uuid,
    avatar_url                  text,
    created_at                  timestamptz,
    updated_at                  timestamptz,
    member_count                int,
    last_message_content        text,
    last_message_sender_first_name text,
    last_message_at             timestamptz,
    member_avatar_urls          text[]
)
language sql
security definer
stable
as $$
    select
        gc.id,
        gc.name,
        gc.created_by,
        gc.game_id,
        gc.avatar_url,
        gc.created_at,
        gc.updated_at,
        (select count(*)::int from public.group_chat_members m where m.group_chat_id = gc.id) as member_count,
        lm.content as last_message_content,
        lm.sender_first_name as last_message_sender_first_name,
        lm.created_at as last_message_at,
        (
            select array_agg(u.avatar_url)
            from (
                select usr.avatar_url
                from public.group_chat_members mem
                join public.users usr on usr.id = mem.user_id
                where mem.group_chat_id = gc.id
                  and usr.avatar_url is not null
                order by mem.joined_at
                limit 4
            ) u
        ) as member_avatar_urls
    from public.group_chats gc
    join public.group_chat_members gcm on gcm.group_chat_id = gc.id and gcm.user_id = p_user_id
    left join lateral (
        select
            msg.content,
            msg.created_at,
            usr.first_name as sender_first_name
        from public.group_chat_messages msg
        join public.users usr on usr.id = msg.user_id
        where msg.group_chat_id = gc.id
        order by msg.created_at desc
        limit 1
    ) lm on true
    order by coalesce(lm.created_at, gc.created_at) desc;
$$;
