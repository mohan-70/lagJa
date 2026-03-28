<div align="center">

# Lagja 🚀
### Your Placement Journey Starts Here

A production-ready Flutter app for BCA/BTech students in India to track,
plan, and crush their placement preparation.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Gemini](https://img.shields.io/badge/Gemini%202.0%20Flash-4285F4?style=for-the-badge&logo=google&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-6C63FF?style=for-the-badge)

</div>

---

## 📱 What is Lagja?

**Lagja** (Hindi: "lag ja apni prep mein") is an all-in-one placement preparation
tracker built specifically for Indian engineering students. It combines a DSA
tracker, company wishlist, interview notes, AI-powered roadmap generator, and a
friend leaderboard — all in one clean dark-themed app.

---

## ✨ Features

### 📊 Dashboard
- Personalized greeting with your name
- **GitHub-style activity heatmap** — visualize your daily prep consistency
- **Daily streak tracker** — keep the chain alive 🔥
- Real-time stats: problems solved, companies tracked, notes written
- Quick action buttons for fast entry

### 💻 DSA Tracker
- Add problems with **topic, title, and difficulty** (Easy / Medium / Hard)
- Filter by difficulty, solved/unsolved status
- Mark problems solved — updates your streak and heatmap automatically
- Group problems by topic with expandable sections
- Long press to delete with confirmation

### 🏢 Companies
- Build your **dream company wishlist**
- Full status workflow: `Wishlist → Applied → Interview → Offered / Rejected`
- Color-coded status chips for instant visibility
- Tap to update status, long press to delete
- Filter by status

### 📝 Interview Notes
- Add **company-specific interview notes**
- Search notes by company name
- Preview cards with "Read More" for long notes
- Full modal view for detailed reading
- Delete with confirmation

### ✨ AI Roadmap Generator (Powered by Gemini 2.0 Flash)
**Phase 1 — Full Placement Roadmap:**
- Input: target company, job role, weeks available, current level
- Gemini generates a **week-by-week topic roadmap** covering:
  - DSA, OOPs, Theory (OS/DBMS/CN), System Design, HR, Projects
- Each topic shows: priority, estimated days, category, type (practice/read/revise)
- Topics grouped by week number

**Phase 2 — Topic Deep Dive:**
- Tap any topic → Gemini generates tailored content:
  - **DSA/OOPs** → practice problems with difficulty + why it's important
  - **Theory** → key concepts + likely interview questions
  - **HR** → common questions + tips to answer
  - **Project/System Design** → talking points + explanation tips
- DSA problems can be **saved directly to DSA Tracker** in one tap

### 🔍 Company Intel (AI-Powered)
- Search any company → Gemini returns:
  - Fresher CTC & intern stipend
  - Hiring difficulty + selection rate
  - Interview rounds breakdown
  - Key skills required
  - Tips to get in
  - Company rating
- Quick search chips: TCS, Infosys, Google, Amazon, Wipro

### 🏆 Placement War — Friend Leaderboard
- Create a **private group** with friends using a 6-character invite code
- Real-time leaderboard sorted by **weekly problems solved**
- 🥇🥈🥉 medals for top 3
- See everyone's streak, weekly count, and total problems
- Auto-syncs your stats when you open the screen
- Share invite code to add more friends
- Resets every Monday

### ⚙️ Settings
- Edit your display name
- Clear DSA problems, companies, or notes
- Sign out
- Delete account (removes all data)
- Privacy Policy link

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (latest stable) |
| Auth | Firebase Authentication (Google Sign-In) |
| Database | Cloud Firestore |
| AI | Google Gemini 2.0 Flash API |
| HTTP | `http` package |
| Heatmap | `flutter_heatmap_calendar` |
| Utilities | `uuid`, `intl`, `url_launcher` |

---

## 🎨 Design

- **Theme**: Dark only — no light mode
- **Style**: Premium minimal — inspired by Linear / Apple dark UI
- **Colors**:
  - Background: `#000000`
  - Card: `#1C1C1E`
  - Border: `#2C2C2E`
  - Accent: `#6C63FF`
  - Text: `#FFFFFF` / `#8E8E93`
- **Material 3** with custom overrides for a native iOS dark feel

---

## 📁 Project Structure