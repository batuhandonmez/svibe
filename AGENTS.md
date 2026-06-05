# Svibe Agent Guide

## Project

Svibe is an audio-first social app. The product should feel focused, ritualistic, and built around listening before speaking.

Core mechanics:
- New users can start as VIP, lucky unmuted users, or muted users.
- Muted users have a limited daily listening/speaking flow and must unlock speaking rights through the Golden Voice mechanic.
- Feed items are short voice posts.
- Users must listen for the first 3 seconds before swiping.
- Voice posts are capped at 30 seconds.
- Sending a voice post should eventually support the "cast" ritual through phone motion.

## Current Stack

Backend:
- Python/FastAPI
- Uvicorn
- SQLAlchemy with Supabase PostgreSQL
- Planned AWS S3 media storage through Boto3
- Current backend layout: `backend/main.py`, `backend/core/`, `backend/models/`, `backend/routers/`, `backend/schemas/`, `backend/services/`

Mobile frontend, when added:
- Flutter
- Riverpod for state management
- Hive for local storage
- Feature-first layout such as `features/auth`, `features/feed`, `features/profile`
- Light and dark mode support
- Frosted glass profile image treatment where relevant

## Working Style

- Be direct and practical. Avoid long philosophical explanations.
- Prefer clean, modular code that follows the existing project layout.
- Keep changes scoped to the requested feature or bug.
- Do not move to a new implementation step until the current step is complete enough to verify.
- If a request contains a logic flaw, security risk, or exposed secret risk, warn before implementing the risky part.
- Never expose `.env` values, AWS keys, database URLs, access tokens, or other secrets.
- Do not edit generated files such as `__pycache__` or virtual environment files under `backend/venv/`.

## Backend Conventions

- Put API route modules under `backend/routers/`.
- Put SQLAlchemy models under `backend/models/`.
- Put request/response Pydantic schemas under `backend/schemas/`.
- Put reusable business logic and external-service code under `backend/services/`.
- Put configuration and database setup under `backend/core/`.
- Keep imports consistent with the existing app style.
- Use dependency-injected database sessions through `get_db()` for request handlers.

## Verification

For backend work, verify with the narrowest useful checks available.

Common local commands:

```powershell
cd backend
.\venv\Scripts\python.exe -m uvicorn main:app --reload
```

When adding behavior:
- Add or update tests when the project has a test setup or when the change is risky.
- At minimum, import the touched modules or start the FastAPI app when practical.
- If a browser-visible flow exists, use the in-app browser to verify the rendered behavior.

## Product Docs

Use these files as product context:
- `product_flow.md` for onboarding, feed, Golden Voice, and cast mechanics.
- `database.md` for intended PostgreSQL tables.
- `architecture.md` for planned stack and folder structure.
- `checklist.md` for MVP phase status.
- `ai_rules.md` for user working preferences.

If these docs conflict with actual code, inspect the code first and call out the mismatch before changing behavior.
