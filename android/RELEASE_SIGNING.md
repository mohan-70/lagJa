# Lagja - Release Signing Setup Instructions

## 1. Generate Keystore
Run this command in the `android/` directory:

```bash
keytool -genkey -v -keystore ../keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

## 2. Update key.properties
Replace the placeholder values in `android/key.properties`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../keystore.jks
```

## 3. Build Release APK
After setting up the keystore and updating passwords:

```bash
flutter build apk --release
flutter build appbundle --release
```

## Important Notes
- Keep your keystore file and passwords secure
- Backup `keystore.jks` and `key.properties` in a safe location
- Never commit these files to version control (already added to .gitignore)
- You'll need the keystore for future app updates to Play Store

## Play Store Upload
Use the appbundle file for Play Store submission:
- Location: `build/app/outputs/bundle/release/app-release.aab`
- This is the recommended format for Play Store
