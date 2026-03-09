# DebtTrack 💸

> **Track. Split. Settle.**

DebtTrack is an Android app that helps you manage your money with friends — track personal expenses, split bills, give/take loans, record repayments, and get smart analytics — all in one place.

---

## Features

- **Personal Expenses** — Log daily self-spending and track monthly totals
- **Bill Splitting** — Split expenses with friends and track who owes what
- **Loans** — Record money you lent or borrowed with full repayment tracking
- **Repayments** — Mark partial or full repayments against any transaction
- **GPay Integration** — A smart popup appears every time you close GPay, letting you instantly record a payment (Self / Split / Loan / Repay)
- **Dashboard Analytics** — View total created, paid, remaining, completion rate, debt ratio, top splits, top lents, and monthly trends
- **Person Reports** — See a breakdown of every person you've transacted with
- **Profile** — Set your name, phone, UPI ID, and profile photo
- **Reset** — Securely wipe all data with a confirmation flow
- **Splash Screen** — Branded launch screen with animated logo

---

## Platform

| Platform | Status |
|----------|--------|
| Android  | ✅ Available |
| iOS      | 🔜 Coming Soon |

---

## Download

### ⬇️ [Download DebtTrack.apk](YOUR_RELEASE_LINK_HERE)

### Steps to install:

1. Click the download link above to download `DebtTrack.apk`
2. Open the downloaded file on your Android phone
3. If prompted, go to **Settings → Install unknown apps** and allow installation from your browser or file manager
4. Tap **Install**
5. Open **DebtTrack** and enjoy!

> Requires Android 5.0 (API 21) or higher

---

## Security & Privacy

DebtTrack is built with a **100% offline, local-first** architecture. Here is exactly how your data is handled:

### Where is your data stored?
- All data — transactions, persons, payments, personal expenses — is stored in a **local SQLite database** on your device only
- Your profile photo, name, phone, and UPI ID are stored in your device's **local SharedPreferences**
- **No data is ever sent to any server, cloud, or third party**

### Why is it secure?
- **No internet required** — the app has no backend, no API calls, no cloud sync
- **No account needed** — no sign-up, no login, no email, no password
- **No ads, no trackers, no analytics SDKs** — your usage is completely private
- **Data never leaves your phone** — everything lives in your device's private app storage, inaccessible to other apps
- **Reset protection** — wiping all data requires manually typing `reset` to prevent accidental deletion

### What permissions does the app use?
| Permission | Why |
|------------|-----|
| Camera | Scan bills and QR codes |
| Accessibility Service | Detect when GPay is closed to show payment prompt |
| Notifications | Optional payment reminders |

> The Accessibility Service only watches for app window changes (specifically GPay closing). It does **not** read screen content, keystrokes, or any sensitive information.

---

## Tech Stack

- **Flutter** (Dart)
- **SQLite** via `sqflite` — local database
- **Shared Preferences** — local key-value storage
- **Google ML Kit** — on-device Bill OCR (no data sent to Google)
- **Mobile Scanner** — QR Code scanning
- **Android Accessibility Service** — GPay close detection

---

## License

This project is for personal use. All rights reserved.
