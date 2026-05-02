# CLAUDE.md

Guidance for future Claude Code sessions working in this repo. **Read this
before proposing or building anything.**

---

## ⚡ RESUME HERE — work in progress

When this session paused, the Top 10 sub-app was **shipped and live**, but a
schema rethink was agreed and **not yet implemented**. Pick up from the
"Next session: schema rethink" section near the bottom.

Live URLs (GitHub Pages, served from `main`):

- App home/report: `https://cathcoach4u.github.io/yourstrengthscoach/top10/`
- Entry: `https://cathcoach4u.github.io/yourstrengthscoach/top10/enter.html`
- Login: `https://cathcoach4u.github.io/yourstrengthscoach/top10/login.html`

Supabase redirect-URL allowlist must include:

```
https://cathcoach4u.github.io/yourstrengthscoach/top10/reset-password.html
```

---

## What this repo is

`yourstrengthscoach` is one of the **Coach4U** apps. It is a **static site
hosted on GitHub Pages** — plain HTML / CSS / vanilla JS modules, with
Supabase used directly from the browser. There is **no build step, no Node
toolchain, no framework** (no Next.js, no Vite, no React). Do not introduce
one without explicit user instruction.

The site is deployed from `main` (GitHub Pages serves from there). Sub-apps
live under their own folders (e.g. `top10/`) and are served at `/<folder>/`.

## Stack & non-negotiables

- **Static HTML pages**, one folder per sub-app.
- **Supabase JS v2 via ESM CDN**, imported inline in every HTML page:
  ```html
  <script type="module">
    import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm';
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  </script>
  ```
  GitHub Pages does not reliably load external `.js` modules — **always
  initialise Supabase inline** in each page. Do **not** import from a shared
  config file for auth/data operations.
- **Email + password auth only.** No magic links, no OTP, no OAuth.
- **Membership gating** on every authenticated page: redirect to
  `inactive.html` if `users.membership_status !== 'active'`.
- **Forgot-password redirect URL** must be built from `window.location.href`,
  not `window.location.origin`. Using `origin` drops the path and Supabase
  cannot match the entry in the redirect-URL allowlist.

## Supabase projects (two exist — read carefully)

This repo currently uses **Project A**. Project B exists and was
investigated as a possible single source of truth, but the conclusion was
to **stay on Project A** and **mirror Project B's schema convention** here.

| Role                     | URL                                                       | Anon key                                            |
| ------------------------ | --------------------------------------------------------- | --------------------------------------------------- |
| **Project A** (this app) | `https://eekefsuaefgpqmjdyniy.supabase.co`                | `sb_publishable_pcXHwQVMpvEojb4K3afEMw_RMvgZM-Y`    |
| Project B (other portal) | `https://uoixetfvboevjxlkfyqy.supabase.co`                | `sb_publishable_m3qgSGvWF0n2TePf6vhqMw_9obUvJEJ`    |

Anon keys are publishable and safe to commit. **Never** commit a service-role key.

### Shared `users` table (Project A)

```sql
create table public.users (
  id                uuid primary key references auth.users(id) on delete cascade,
  email             text not null,
  full_name         text,
  membership_status text not null default 'inactive',
  created_at        timestamptz default now()
);
```

Row-level security is enabled; users can read and update their own row only.

### Activating a member (Project A)

After a member signs up via Supabase Auth, mirror them into `public.users`:

```sql
INSERT INTO users (id, email, membership_status)
SELECT id, email, 'active'
FROM auth.users
WHERE LOWER(email) = LOWER('email@here.com');
```

## Repo layout

```
sql/                       Migrations — run in the Supabase SQL editor
  top10_setup.sql          (CURRENT) Relational catalog + per-user table.
                           Will be REPLACED — see "Next session" section.

top10/                     Top 10 Strengths sub-app (served at /top10/)
  css/style.css
  index.html               View top 10 + basic report
  enter.html               Enter / edit ranked top 10 with Name/Claim/Aim notes
  login.html
  forgot-password.html
  reset-password.html
  inactive.html

CLAUDE.md
README.md
```

When you add a new sub-app, follow the same pattern: own folder, own auth
pages, own `css/style.css`, inline Supabase init in every HTML page.

---

## Top 10 Strengths sub-app — what's deployed today

Tables live in **Project A** (`sql/top10_setup.sql`):

- `strengths_catalog` — all 34 Gallup CliftonStrengths themes (name, domain,
  sort_order). Read-only for authenticated users. Seeded on creation.
- `user_top_strengths` — one row per ranked strength (rank 1–10) per user,
  with `name_it` / `claim_it` / `aim_it` text columns. RLS scopes
  reads/writes to `auth.uid() = user_id`. Unique constraints on
  `(user_id, rank)` and `(user_id, strength_id)`.
- `user_top_strengths_view` — joined view used by the report.

