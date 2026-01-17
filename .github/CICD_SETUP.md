# GitHub Actions CI/CD Setup Guide for CardFlow

This guide explains how to set up GitHub Actions to automatically build APK (Android) and IPA (iOS) files for the CardFlow Flutter application.

## 📁 Workflow Files

Three workflow files have been created in `.github/workflows/`:

| File | Purpose | Trigger |
|------|---------|---------|
| `build-android.yml` | Builds Android APK & App Bundle | Push to main/develop, PRs, tags |
| `build-ios.yml` | Builds iOS IPA | Push to main/develop, PRs, tags |
| `release.yml` | Creates releases with both platforms | Version tags (v*.*.*) |

## 🚀 Quick Start

### 1. Push to GitHub

The workflows will automatically run when you:
- Push to `main` or `develop` branches
- Create a Pull Request to `main`
- Push a version tag (e.g., `v1.0.0`)

### 2. Manual Trigger

You can also manually trigger builds from the GitHub Actions tab using "Run workflow".

## 🔐 Setting Up Secrets

### Required Secrets for Firebase (Both Platforms)

Navigate to: **Repository Settings → Secrets and variables → Actions → New repository secret**

#### For Android Firebase:
| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `GOOGLE_SERVICES_JSON` | Base64 encoded google-services.json | `base64 -i android/app/google-services.json` |

#### For iOS Firebase:
| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `GOOGLE_SERVICE_INFO_PLIST` | Base64 encoded GoogleService-Info.plist | `base64 -i ios/Runner/GoogleService-Info.plist` |

### Android Signing Secrets (For Play Store Release)

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `ANDROID_KEYSTORE_BASE64` | Base64 encoded .jks keystore | `base64 -i your-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password | Your keystore password |
| `ANDROID_KEY_ALIAS` | Key alias name | Your key alias |
| `ANDROID_KEY_PASSWORD` | Key password | Your key password |

#### Creating an Android Keystore:

```bash
# Generate a new keystore
keytool -genkey -v -keystore cardflow-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias cardflow

# Encode to base64 (Linux/Mac)
base64 -i cardflow-release.jks > keystore-base64.txt

# Encode to base64 (Windows PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("cardflow-release.jks")) > keystore-base64.txt
```

### iOS Signing Secrets (For App Store Release)

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `IOS_CERTIFICATE_BASE64` | Base64 encoded .p12 certificate | Export from Keychain Access |
| `IOS_CERTIFICATE_PASSWORD` | Certificate password | Password used during export |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64 encoded .mobileprovision | Download from Apple Developer Portal |
| `KEYCHAIN_PASSWORD` | Temporary keychain password | Any secure password |

#### Getting iOS Certificates:

1. **Apple Developer Account**: You need an Apple Developer Program membership ($99/year)

2. **Create Certificate**:
   - Go to [Apple Developer Portal](https://developer.apple.com/account/resources/certificates/list)
   - Create a "Distribution" certificate
   - Download and install in Keychain Access

3. **Export Certificate**:
   ```bash
   # Open Keychain Access, find your certificate, export as .p12
   # Then encode to base64:
   base64 -i certificate.p12 > certificate-base64.txt
   ```

4. **Create Provisioning Profile**:
   - Go to [Provisioning Profiles](https://developer.apple.com/account/resources/profiles/list)
   - Create an "App Store" distribution profile
   - Download the .mobileprovision file
   ```bash
   base64 -i profile.mobileprovision > profile-base64.txt
   ```

5. **Create ExportOptions.plist** (for signed IPA builds):
   Create `ios/ExportOptions.plist`:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>method</key>
       <string>app-store</string>
       <key>teamID</key>
       <string>YOUR_TEAM_ID</string>
       <key>uploadBitcode</key>
       <false/>
       <key>uploadSymbols</key>
       <true/>
   </dict>
   </plist>
   ```

## 📦 Downloading Build Artifacts

After a workflow completes:

1. Go to **Actions** tab in your GitHub repository
2. Click on the completed workflow run
3. Scroll down to **Artifacts** section
4. Download:
   - `android-apk-release` - Contains the APK file
   - `android-appbundle-release` - Contains the AAB file (for Play Store)
   - `ios-ipa-release` - Contains the IPA file

## 🏷️ Creating a Release

To create a full release with both Android and iOS builds:

```bash
# Tag your release
git tag v1.0.0
git push origin v1.0.0
```

This triggers the `release.yml` workflow which:
1. Builds Android APK and App Bundle
2. Builds iOS IPA
3. Creates a GitHub Release with all artifacts attached

## ⚙️ Workflow Configuration

### Customizing Flutter Version

Edit the `FLUTTER_VERSION` environment variable in workflow files:

```yaml
env:
  FLUTTER_VERSION: '3.24.0'  # Change this to your desired version
```

### Customizing Build Types

The workflows support:
- **Debug builds**: For testing (on PRs)
- **Release builds**: For distribution (on main/develop/tags)

## 🔧 Troubleshooting

### Build Fails with "flutter pub get" errors

1. Ensure `pubspec.lock` is committed to git
2. Check that all dependencies are compatible with the Flutter version

### Android build fails

1. Verify `google-services.json` exists or secret is set
2. Check Gradle wrapper version compatibility
3. Ensure Java 17 is being used

### iOS build fails

1. iOS builds require a macOS runner (provided by GitHub)
2. Without code signing, only unsigned IPA is produced
3. For signed builds, ensure all Apple certificates are valid

### Missing artifacts

1. Check the workflow logs for errors
2. Ensure the build completed successfully
3. Artifacts expire after the retention period (default: 30 days)

## 📝 Notes

- **iOS folder**: If the `ios` folder doesn't exist in your repo, the workflow will create it automatically using `flutter create --platforms=ios .`
- **Unsigned IPA**: Without Apple Developer certificates, only unsigned IPAs are created (can't be installed on devices without jailbreak)
- **macOS runners**: iOS builds use GitHub's macOS runners which have limited free minutes

## 🔗 Useful Links

- [Flutter CI/CD Documentation](https://docs.flutter.dev/deployment/cd)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Apple Developer Program](https://developer.apple.com/programs/)
- [Google Play Console](https://play.google.com/console)
