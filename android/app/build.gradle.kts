plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.sompinger"
    compileSdk = flutter.compileSdkVersion
    
    // Исправление дублирования: оставляем только эту строку
    ndkVersion = "27.0.12077973"  // Фиксированная версия NDK

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"  // Исправленный синтаксис (без toString())
    }

    defaultConfig {
        applicationId = "com.example.sompinger"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Добавленная конфигурация подписи
    signingConfigs {
        create("release") {
            storeFile = file("keystore.jks") // Путь к вашему keystore
            storePassword = "your_password"
            keyAlias = "your_alias"
            keyPassword = "your_password"
        }
    }

    buildTypes {
        release {
            // Используем конфигурацию подписи
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
