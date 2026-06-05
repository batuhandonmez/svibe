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
GET /users/{user_id}
```

`POST /users` applies the onboarding logic:
- VIP users start unmuted with a higher daily vibe limit.
- A lucky percentage of regular users start unmuted.
- Other regular users start muted.

`GET /users/me/status` requires a bearer token. It returns whether the current
user is muted, how many daily vibe uploads remain, the user's daily limit, the
next reset time, and whether uploading is currently allowed. If the reset time
has passed, the backend refreshes the user's daily count before responding.

### Vibes

```http
POST /vibes
GET /vibes
DELETE /vibes/{vibe_id}
POST /vibes/{vibe_id}/listen/start
POST /vibes/{vibe_id}/swipe-right
```

All vibe endpoints require:

```http
Authorization: Bearer <access_token>
```

`POST /vibes` accepts multipart form data:
- `duration`
- `is_golden_voice`
- `audio`

Rules:
- muted users cannot upload
- duration must be 1-30 seconds
- daily vibe count must be greater than 0
- successful upload decrements daily vibe count
- daily vibe counts are restored automatically after the user's reset time
- audio is uploaded to S3 and the DB stores the private object URL
- API responses return a temporary presigned playback URL

`GET /vibes` returns active vibes from other users. It does not include the
authenticated user's own vibes. Feed items also include the owner's `username`,
`profile_picture_url`, and the current user's listen/swipe state:
- `listen_started_at`
- `can_swipe_at`
- `can_swipe_now`

`POST /vibes/{vibe_id}/listen/start` records when the authenticated user starts
listening to a vibe. Users cannot start listening to their own vibes.

`DELETE /vibes/{vibe_id}` lets the owner delete their own vibe. The backend
removes related listen records, deletes the DB row, and then best-effort deletes
the S3 audio object.

`POST /vibes/{vibe_id}/swipe-right` unlocks a muted user only when the swiped vibe is a Golden Voice.
It also requires a bearer token and applies the unlock to the authenticated user.
Users cannot swipe right on their own vibes.
Users must start listening and wait at least 3 seconds before swiping.
