buildscript {
    configurations.classpath {
        resolutionStrategy.eachDependency {
            when {
                requested.group == "org.jdom" && requested.name == "jdom2" -> {
                    useVersion("2.0.6.1")
                    because("Mitigate CVE-2021-33813 from AGP transitive dependency")
                }

                requested.group == "com.google.protobuf" &&
                    requested.name in setOf(
                        "protobuf-java",
                        "protobuf-javalite",
                        "protobuf-kotlin",
                        "protobuf-kotlin-lite",
                    ) -> {
                    useVersion("3.25.5")
                    because("Mitigate CVE-2024-7254 in AGP/UTP transitive dependencies")
                }
            }
        }
    }
}

// Top-level build file where you can add configuration options common to all sub-projects/modules.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.compose) apply false
}

tasks.whenTaskAdded {
    if (name.contains("ArtProfile")) {
        enabled = false
    }
}