> **Known issue from last session:** the SQL was run once but the **view
> creation step failed** due to copy-paste mangling (`<uts.id>` placeholder
> brackets). Whether the view actually exists in Project A is unclear.
> If the report page errors with
> `Could not find the table 'public.user_top_strengths_view' in the schema cache`,
> re-run the view block from `sql/top10_setup.sql` (or just re-run the whole
> file — it's idempotent). Use the **Raw** view on GitHub when copying SQL
> to avoid clipboard tools wrapping identifiers in `<...>`.

Save flow (`enter.html`): delete-all-then-insert the user's 10 rows in a
single batch. Simpler than juggling the two unique constraints on reorder.

No canned Gallup-authored content is shipped. Theme names and the four
domains are factual; per-strength descriptions and Name/Claim/Aim text are
captured per client in the entry form to avoid IP issues.

---

## ▶︎ NEXT SESSION: schema rethink (agreed, not yet implemented)

The user agreed to **simplify the schema to match Project B's convention**.
This work was paused before any code changes were made.

### Why we're changing it

- Project B has a `hub_strengths` table with `user_id`, `top_strengths`
  (jsonb array), `name_claim_aim` (jsonb), `strengths_report_url`,
  `insights`, `updated_at`. Empty but correctly shaped.
- We searched Project B for an existing **catalog of 34 themes** — none
  exists (no table has 34 rows). So the relational catalog approach in
  Project A is over-engineered: the 34 are immutable, hardcoding them in
  JS is the right call.
- Mirroring `hub_strengths`'s schema in Project A:
  - One table instead of two.
  - Matches naming convention used elsewhere in Project B.
  - If Project A and B ever consolidate, it's a literal table copy.

### The plan (what to actually do next session)

1. **New SQL file** `sql/top10_hub_setup.sql` that creates `public.hub_strengths`
   in Project A with this schema (matches Project B exactly):
   ```sql
   create table public.hub_strengths (
     id                   uuid primary key default gen_random_uuid(),
     user_id              uuid not null unique references auth.users(id) on delete cascade,
     top_strengths        jsonb,                 -- array of 10 names in rank order
     name_claim_aim       jsonb,                 -- object keyed by strength name
     strengths_report_url text,
     insights             text,
     updated_at           timestamptz not null default now()
   );
   alter table public.hub_strengths enable row level security;
   create policy "users access own hub_strengths"
     on public.hub_strengths for all
     using (auth.uid() = user_id) with check (auth.uid() = user_id);
   ```

2. **Drop the old objects** (they're empty so safe to drop):
   ```sql
   drop view  if exists public.user_top_strengths_view;
   drop table if exists public.user_top_strengths;
   drop table if exists public.strengths_catalog;
   ```
   Decide: leave the old `sql/top10_setup.sql` in place for history, or
   delete it. User leans toward deleting since it's no longer the truth.

3. **Hardcode the 34 catalog** as a JS constant in both `enter.html` and
   `index.html`. Shape:
   ```js
   const CATALOG = [
     { name: 'Achiever',          domain: 'Executing' },
     { name: 'Activator',         domain: 'Influencing' },
     // … all 34, alphabetical
   ];
   ```
   (Full list is in the seed block of `sql/top10_setup.sql` — copy from
   there.)

4. **Rewrite `enter.html` save flow:** upsert ONE row into `hub_strengths`
   for the current user.
   - `top_strengths` = array of 10 strength names in rank order
   - `name_claim_aim` = `{ "Achiever": { name: "...", claim: "...", aim: "..." }, ... }`
   - Use `supabase.from('hub_strengths').upsert({ user_id, top_strengths, name_claim_aim, updated_at: new Date().toISOString() }, { onConflict: 'user_id' })`

5. **Rewrite `index.html` report:** read the single row and render. Domain
   counts come from looking each name up in `CATALOG`.

6. **Keep auth + membership gating exactly as is** (`users.membership_status = 'active'`
   in Project A).

### Open questions still to confirm next session

- Does the user want `strengths_report_url` and `insights` columns
  surfaced in the entry/report UI, or just stored for parity with Project B?
  (Last preference: keep the columns, don't surface in UI yet.)
- Is the partial SQL run from last session leaving Project A in a half-good
  state (tables yes, view no)? Doing the rewrite makes this moot — the
  drops in step 2 clean up regardless.

---

## Conventions for new work

- **Don't add a build step.** If a task seems to need one, push back and ask
  before introducing tooling.
- **Don't replace inline Supabase init with a shared module** — it breaks on
  GitHub Pages.
- **Don't add canned Gallup descriptions** to seed data or hardcoded
  catalogs. Names + domains only.
- **SQL files are idempotent.** Use `create table if not exists`,
  `on conflict do nothing`, `drop policy if exists` so re-running is safe.
- **Match existing styling.** Brand color `#003366`, Tailwind-free, the
  variables and class names in `top10/css/style.css` are the reference.
- **Membership gating goes on every authenticated page** — copy the snippet
  from `top10/index.html` or `enter.html`.
- **When pasting SQL or code** anywhere with `<...>` warnings (errors
  showing literal `<colname>`), copy from GitHub's **Raw** view, not a
  rendered code block. Some clipboard/AI tools wrap identifiers in angle
  brackets.

## Branching & PRs

- Final code lives on `main` (GitHub Pages serves from there).
- The user has authorised pushing **directly to `main`** for this repo
  (confirmed in the last session). PRs are nice-to-have, not required.
- Use the GitHub MCP tools (`mcp__github__*`) for all GitHub interactions —
  no `gh` CLI available.

## Things to ask before doing

- "Build a new app" — confirm whether it belongs in this repo as a new
  `<name>/` folder or in a separate Coach4U repo.
- Anything that touches `auth`, the `users` table schema, or RLS policies
  shared across sub-apps.
- Adding new top-level dependencies, tooling, or a build pipeline.
- Switching projects (Project A ↔ Project B) — confirmed answer is
  **stay on Project A** for this repo, but check before changing.
