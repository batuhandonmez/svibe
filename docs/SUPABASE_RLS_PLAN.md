# Supabase RLS Plan

This project currently uses FastAPI with a direct PostgreSQL connection. The
Flutter app does not talk to Supabase tables directly yet. Even so, the public
schema should be prepared for Row Level Security before any browser/mobile
client receives a Supabase publishable key.

Supabase guidance: RLS must be enabled for tables in exposed schemas such as
`public`, and policies should specify roles such as `authenticated`.

Relevant docs:
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/storage/security/access-control

## Current Risk

The current Supabase advisor state reported RLS disabled on these public tables:

- `public.users`
- `public.vibes`
- `public.vibe_listens`
- `public.vibe_swipes`
- `public.follows`
- `public.dm_threads`
- `public.dm_messages`

Do not enable RLS blindly in production without policy tests. Enabling RLS with
no policies can make data inaccessible through the Supabase Data API. The
FastAPI service may keep working through its database connection, but future
Supabase client access will be blocked until policies are correct.

## Intended Access Model

- Users can read public profile fields for non-private accounts.
- Users can read their own full profile.
- Users can update only their own profile fields.
- Public vibes from non-private accounts can be discovered.
- Private users' vibes should not appear in discovery.
- Users can create, update, and delete only their own vibes.
- Users can create one swipe/listen row for their own user id.
- Users can read their own swipe/listen history.
- Follow requests are visible to requester and target.
- DM threads/messages are visible only to their participants.

## Staged Rollout

1. Keep FastAPI as the only writer for now.
2. Add indexes used by policy filters before enabling policies:
   - `users.id`
   - `vibes.user_id`
   - `vibe_swipes.user_id`
   - `vibe_swipes.vibe_id`
   - `vibe_listens.user_id`
   - `vibe_listens.vibe_id`
   - `follows.follower_id`
   - `follows.following_id`
   - `dm_threads.participant_a_id`
   - `dm_threads.participant_b_id`
   - `dm_messages.thread_id`
   - `dm_messages.sender_id`
3. Create policies in a development branch or disposable project.
4. Run backend tests and a real login/discover/swipe/DM smoke test.
5. Enable RLS in production only after the policy behavior is proven.

## Policy Skeleton

This is a starting point, not a migration to apply as-is.

```sql
alter table public.users enable row level security;
alter table public.vibes enable row level security;
alter table public.vibe_listens enable row level security;
alter table public.vibe_swipes enable row level security;
alter table public.follows enable row level security;
alter table public.dm_threads enable row level security;
alter table public.dm_messages enable row level security;

create policy "Users can read their own profile"
on public.users
for select
to authenticated
using ((select auth.uid()) = id);

create policy "Public profiles are visible"
on public.users
for select
to authenticated
using (is_private = false);

create policy "Users can update their own profile"
on public.users
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy "Users can read discoverable vibes"
on public.vibes
for select
to authenticated
using (
  exists (
    select 1
    from public.users u
    where u.id = vibes.user_id
      and u.is_private = false
  )
);

create policy "Users can manage their own vibes"
on public.vibes
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users can read their own swipes"
on public.vibe_swipes
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can create their own swipes"
on public.vibe_swipes
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users can read their own listens"
on public.vibe_listens
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can create their own listens"
on public.vibe_listens
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "Follow rows visible to participants"
on public.follows
for select
to authenticated
using (
  (select auth.uid()) = follower_id
  or (select auth.uid()) = following_id
);

create policy "Users can create their own follow requests"
on public.follows
for insert
to authenticated
with check ((select auth.uid()) = follower_id);

create policy "DM threads visible to participants"
on public.dm_threads
for select
to authenticated
using (
  (select auth.uid()) = participant_a_id
  or (select auth.uid()) = participant_b_id
);

create policy "DM messages visible to thread participants"
on public.dm_messages
for select
to authenticated
using (
  exists (
    select 1
    from public.dm_threads t
    where t.id = dm_messages.thread_id
      and (
        (select auth.uid()) = t.participant_a_id
        or (select auth.uid()) = t.participant_b_id
      )
  )
);

create policy "DM participants can send messages"
on public.dm_messages
for insert
to authenticated
with check (
  (select auth.uid()) = sender_id
  and exists (
    select 1
    from public.dm_threads t
    where t.id = dm_messages.thread_id
      and (
        (select auth.uid()) = t.participant_a_id
        or (select auth.uid()) = t.participant_b_id
      )
  )
);
```

## Open Decisions

- Whether Flutter will ever use Supabase Data API directly or always go through
  FastAPI.
- Whether `users.id` should eventually map to Supabase Auth `auth.users.id`.
- Whether S3 remains the media store or profile images move to Supabase Storage.
- Whether DM needs realtime subscriptions in V1 or can remain polling/API based.
