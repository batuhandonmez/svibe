-- Svibe Supabase Data API hardening.
--
-- Flutter currently talks to the FastAPI backend, not directly to Supabase
-- table endpoints. These revokes reduce exposure from Supabase Data API roles
-- while the project keeps using a trusted server-side PostgreSQL connection.
--
-- This does not replace proper RLS. RLS policies are still needed before any
-- browser/mobile client receives a Supabase publishable key for direct table
-- access.

revoke all privileges on table
  public.users,
  public.vibes,
  public.vibe_listens,
  public.vibe_swipes,
  public.follows,
  public.dm_threads,
  public.dm_messages
from anon, authenticated;
