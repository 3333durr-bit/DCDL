# DCDL — Geometry Dash Demon List

React + TypeScript + Vite frontend with a Supabase backend foundation.

## Run locally

```bash
npm install
cp .env.example .env.local
npm run dev
```

Fill in `.env.local` with the Supabase project URL and publishable/anon key from your Supabase project settings. Never put a Supabase `service_role` key in frontend code or commit credentials.

## Supabase setup

1. Create a Supabase project.
2. Open **SQL Editor** and run `supabase/migrations/0001_initial_schema.sql`.
3. Copy the project URL and publishable/anon key into `.env.local`.
4. Register the owner account, verify its email, then locate its UUID in Authentication → Users.
5. In SQL Editor, promote only that exact auth UUID:
   `update public.profiles set role = 'admin' where id = 'YOUR_AUTH_USER_UUID';`

The admin role is deliberately not assigned from a user-editable GD username. RLS policies enforce admin-only moderation on the server.

## Current implementation status

- UI: first visual React prototype with local demo data.
- Backend foundation: Supabase client, schema, auth profile trigger, RLS policies, voting, submissions, completion review, points, fixed chat channels and DMs.
- Not yet wired into every UI flow: live sign-in/sign-up, realtime chat, file upload and admin review screens need the Supabase project credentials and subsequent integration work.
- Voice chat requires a separate real-time audio provider; the database channel alone is not voice functionality.

## Development

`npm run build` checks TypeScript and creates the production build.
