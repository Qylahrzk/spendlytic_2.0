plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // ✅ 1. ADD THIS LINE FOR FIREBASE
    id("com.google.gms.google-services") 
}

android {
    namespace = "com.example.spendlytic_v2"
    // ✅ 2. SET COMPILE SDK TO 35
    compileSdk = 35 
    
    // ✅ 3. FIX NDK VERSION
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // ✅ 4. CRITICAL: USE THE OLD ID SO FIREBASE WORKS
        applicationId = "com.example.projectspendlytic" 
        
        // ✅ 5. SET MIN SDK TO 23 (Required by plugins)
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}