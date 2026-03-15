allprojects {
    repositories {
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/public")
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

fun invokeAndroidDsl(target: Any, methodName: String, vararg args: Any?): Any? {
    val method =
        target.javaClass.methods.firstOrNull { method ->
            method.name == methodName && method.parameterTypes.size == args.size
        }
            ?: return null
    return runCatching { method.invoke(target, *args) }.getOrNull()
}

// AGP 8+ 要求所有 Android 模块声明 namespace。
// 某些三方库（例如旧版 isar_flutter_libs）未声明时，这里兜底补齐，
// 优先读取其 AndroidManifest 的 package 字段，避免改动 pub-cache。
subprojects {
    plugins.withId("com.android.library") {
        val androidExt = project.extensions.findByName("android") ?: return@withId

        // 同时兼容旧 AGP（compileSdkVersion）与新 AGP（setCompileSdk）。
        invokeAndroidDsl(androidExt, "compileSdkVersion", 36)
            ?: invokeAndroidDsl(androidExt, "setCompileSdkVersion", 36)
            ?: invokeAndroidDsl(androidExt, "setCompileSdk", 36)

        val currentNamespace = invokeAndroidDsl(androidExt, "getNamespace") as? String
        if (currentNamespace.isNullOrBlank()) {
            val manifestFile = project.file("src/main/AndroidManifest.xml")
            val manifestPackage =
                if (manifestFile.exists()) {
                    Regex("""package\s*=\s*"([^"]+)"""")
                        .find(manifestFile.readText())
                        ?.groupValues
                        ?.getOrNull(1)
                } else {
                    null
                }
            val fallbackNamespace =
                manifestPackage ?: "local.${project.name.replace('-', '_')}"
            invokeAndroidDsl(androidExt, "setNamespace", fallbackNamespace)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
