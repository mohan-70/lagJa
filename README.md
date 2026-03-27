# Lagja 🚀 - Placement Preparation Tracker

A production-ready Flutter app for BCA/BTech students in India to track their placement preparation journey.

## 🎯 Features

- **📊 Dashboard**: Track your progress with stats, streaks, and activity heatmaps
- **💻 DSA Tracker**: Add, filter, and track Data Structures & Algorithms problems
- **🏢 Companies**: Manage job applications with status workflow
- **📝 Interview Notes**: Document interview experiences and company-specific notes
- **🔥 Activity Tracking**: Maintain streaks and visualize your preparation journey

## 🛠 Tech Stack

- **Flutter**: Latest stable version
- **Firebase**:
  - Authentication (Google Sign-In only)
  - Cloud Firestore
- **Packages**:
  - `flutter_heatmap_calendar` - Activity visualization
  - `intl` - Date formatting
  - `uuid` - Unique ID generation

## 🎨 Design

- **Dark Theme Only**: Material 3 design system
- **Color Scheme**:
  - Primary: `#6C63FF`
  - Background: `#0F0F1A`
  - Surface/Card: `#1A1A2E`
- **UI**: Premium, minimal, smooth with consistent spacing

## 📱 Screens

1. **Login Screen**: Google Sign-In authentication
2. **Dashboard**: Overview with stats and heatmap
3. **DSA Tracker**: Problem management with filters
4. **Companies**: Application tracking with status workflow
5. **Notes**: Interview notes with search functionality

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>=3.10.0)
- Dart SDK (>=3.0.0)
- Firebase project setup

### Setup Instructions

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd lagja
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   
   a. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
   
   b. Enable Authentication:
      - Go to Authentication → Sign-in method
      - Enable Google Sign-In
   
   c. Setup Firestore Database:
      - Go to Firestore Database → Create database
      - Choose Test mode for development
      - Select a location
   
   d. Add Android app:
      - Go to Project settings → Add app → Android
      - Package name: `com.example.lagja`
      - Download `google-services.json`
      - Place it in `android/app/google-services.json`
   
   e. Add iOS app (if needed):
      - Go to Project settings → Add app → iOS
      - Bundle ID: `com.example.lagja`
      - Download `GoogleService-Info.plist`
      - Place it in `ios/Runner/GoogleService-Info.plist`

4. **Update Firebase Configuration**
   
   Run the FlutterFire CLI to generate the correct configuration:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   
   This will update `lib/firebase_options.dart` with your actual Firebase configuration.

5. **Android Configuration**
   
   Add the following to `android/build.gradle`:
   ```gradle
   buildscript {
     dependencies {
       // Add this line
       classpath 'com.google.gms:google-services:4.3.15'
     }
   }
   ```
   
   Add to `android/app/build.gradle`:
   ```gradle
   // Apply the plugin at the bottom
   apply plugin: 'com.google.gms.google-services'
   ```

6. **Run the app**
   ```bash
   flutter run
   ```

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry point
├── firebase_options.dart        # Firebase configuration
├── models/                      # Data models
│   ├── dsa_problem.dart
│   ├── company.dart
│   └── note.dart
├── services/                    # Business logic
│   ├── auth_service.dart
│   └── firestore_service.dart
├── screens/                     # UI screens
│   ├── login_screen.dart
│   ├── dashboard_screen.dart
│   ├── dsa_tracker_screen.dart
│   ├── companies_screen.dart
│   └── notes_screen.dart
└── widgets/                     # Reusable widgets
    └── main_screen.dart
```

## 🔥 Firebase Data Structure

All data is scoped per user under `users/{uid}/`:

```
users/{uid}/
├── data/
│   ├── dsa_problems/
│   │   └── {problemId}/
│   │       ├── topic
│   │       ├── title
│   │       ├── difficulty
│   │       ├── isSolved
│   │       └── createdAt
│   ├── companies/
│   │   └── {companyId}/
│   │       ├── name
│   │       ├── role
│   │       ├── status
│   │       ├── notes
│   │       └── createdAt
│   └── notes/
│       └── {noteId}/
│           ├── companyName
│           ├── content
│           └── createdAt
└── activity/
    └── dates/
        └── {yyyy-MM-dd}/
            └── count
```

## 🎯 Features in Detail

### DSA Tracker
- Add problems with topic, title, and difficulty
- Filter by difficulty and solved status
- Mark problems as solved/unsolved
- Delete with confirmation
- Search functionality

### Companies Tracker
- Add companies with role and status
- Status workflow: Wishlist → Applied → Interview → Offered/Rejected
- Color-coded status chips
- Update status with tap
- Optional notes per company

### Interview Notes
- Add notes for specific companies
- Search by company name
- Preview with "Read More" for long notes
- Full modal view for detailed notes
- Delete with confirmation

### Dashboard
- Personalized greeting
- Current streak calculation
- Activity heatmap visualization
- Real-time stats (problems, companies, notes)
- Quick action buttons

## 🧪 Testing

```bash
# Run tests
flutter test

# Run with coverage
flutter test --coverage
```

## 📦 Build

```bash
# Build APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release

# Build iOS
flutter build ios --release
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🚀 Deployment

### Android
1. Build the release APK or App Bundle
2. Upload to Google Play Console
3. Follow the standard release process

### iOS
1. Build the iOS release
2. Upload to App Store Connect
3. Follow the standard App Store review process

## 🐛 Troubleshooting

### Common Issues

1. **Firebase Configuration Error**
   - Ensure `firebase_options.dart` is properly configured
   - Verify `google-services.json` is in the correct location
   - Check Firebase project settings

2. **Google Sign-In Issues**
   - Ensure SHA-1 fingerprint is added to Firebase
   - Verify Google Sign-In is enabled in Firebase Console
   - Check OAuth consent screen configuration

3. **Build Issues**
   - Run `flutter clean` and `flutter pub get`
   - Ensure all dependencies are compatible
   - Check for platform-specific requirements

## 📞 Support

For issues and questions:
- Create an issue on GitHub
- Check existing issues for solutions
- Refer to Flutter and Firebase documentation

---

**Built with ❤️ for Indian students preparing for placements**
