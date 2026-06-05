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

## Notes

- Do not commit `backend/.env`.
- The AWS key used during local development should be rotated before serious
  production work.
- Windows desktop Flutter builds require a complete Visual Studio C++ toolchain.
- Android builds in paths with non-ASCII characters may need
  `android.overridePathCheck=true`, already set in this project.
