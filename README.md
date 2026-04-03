<div align="center">

# Lagja 🚀

### Your Placement Journey Starts Here

A production-ready Flutter app for BCA/BTech students in India to track,
plan, and crush their placement preparation — powered by AI.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Gemini](https://img.shields.io/badge/Gemini%202.0%20Flash-4285F4?style=for-the-badge&logo=google&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-0052CC?style=for-the-badge)

</div>

-----

## 📱 What is Lagja?

**Lagja** (Hindi: “lag ja apni prep mein”) is an all-in-one AI-powered placement preparation tracker built specifically for Indian engineering students. It combines a DSA tracker, company wishlist, interview notes, AI roadmap generator, company intel, friend leaderboard, and personalized settings — all in one premium light-themed app.

-----

## ✨ Features

### 📊 Dashboard (Today Tab)

- Personalized greeting with user’s first name
- **GitHub-style activity heatmap** — visualize daily prep consistency
- **Daily streak tracker** — keep the chain alive 🔥
- Real-time stats: problems solved, companies tracked, notes written
- Quick action buttons for fast entry
- **Top tab navigation** (Swiggy-style) with 4 sub-tabs:
  - Overview, Leaderboard, Company Intel, Settings

### 💻 DSA Tracker

- Add problems with **topic, title, and difficulty** (Easy / Medium / Hard)
- Filter by difficulty and solved/unsolved status
- Color-coded difficulty strip on each card
- Mark problems solved — updates streak and heatmap automatically
- Search problems by title
- Long press to delete with confirmation
- Empty state with motivational message

### 🏢 Companies

- Build your **dream company wishlist**
- Full status workflow: `Wishlist → Applied → Interview → Offered / Rejected`
- Color-coded status chips for instant visibility
- Filter by status
- Tap to update status, long press to delete

### 📝 Interview Notes

- Add **company-specific interview notes**
- Search notes by company name
- 2-line preview cards with “Read more” option
- Full modal view for detailed reading
- Delete with confirmation

### ✨ AI Roadmap Generator (Gemini 2.0 Flash)

**Phase 1 — Full Placement Roadmap:**

- Input: target company, job role, weeks available, current level
- Gemini generates a **week-by-week topic roadmap** covering:
  - DSA, OOPs, Theory (OS/DBMS/CN), System Design, HR, Projects
- Each topic shows: priority, estimated days, category, type (practice/read/revise)
- Topics grouped by week number

**Phase 2 — Topic Deep Dive:**

- Tap any topic → Gemini generates tailored content:
  - **DSA/OOPs** → practice problems with difficulty + why important
  - **Theory** → key concepts + likely interview questions
  - **HR** → common questions + tips to answer
  - **Project/System Design** → talking points + prep tips
- DSA problems saved directly to DSA Tracker in one tap

### 🔍 Company Intel (AI-Powered)

Search any company and get:

- Fresher CTC & intern stipend estimates
- Hiring difficulty + selection rate
- Interview rounds breakdown
- Key skills required
- Tips to get in
- Company rating
- Quick search chips: TCS, Infosys, Google, Amazon, Wipro

### 🏆 Placement War — Friend Leaderboard

- Create a **private group** with a 6-character invite code
- Real-time leaderboard sorted by **weekly problems solved**
- 🥇🥈🥉 medals for top 3
- See everyone’s streak, weekly count, and total problems
- Auto-syncs your stats on open
- Share invite code to add friends
- Leave group option
- Resets every Monday

### ⚙️ Settings

- Edit display name
- App version info
- Clear DSA problems / companies / notes
- Sign out
- Delete account (removes all Firestore data)
- Privacy Policy link

-----

## 🎨 Design System

- **Theme**: Light — Inspired by Unstop design
- **Style**: Premium minimal — Light blue cards and deep blue accents
- **Colors**:
  - Background: `#FFFFFF` (White)
  - Surface/Card: `#E8F0FF` (Light Blue)
  - Border: `#E0E0E0` (Light Gray)
  - Accent: `#0052CC` (Deep Blue)
  - Text Primary: `#1A1A1A` (Dark)
  - Text Secondary: `#4A4A4A` (Dark Gray)
  - Success: `#10B981` (Green)
  - Warning: `#FF9F0A` (Orange)
  - Error: `#FF453A` (Red)
- **Material 3** with central ThemeData enforcement

### Reusable Widgets (`lib/widgets/ui/`)

- `AppCard` — standard light blue card with border
- `FakeGlassCard` — blue-tinted hero card
- `GradientButton` — deep blue to purple gradient button with press animation
- `SectionHeader` — left accent bar + uppercase label
- `DifficultyChip` — color-coded Easy/Medium/Hard
- `StatusChip` — color-coded company application status

### Custom Loading

- `LagjaLoader` — branded pulsing logo animation replaces all CircularProgressIndicators
- Login screen: deep blue ring animates around logo during Google Sign In

-----

## 🛠 Tech Stack

|Layer    |Technology                               |
|---------|-----------------------------------------|
|Framework|Flutter (latest stable)                  |
|Auth     |Firebase Authentication (Google Sign-In) |
|Database |Cloud Firestore (real-time StreamBuilder)|
|AI       |OpenRouter (Gemini 2.0 Flash compatible) via http package |
|Remote Config | Firebase Remote Config ^4.3.0              |
|HTTP     |`http` package                           |
|Heatmap  |`flutter_heatmap_calendar`               |
|Utilities|`uuid`, `intl`, `url_launcher`           |

-----

## 📁 Project Structure

```
lib/
├── main.dart                        # App entry + ThemeData
├── firebase_options.dart
├── constants/
│   └── api_constants.dart           # Gemini API key (keep secret, add to .gitignore)
├── models/
│   ├── dsa_problem.dart
│   ├── company.dart
│   ├── note.dart
│   ├── roadmap_problem.dart
│   └── group_member.dart
├── services/
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── ai_service.dart
│   └── remote_config_service.dart
├── screens/
│   ├── login_screen.dart
│   ├── dashboard_screen.dart        # Top tabs (Overview, Leaderboard, Company Intel, Settings)
│   ├── roadmap_screen.dart          # Phase 1 roadmap + Phase 2 TopicContentScreen
│   ├── dsa_tracker_screen.dart
│   ├── companies_screen.dart
│   ├── notes_screen.dart
│   ├── roadmap_screen.dart          # Phase 1 roadmap + Phase 2 TopicContentScreen
│   ├── leaderboard_screen.dart
│   ├── company_intel_screen.dart
│   └── settings_screen.dart
└── widgets/
    ├── main_screen.dart             # Bottom nav shell
    ├── lagja_loader.dart            # Branded loading animation
└── ui/
        ├── app_card.dart
        ├── fake_glass_card.dart
        ├── gradient_button.dart
        ├── lagja_loader.dart
        ├── section_header.dart
        ├── difficulty_chip.dart
        └── status_chip.dart
    └── theme/
        ├── app_colors.dart
        └── app_theme.dart
```

-----

## 🔥 Firestore Data Structure

```
users/{uid}/
├── dsa_problems/{problemId}
│   ├── topic, title, difficulty, isSolved, createdAt
├── companies/{companyId}
│   ├── name, role, status, notes, createdAt
├── notes/{noteId}
│   ├── companyName, content, createdAt
├── activity/{yyyy-MM-dd}
│   └── count
└── meta/
    ├── streak → { currentStreak, lastActiveDate }
    └── group  → { groupId, joinedAt }

groups/{groupId}/
├── name, inviteCode, createdBy, createdAt
└── members/{uid}
    ├── displayName, photoUrl
    ├── weeklyProblems, totalProblems, currentStreak
    └── lastUpdated
```

-----

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `>=3.10.0`
- Dart SDK `>=3.0.0`
- Firebase project
- Gemini API key from [Google AI Studio](https://aistudio.google.com) (free tier available)

### Setup

```bash
# 1. Clone the repo
git clone https://github.com/mohan-70/lagja.git
cd lagja

# 2. Install dependencies
flutter pub get

# 3. Configure Firebase
dart pub global activate flutterfire_cli
flutterfire configure

# 4. Add API keys to assets/.env
# OPENROUTER_API_KEY=your_key_from_openrouter.ai

# 5. Run
flutter run
```

### Firebase Setup

1. Enable **Google Sign-In** in Firebase Auth
1. Create **Firestore database** in test mode
1. Add your **SHA-1** fingerprint to Firebase Console
1. Download `google-services.json` → place in `android/app/`

### Custom App Icon

```bash
dart run flutter_launcher_icons
flutter clean
flutter run
```

-----

## 📦 Build

```bash
# Debug
flutter run

# Release APK
flutter build apk --release

# App Bundle (Play Store)
flutter build appbundle --release
```

-----

## 🐛 Troubleshooting

**Google Sign-In `ApiException: 10`**
→ Add SHA-1 fingerprint to Firebase Console:

```bash
cd android && ./gradlew signingReport
```

**Duplicate Firebase App Error**

```dart
if (Firebase.apps.isEmpty) {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
```

**Build issues**

```bash
flutter clean && flutter pub get
```

**App icon not updating**
→ Uninstall app from device first, then reinstall fresh APK.

-----

## 🔒 Security Notes

- Never commit `lib/constants/api_constants.dart` with your real API key
- Add it to `.gitignore`
- For production: move API key to a secure backend proxy

-----

## 📄 Privacy Policy

[View Privacy Policy](https://mohan-70.github.io/lagja-privacy)

-----

## 📄 License

MIT License — see <LICENSE> for details.

-----

<div align="center">

**Built with ❤️ for Indian students preparing for placements**

*by [Trumos](https://github.com/mohan-70)*

</div>