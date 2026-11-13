# Workouts: setup guide

A small personal workout tracker: schedule workouts on a calendar (one day, weekly, or every N days), then check off each exercise as you do it. It runs on GitHub Pages and stores data in Supabase, so your PC and phone share the same data.

**Files**

| File | What it is |
|---|---|
| `index.html` | The whole app |
| `config.example.js` | Template for `config.js`, which holds your Supabase settings (see step 3) |
| `manifest.webmanifest`, `icon-*.png` | Let Android install it as an app |
| `schema.sql` | Database tables and security rules. You paste this into Supabase once; it doesn't need to go on GitHub |

**Try it first:** open `index.html` in a browser. Until you add your Supabase settings it runs in *demo mode*, which saves data only in that browser, so you can try it out right away.

Setup takes about 20 minutes. Dashboard menu names occasionally move around, so if a label below doesn't match exactly, look for the nearest equivalent.

---

## 1. Create the Supabase project

1. Sign up at **supabase.com** (with email, or with your GitHub account, which you'll need for step 3 anyway).
2. Create a **new project**. Pick any name, set a database password (save it in your password manager; the app doesn't use it), and choose a region near you. Under **Security**:
   - **Enable Data API:** on (the app needs it)
   - **Automatically expose new tables:** off (`schema.sql` grants access to its own tables)
   - **Enable automatic RLS:** on (an optional safety net for tables you add later)
3. When the project is ready, open **SQL Editor → New query**, paste in all of `schema.sql`, and click **Run**. You should see "Success. No rows returned."

## 2. Create your login, then lock sign-ups

1. Go to **Authentication → Users → Add user → Create new user**. Enter your email and a strong password, and tick **Auto Confirm User**.
2. Go to **Authentication → Sign In / Providers** (or **Settings**) and turn **off** "Allow new users to sign up". From now on your account is the only one that can exist.

## 3. Connect the app to your project

1. In Supabase, open **Project Settings → API Keys** (the Connect button at the top also shows these). Copy:
   - the **Project URL**, like `https://abcdefgh.supabase.co`
   - the **publishable key**, which starts with `sb_publishable_` (older projects call it the `anon` key)
2. Make a copy of `config.example.js` named **`config.js`** and fill in your values:
   ```js
   window.APP_CONFIG = {
     SUPABASE_URL: 'https://abcdefgh.supabase.co',
     SUPABASE_KEY: 'sb_publishable_…',
   };
   ```
   ⚠️ Use only the **publishable** key. Never put the **secret** / `service_role` key in this file. That key bypasses all the security rules.

   Keeping the settings in their own file means you can replace `index.html` with a newer version at any time without re-entering them. Without a `config.js`, the app runs in demo mode.

## 4. Publish on GitHub Pages

1. On github.com, create a **new public repository**, e.g. `workouts`.
2. Click **Add file → Upload files** and upload `index.html`, your `config.js`, `manifest.webmanifest`, and the three `icon-*.png` files. Commit.
3. Go to **Settings → Pages**. Under *Build and deployment*, set Source to **Deploy from a branch**, branch **main**, folder **/ (root)**, and click **Save**.
4. After a minute or two the app is live at `https://YOUR-USERNAME.github.io/workouts/`.

The code is public, which is expected and fine. All it reveals is your project URL and publishable key. Your data is only readable after signing in as you, enforced by the rules in `schema.sql`.

## 5. Use it on your devices

- **PC:** open the URL, sign in, and bookmark it.
- **Android:** open the URL in Chrome and sign in. Then use **⋮ menu → Add to Home screen / Install app**. It opens full-screen like a normal app, and you stay signed in.

---

## Using the app

- **Tracker:** the selected day's workouts (opens on today), plus any single exercises grouped under "Exercises".
  - Exercises with several sets show a numbered button per set. Tap each one as you finish it, and tap again to undo. One-set exercises have a single checkbox.
  - **⋯ on an exercise** changes that day only: *Remove a set*, *Add a set*, *Reset to plan*, *Edit for this day* (e.g. note the weight you actually used), or *Remove from this day*. Removed exercises are listed at the bottom with a **Restore** button.
  - **+ Add an exercise to this day** adds a one-off exercise to that date only. It isn't added to your Workouts page.
  - Use ‹ › to look at other days, including catching up on yesterday.
- **Calendar:** a month view with a dot per day: green = all sets done, amber = partly done, red = missed, outline = planned. Tap a day to open it.
- **Workouts:** your schedule, in two kinds:
  - **+ Workout:** a named group of exercises scheduled together
  - **+ Exercise:** one exercise scheduled on its own

  Each exercise has a number of sets and optional per-set details (e.g. "10 reps @ 40 lb"). Each has one of three schedules:
  - **One day:** a single date
  - **Weekly:** chosen days of the week
  - **Every N days:** counting from the start date
- **Your history is kept separately from your workouts.** The first time you touch a workout on a day (check off a set or use ⋯), its exercises are copied into that day's log. After that:
  - Editing or deleting a workout or exercise on the Workouts tab doesn't change days you've already started. Those days keep exactly what you did.
  - Changes apply to upcoming days, and to any day where you haven't touched that workout yet. That includes past days you skipped: those are shown from the current schedule, so deleting a workout also removes its "missed" marks.
  - If you edit a workout after starting it today, today keeps the version you started. Use ⋯ → *Edit for this day* to adjust today.

## Good to know

- **Free-tier pausing:** Supabase pauses free projects after about a week with no activity (e.g. while you're on vacation). Your data is kept. If the app stops loading, open the Supabase dashboard and click **Restore project**.
- **Updating the app:** upload the new `index.html` to the repository, replacing the old one. Leave `config.js` alone, since your settings live there. GitHub Pages redeploys automatically in about a minute; on your phone, close and reopen the app to pick up the change. (It can take a few minutes for the old version to stop being served from cache.)
- **Forgot your password:** keep it in a password manager. If it's lost, you can set a new one from Supabase's SQL Editor:
  ```sql
  update auth.users
  set encrypted_password = crypt('your-new-password', gen_salt('bf'))
  where email = 'you@example.com';
  ```
  Don't delete and recreate the user: your data belongs to that user and would be deleted with it.
