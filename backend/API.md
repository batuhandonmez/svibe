# Svibe Backend API

## Environment

Required:

```env
DATABASE_URL=postgresql://...
```

Required for real S3 uploads:

```env
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=eu-central-1
AWS_S3_BUCKET_NAME=svibe-audio-dev
AWS_S3_AUDIO_PREFIX=vibes
MAX_AUDIO_FILE_SIZE_MB=20
```

Do not commit `.env`.

## Run

```powershell
cd backend
.\venv\Scripts\python.exe -m pip install -r requirements.txt
.\venv\Scripts\python.exe -m uvicorn main:app --reload
```

Swagger UI:

```text
http://127.0.0.1:8000/docs
```

## Endpoints

### Health

```http
GET /health
```

### Auth

```http
POST /auth/register
POST /auth/login
GET /auth/me
```

`POST /auth/register` creates a user, applies onboarding logic, hashes the
password, and returns a bearer token.

`POST /auth/login` returns a bearer token for an existing password-backed user.

`GET /auth/me` requires:

```http
Authorization: Bearer <access_token>
```

### Users

```http
POST /users
GET /users/me/status
PATCH /users/me
POST /users/me/photo
GET /users/{user_id}
POST /users/{user_id}/follow
POST /users/{user_id}/follow/accept
```

`POST /users` applies the onboarding logic:
- VIP users start unmuted with a higher daily vibe limit.
- A lucky percentage of regular users start unmuted.
- Other regular users start muted.

`GET /users/me/status` requires a bearer token. It returns whether the current
user is muted, how many daily vibe uploads remain, the user's daily limit, the
next reset time, and whether uploading is currently allowed. If the reset time
has passed, the backend refreshes the user's daily count before responding.
It also returns account privacy and DM privacy.

`PATCH /users/me` updates `display_name`, `bio`, `is_private`, and
`message_privacy`.

`POST /users/me/photo` accepts multipart `photo` upload and stores the profile
image under the S3 `profiles/` prefix, or under local media in development when
S3 is not configured. Profile photos are not set by URL during account creation.

Private accounts receive pending follow requests. Public accounts are followed
immediately.

### DM

```http
GET /dm/threads
POST /dm/threads
GET /dm/threads/{thread_id}/messages
POST /dm/threads/{thread_id}/messages
POST /dm/threads/{thread_id}/messages/audio
```

`POST /dm/threads` accepts `{"user_id": "<target-user-id>"}`. The target user's
`message_privacy` decides whether the thread can be created:
- `everyone`: anyone can start a DM
- `followers`: only accepted followers can start a DM
- `off`: new DMs are blocked

`POST /dm/threads/{thread_id}/messages` accepts text messages.
`POST /dm/threads/{thread_id}/messages/audio` accepts multipart `audio` plus a
`duration` field from 1 to 30 seconds and stores the voice DM under the S3
`dm/` prefix.

### Vibes

```http
POST /vibes
GET /vibes
GET /vibes/discover/next
DELETE /vibes/{vibe_id}
POST /vibes/{vibe_id}/listen/start
POST /vibes/{vibe_id}/swipe
POST /vibes/{vibe_id}/swipe-right
```

All vibe endpoints require:

```http
Authorization: Bearer <access_token>
```

`POST /vibes` accepts multipart form data:
- `duration`
- `audio`

Rules:
- muted users cannot upload
- duration must be 1-30 seconds
- daily vibe count must be greater than 0
- successful upload decrements daily vibe count
- Golden Voice is assigned by the backend only
- daily vibe counts are restored automatically after the user's reset time
- audio is uploaded to S3 and the DB stores the private object URL
- API responses return a temporary presigned playback URL

`GET /vibes/discover/next` returns one discoverable public vibe. It excludes the
authenticated user's own vibes, private accounts, expired vibes, and vibes the
user has already liked/disliked. Selection is random with a light popularity
weight.

`GET /vibes` returns active public vibes from other users. Feed items also
include the owner's `username`, `display_name`, `profile_picture_url`, and the
current user's listen/swipe state:
- `listen_started_at`
- `can_swipe_at`
- `can_swipe_now`

`POST /vibes/{vibe_id}/listen/start` records when the authenticated user starts
listening to a vibe. Users cannot start listening to their own vibes.

`DELETE /vibes/{vibe_id}` lets the owner delete their own vibe. The backend
removes related listen records, deletes the DB row, and then best-effort deletes
the S3 audio object.

`POST /vibes/{vibe_id}/swipe` accepts JSON:

```json
{"direction": "like", "golden_unlock_confirmed": false}
```

`direction` can be `like` or `dislike`. Likes increment
`swipe_right_count`; dislikes simply remove the vibe from the user's future
discover feed.

If a muted user likes a Golden Voice without `golden_unlock_confirmed`, the API
returns `golden_voice_unlock_pending=true` so the client can show the
"Shake your vibe" ritual. Calling again with `golden_unlock_confirmed=true`
grants speaking rights.

`POST /vibes/{vibe_id}/swipe-right` remains as a compatibility endpoint for old
clients and behaves like a confirmed like.

Users cannot swipe on their own vibes.
Users must start listening and wait at least 3 seconds before swiping.
