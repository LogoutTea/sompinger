import com.android.build.gradle.BaseExtension

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.3.0") // Проверьте актуальную версию
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    afterEvaluate { project ->
        // Проверяем наличие Android плагина
        val hasAndroidPlugin = project.plugins.hasPlugin("com.android.application") || 
                              project.plugins.hasPlugin("com.android.library")
        
        if (hasAndroidPlugin) {
            project.extensions.configure<BaseExtension>("android") {
                compileSdkVersion(34)  // Исправленное присвоение через функцию
                
                defaultConfig {
                    minSdk = 21
                    targetSdk = 34
                }
            }
        }
    }
}
