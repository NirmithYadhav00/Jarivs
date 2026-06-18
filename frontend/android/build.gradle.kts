import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

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

    val newSubprojectBuildDir: Directory =
        newBuildDir.dir(project.name)

    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {

    project.evaluationDependsOn(":app")
}

subprojects {

    configurations.all {

        resolutionStrategy {

            // FIXED: was 1.12.0, which is missing
            // EditorInfoCompat.setStylusHandwritingEnabled(...),
            // causing a NoSuchMethodError crash the moment the
            // soft keyboard tries to show (TextInputPlugin.createInputConnection).
            // That method was added in androidx.core 1.13.0.
            force("androidx.core:core-ktx:1.13.1")
            force("androidx.core:core:1.13.1")
            force("androidx.browser:browser:1.8.0")
        }
    }
}

tasks.register<Delete>("clean") {

    delete(rootProject.layout.buildDirectory)
}