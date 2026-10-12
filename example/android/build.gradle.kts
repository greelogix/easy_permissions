plugins {
    id("com.android.application") apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// API 37 is distributed as android-37.0; align the plugin's integer SDK
// declaration with the installed platform until its upstream DSL is updated.
subprojects {
    if (name == "permission_handler_android") {
        afterEvaluate {
            extensions.configure<com.android.build.gradle.BaseExtension> {
                compileSdkVersion("android-37.0")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
