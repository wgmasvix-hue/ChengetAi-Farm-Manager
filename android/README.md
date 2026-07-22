# ChengetAi Farm — Android app

A lightweight Android app that wraps the ChengetAi Farm Manager platform
(`farm.chengetailabs.co.zw`). On first launch the user enters their farm
name (their tenant subdomain) and the app opens their private portal
full-screen, with support for:

- GPS location (for farm mapping)
- Photo/file uploads on records
- Android back-button navigation
- Remembering the chosen farm (changeable via the menu)

## Getting the APK

Every push that touches `android/` triggers the
[Build Android APK](../.github/workflows/android-apk.yml) GitHub Actions
workflow, which builds the app and attaches `ChengetAi-Farm.apk` to the
**app-latest** release on the repository's Releases page.

Download it on an Android phone (8.0+), open the file, and allow
installation from unknown sources when prompted.

## Building locally

With the Android SDK installed:

```sh
gradle -p android assembleDebug
# APK: android/app/build/outputs/apk/debug/app-debug.apk
```

## Play Store

The CI build is signed with a debug key, which is fine for direct (APK)
distribution. Publishing to the Google Play Store additionally requires a
Play developer account and a proper release signing key configured in the
build.
