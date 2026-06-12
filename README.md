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

Smoke check against a running local backend:

```powershell
.\venv\Scripts\python.exe ..\scripts\smoke_backend.py --base-url http://127.0.0.1:8000
```

If the demo account has not been seeded, use the public register flow instead:

```powershell
.\venv\Scripts\python.exe ..\scripts\smoke_backend.py --base-url http://127.0.0.1:8000 --mode register
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

Run on a real phone connected to the same Wi-Fi as this computer:

```powershell
# Find the computer LAN IPv4 address, usually something like 192.168.x.x
Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
  $_.IPAddress -notlike '127.*' -and $_.PrefixOrigin -ne 'WellKnown'
} | Select-Object IPAddress,InterfaceAlias

cd mobile
flutter run --dart-define API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:8000
```

Keep the backend running on `0.0.0.0` for physical-device testing:

```powershell
cd backend
.\venv\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000
```

Development builds allow local HTTP API traffic for `http://YOUR_COMPUTER_LAN_IP:8000`.
On iOS, accept the local network prompt if it appears.

## Local Web Demo

For an iPhone Safari demo, keep the computer and iPhone on the same Wi-Fi, then
use the computer LAN IP in every command below. The example IP is
`192.168.1.102`; replace it with your current value.

```powershell
# Find the computer LAN IPv4 address
Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
  $_.IPAddress -notlike '127.*' -and $_.PrefixOrigin -ne 'WellKnown'
} | Select-Object IPAddress,InterfaceAlias
```

Start the backend so the iPhone can reach it:

```powershell
cd backend
.\venv\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000
```

Seed local demo users, public discovery vibes, and DM content without using
AWS/S3. Use `demo_user` for the one-tap demo login, or replace it with your
own account username:

```powershell
backend\venv\Scripts\python.exe scripts\seed_local_demo.py --username demo_user --base-url http://YOUR_COMPUTER_LAN_IP:8000
```

Run the Flutter web demo for Safari on the iPhone:

```powershell
cd mobile
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8096 --dart-define API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:8000
```

Open this on the iPhone:

```text
http://YOUR_COMPUTER_LAN_IP:8096
```

Demo login:

```text
demo_user / demo12345
```

In the web/mobile login screen, the demo credential card fills and submits this
account with one tap after `scripts\seed_demo.py` has been run. For a newly
created account, use `scripts\seed_local_demo.py --username <your_username>` to
add local demo feed and DM data.

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
