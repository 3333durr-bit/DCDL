# DCDL — Geometry Dash Demon List

React + TypeScript frontend for the DCDL community demon list.

## Development

```bash
npm install
npm run dev
```

## Current status

This is the first visual frontend prototype. The list currently uses local demo data and browser state only.

### Planned integrations
- Supabase Auth (one account per player; unique GD username)
- Supabase Postgres with row-level security
- Supabase Storage / external video hosting for proof uploads
- Admin-only moderation and placement publishing
- Realtime community chat and direct messages

**Security note:** the Durranas admin role must be assigned and enforced server-side (for example with a protected profile/role table and RLS policies), never trusted from a client-side username check alone.
