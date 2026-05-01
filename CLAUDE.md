# CLAUDE.md

Guidance for future Claude Code sessions working in this repo. Read this before
proposing or building anything.

## What this repo is

`yourstrengthscoach` is one of the **Coach4U** apps. It is a **static site
hosted on GitHub Pages** — plain HTML / CSS / vanilla JS modules, with
Supabase used directly from the browser. There is **no build step, no Node
toolchain, no framework** (no Next.js, no Vite, no React). Do not introduce
one without explicit user instruction.

The site is deployed from the default branch — final code lives on `main`.
Sub-apps live under their own folders (e.g. `top10/`) and are served at
`/<folder>/` paths.

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

## Supabase project

| Key         | Value                                                       |
| ----------- | ----------------------------------------------------------- |
| Project URL | `https://eekefsuaefgpqmjdyniy.supabase.co`                  |
| Anon key    | `sb_publishable_pcXHwQVMpvEojb4K3afEMw_RMvgZM-Y`            |

The anon key is publishable and safe to commit. Never commit a service-role
key.

### Shared `users` table

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

### Activating a member

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
  top10_setup.sql          Top 10 strengths catalog + per-user table

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

## Top 10 Strengths sub-app — current state

Tables (see `sql/top10_setup.sql`):

- `strengths_catalog` — all 34 Gallup CliftonStrengths themes (name, domain,
  sort_order). Read-only for authenticated users. Already seeded.
- `user_top_strengths` — one row per ranked strength (rank 1–10) per user,
  with `name_it` / `claim_it` / `aim_it` text columns for the per-client
  coaching notes. RLS scopes reads/writes to `auth.uid() = user_id`. Unique
  constraints on `(user_id, rank)` and `(user_id, strength_id)`.
- `user_top_strengths_view` — joined view used by the report so the page only
  needs one query.

Save flow (`enter.html`): delete-all-then-insert the user's 10 rows in a
single batch. Simpler than juggling the two unique constraints on reorder.

No canned Gallup-authored content is shipped. Theme names and the four
domains are factual; per-strength descriptions and Name/Claim/Aim text are
captured per client in the entry form to avoid IP issues.

## Conventions for new work

- **Don't add a build step.** If a task seems to need one, push back and ask
  before introducing tooling.
- **Don't replace inline Supabase init with a shared module** — it breaks on
  GitHub Pages.
- **Don't add canned Gallup descriptions** to the catalog seed. Keep the
  catalog name + domain + sort_order only.
- **SQL files are idempotent.** Use `create table if not exists`,
  `on conflict do nothing`, and `drop policy if exists` so re-running is
  safe.
- **Match existing styling.** Brand color `#003366`, Tailwind-free, the
  variables and class names in `top10/css/style.css` are the reference.
- **Membership gating goes on every authenticated page** — copy the snippet
  from `top10/index.html` or `enter.html`.

## Branching & PRs

- Final code lives on `main` (GitHub Pages serves from there).
- Develop on a feature branch, push, open a **draft PR** against `main`, then
  merge once the user approves. Do not push directly to `main`.
- Use the GitHub MCP tools (`mcp__github__*`) for all GitHub interactions —
  no `gh` CLI available.

## Things to ask before doing

- "Build a new app" — confirm whether it belongs in this repo as a new
  `<name>/` folder or in a separate Coach4U repo.
- Anything that touches `auth`, the `users` table schema, or RLS policies
  shared across sub-apps.
- Adding new top-level dependencies, tooling, or a build pipeline.
