plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "jp.lycorp.tritonkit.bridge"
    compileSdk = 34

    defaultConfig {
        applicationId = "jp.lycorp.tritonkit.bridge"
        minSdk = 30
        targetSdk = 34
        versionCode = 1
        versionName = "0.1.0"

        // protocol_version aligns with the wire spec at
        // ai-doc/ANDROID_WIRE_SPEC.md. Bumped to 2: `/a11y_tree_full`
        // may now return a synthetic root with `className =
        // "__tritonkit:multi_window__"` when the app has secondary
        // windows (PopupWindow / dialog / dropdown). Old clients would
        // render the wrapper as an opaque node — bumping forces them
        // to upgrade.
        buildConfigField("int", "PROTOCOL_VERSION", "2")
    }

    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            // Debug-signed by intent: TritonKit (including this bridge) is
            // internal developer tooling — installed via `TritonKit android
            // init` → `adb install` onto an emulator or developer-owned
            // device. The Android debug signing key is public, so this
            // signature carries no authenticity guarantee; that is
            // acceptable because the install channel is trusted (the
            // operator runs `adb` against their own hardware) and the
            // bridge is never distributed through Play or any consumer
            // channel. See `AGENTS.md` → "Distribution posture (developer
            // tool only)". Switch to a real release signing config
            // before any consumer / GA distribution.
            signingConfig = signingConfigs.getByName("debug")
        }
        getByName("debug") {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
    testImplementation("io.mockk:mockk:1.13.10")
}
