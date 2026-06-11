-- Svibe Supabase security/performance preparation indexes.
-- Safe to run multiple times.

create index if not exists idx_users_is_private
on public.users (is_private);

create index if not exists idx_users_message_privacy
on public.users (message_privacy);

create index if not exists idx_vibes_user_id
on public.vibes (user_id);

create index if not exists idx_vibes_expires_at
on public.vibes (expires_at);

create index if not exists idx_vibes_discovery
on public.vibes (expires_at, swipe_right_count);

create index if not exists idx_vibe_listens_user_id
on public.vibe_listens (user_id);

create index if not exists idx_vibe_listens_vibe_id
on public.vibe_listens (vibe_id);

create index if not exists idx_vibe_swipes_user_id
on public.vibe_swipes (user_id);

create index if not exists idx_vibe_swipes_vibe_id
on public.vibe_swipes (vibe_id);

create index if not exists idx_follows_follower_id
on public.follows (follower_id);

create index if not exists idx_follows_following_id
on public.follows (following_id);

create index if not exists idx_follows_status
on public.follows (status);

create index if not exists idx_dm_threads_user_low_id
on public.dm_threads (user_low_id);

create index if not exists idx_dm_threads_user_high_id
on public.dm_threads (user_high_id);

create index if not exists idx_dm_messages_thread_id
on public.dm_messages (thread_id);

create index if not exists idx_dm_messages_sender_id
on public.dm_messages (sender_id);

create index if not exists idx_dm_messages_created_at
on public.dm_messages (created_at);
