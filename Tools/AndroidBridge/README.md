# tritonkit-android-bridge

Kotlin Android app that runs an in-process `AccessibilityService` + HTTP server inside the device, driven from the host by the TritonKit CLI over `adb forward`.

## Building

Prerequisites:
- Android SDK with platform-tools + `compileSdk=34` installed, and `$ANDROID_HOME` (or `$ANDROID_SDK_ROOT`) set.
- JDK 17–21. Android Studio's bundled JBR (21) works; `brew install openjdk@17` also works. JDK 22+ is rejected by the bundled Gradle 8.7 with a cryptic version error.
- Gradle wrapper is committed at `Tools/AndroidBridge/gradlew`; no need to install Gradle system-wide.

To produce the debug-signed release APK used by `triton device bridge install`:

```bash
cd Tools/AndroidBridge
./gradlew :app:assembleRelease
```

The APK is written to `app/build/outputs/apk/release/app-release.apk`.

## Layout

```
Tools/AndroidBridge/
├── build.gradle.kts          # Top-level plugins
├── settings.gradle.kts       # `:app` include
├── gradlew                   # Wrapper
├── gradle/wrapper/           # Gradle wrapper jar + properties
└── app/
    ├── build.gradle.kts      # Android app module
    └── src/main/
        ├── AndroidManifest.xml
        ├── res/
        │   ├── xml/accessibility_service_config.xml
        │   └── xml/data_extraction_rules.xml
        └── java/jp/lycorp/tritonkit/bridge/
            ├── config/AuthManager.kt              # Bearer token mint + persist
            ├── handler/                           # One file per verb family
            │   ├── CaptureHandler.kt              # /screenshot
            │   ├── GestureHandler.kt              # /swipe, /gesture
            │   ├── InputHandler.kt                # /keyboard/input, /keyboard/key
            │   ├── KeyboardStateHandler.kt        # /keyboard/state
            │   ├── PasteHandler.kt                # /paste
            │   └── TreeHandler.kt                 # /a11y_tree_full
            ├── model/ElementNode.kt               # Wire shape for tree responses
            ├── server/                            # Raw HTTP server
            │   ├── ActionRouter.kt                # (method, path) dispatch + auth
            │   ├── HttpResponse.kt
            │   └── HttpServer.kt                  # ServerSocket accept-loop
            └── service/
                ├── BridgeKeepAliveService.kt      # Foreground keep-alive
                ├── TritonKitAccessibilityService.kt  # A11y service lifecycle
                └── TritonKitContentProvider.kt       # adb-shell-gated bootstrap
```

## Test

```bash
cd Tools/AndroidBridge
./gradlew :app:testReleaseUnitTest
```
