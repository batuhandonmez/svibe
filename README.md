# Svibe

Svibe is an audio-first social app MVP. The backend is a FastAPI service backed
by Supabase/PostgreSQL and AWS S3. The mobile app is a Flutter client with auth,
feed, profile, and DM screens.

## Backend

```powershell
cd backend
.\venv\Scripts\python.exe -m pip install -r requirements.txt
.\venv\Scripts\python.exe -m uvicorn main:app --reload
```

Swagger:

```text
http://127.0.0.1:8000/docs
```

Tests:

```powershell
cd backend
.\venv\Scripts\python.exe -m pytest -q
```

## Mobile

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
```

Run against local backend:

```powershell
cd mobile
flutter run --dart-define API_BASE_URL=http://127.0.0.1:8000
```

Android emulator uses `http://10.0.2.2:8000` by default when
`API_BASE_URL` is not supplied.

## Local Web Demo

Seed demo users, public discovery vibes, profile vibes, and DM content:

```powershell
backend\venv\Scripts\python.exe scripts\seed_demo.py
```

Build a web demo against the local API:

```powershell
cd mobile
flutter build web --dart-define API_BASE_URL=http://127.0.0.1:8002 --output C:\svibe_web_demo
```

Serve the generated web build:

```powershell
cd C:\svibe_web_demo
python -m http.server 8093
```

Demo login:

```text
demo_user / demo12345
```

In the web/mobile login screen, the demo credential card fills and submits this
account with one tap after `scripts\seed_demo.py` has been run.

Figma redesign file:

```text
https://www.figma.com/design/DRmbMcSTxxrcDvSLWM7ZG3/Svibe-Mobile-Redesign
```

## Notes

- Do not commit `backend/.env`.
- Set `ENVIRONMENT=production` only with a non-default `JWT_SECRET_KEY` of at
  least 32 characters; the API refuses to start otherwise.
- The AWS key used during local development should be rotated before serious
  production work.
- Windows desktop Flutter builds require a complete Visual Studio C++ toolchain.
- Android builds in paths with non-ASCII characters may need
  `android.overridePathCheck=true`, already set in this project.
- Supabase RLS is not applied yet. See `docs/SUPABASE_RLS_PLAN.md` before
  exposing tables directly to a mobile/web Supabase client.
