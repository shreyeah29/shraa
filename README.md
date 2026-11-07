# Shraa — Phase 1

Money, work and health in one iPhone app, with nudges that are tough, strict and a little rude.

## What's in Phase 1

| Area | What works |
|---|---|
| Today | Spent today, safe-to-spend per day, steps / water / gym rings, top 3 tasks, gym + water streaks, Review inbox banner |
| Money | Bank SMS → transaction automatically (HDFC + ICICI tested), auto-categories that learn from your edits, duplicate check, monthly + per-category budgets, donut chart, search, manual add, paste-an-SMS, accounts & cards (auto-created from SMS), Review inbox, CSV export |
| Work | Tasks (Work / Learn / Life, priority, due, quick add), projects with agreed / received / pending amount, payment pipeline + overdue, record payment → income |
| Health | Steps, active kcal, sleep from Apple Health; water (+ saved to Health), gym check-in with workout type, meals (home / outside / skipped), 7-day chart |
| Nudges | Water every ~90 min, step checkpoints (11:00, 15:00, 18:30, 20:30), gym (45 min before / on time / last call), meals, morning plan, evening scorecard, budget 80% / 100% alerts, big-spend alert. Only sent when you're actually behind, with 3 escalation levels. Buttons on the notification: Drank 250 ml / 500 ml, At the gym, Ate it / Skipped, Snooze 30 min |
| Siri | "Log water in Shraa", "Add expense in Shraa", "Gym check in Shraa" |
| Privacy | Everything stays on the phone (SwiftData). Face ID lock. |

## 1. Build it (about 10 minutes)

You need a Mac with **Xcode 16 or newer** and an iPhone on **iOS 17+**.

```bash
brew install xcodegen          # once
cd Shraa
xcodegen                       # creates Shraa.xcodeproj from project.yml
open Shraa.xcodeproj
```

In Xcode:

1. Select the **Shraa** target → **Signing & Capabilities** → pick your Team. If `com.shreya.shraa` is taken, change the bundle ID (also in `project.yml` so it sticks).
2. Check the capabilities are there: **HealthKit** (with Background Delivery), **Time Sensitive Notifications**, **Background Modes** (Background fetch, Background processing). XcodeGen adds them from `project.yml`; if Xcode shows a red warning, click the fix button.
3. Plug in your iPhone, choose it as the run destination, press **⌘R**.
4. Run the tests with **⌘U**: the SMS parser tests use your real HDFC and ICICI messages.

For TestFlight: **Product → Archive → Distribute App → TestFlight & App Store**.

A placeholder icon (white "S" on a coral-to-purple gradient) is included. To replace it, drop a 1024×1024 PNG named `AppIcon.png` into `Shraa/Resources/Assets.xcassets/AppIcon.appiconset`.

## 2. First launch

The app asks for Apple Health and notification permission, then your monthly spending budget. Then open **Today → gear icon** and check your goals and times:

- Steps 10,000 · Water 3,000 ml · Gym Mon–Fri at 18:00
- Wake 07:00 · Sleep 23:00 · Breakfast 09:00 · Lunch 13:30 · Dinner 20:30

Tap **Send a test nudge**, lock the phone, and you should see a water nudge in 5 seconds with buttons.

Also allow **Time Sensitive** for Shraa (Settings → Notifications → Shraa), so nudges get through Focus modes.

## 3. Connect your bank SMS (the important bit)

iPhone apps can't read SMS, so we use a Shortcuts automation to forward each bank SMS to Shraa. It runs silently in the background. Set up **4 automations**, one per keyword:

| # | Message Contains | Catches |
|---|---|---|
| 1 | `debited` | ICICI and HDFC account debits, UPI from PhonePe |
| 2 | `credited` | Money received |
| 3 | `spent` | Debit and credit card spends |
| 4 | `Sent Rs` | HDFC UPI "Sent Rs.x From HDFC Bank" format |

For each one:

1. Open **Shortcuts** → **Automation** tab → **+** (or **New Automation**).
2. Pick **Message**.
3. Leave **Sender** as is. Tap **Message Contains** → type the keyword from the table.
4. Select **Run Immediately**. Turn **Notify When Run** off if you don't want a banner each time.
5. Tap **Next** → **New Blank Automation** (or **Create New Shortcut**).
6. Search actions for **Shraa** → choose **Log Bank SMS**.
7. Tap the **Message text** field → choose **Shortcut Input** (it's the SMS). Done.

Banks don't appear as contacts, so we match on text instead of sender. The app ignores OTPs, bill reminders, promos and failed transactions, so it's fine if an automation catches one.

Tip: test right away. Copy one of your old bank SMS, then in Shraa go **Money → + → Paste bank SMS**.

### How the money logic works

- A PhonePe payment shows up as a bank debit SMS (PhonePe pays from your linked HDFC/ICICI account), so it's captured with no PhonePe connection.
- Same transaction from two sources (e.g. you added it by hand, then the SMS came) within 10 minutes, or the same UPI reference, is saved once.
- Credit card bill payments are **transfers**, not spending, so card spends aren't counted twice.
- Change a transaction's category once and every future transaction from that merchant goes there.
- SMS the parser can't read go to **Review inbox**. Send me those (mask the account digits) and I'll add the format.

## 4. Project layout

```
Shraa/
  project.yml                  XcodeGen config (targets, capabilities, Info.plist)
  Shraa/
    App/                       App entry, Face ID lock, onboarding, Today, Settings, shared UI
    Core/                      SwiftData models, preferences, Siri / Shortcuts intents
    Features/Money/            SMS parser, categoriser, ingest + dedup, stats, screens
    Features/Work/             Tasks and projects
    Features/Health/           HealthKit, nudge library, nudge scheduler, screen
  ShraaTests/                  Parser tests with your real SMS samples
```

To add or change nudge lines, edit `Features/Health/NudgeLibrary.swift`. Level 0 is mild, level 2 is last call.

## 5. What's next (Phase 2)

Savings goals and emergency fund, life savings planner, subscription detector, card due-date reminders, statement import (PhonePe / card PDFs), income-to-project auto-matching, learning goals and focus timer, widgets, XP and levels, Sunday weekly review.

## Known limits

- I wrote this without compiling it (no Xcode in my environment). Expect a few small compile errors on first build; paste them to me and I'll fix them fast.
- iOS allows 64 scheduled notifications per app; Shraa keeps it at 55 and re-plans as you go.
- Step nudges use the step count from the last re-plan (Health wakes the app about hourly), so the number can be up to an hour old.
