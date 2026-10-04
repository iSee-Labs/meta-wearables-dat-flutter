// Repositories are declared at project level as well as in settings:
// Flutter's Gradle plugin injects `download.flutter.io` as a project-level
// repository, and Gradle's default `PREFER_PROJECT` mode then ignores the
// settings-level list. Meta's DAT 1.0 artifacts live on Maven Central.
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
