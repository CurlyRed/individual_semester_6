plugins {
    java
    id("org.springframework.boot") version "3.2.5" apply false
    id("io.spring.dependency-management") version "1.1.4" apply false
    id("org.owasp.dependencycheck") version "9.0.9"
    id("org.sonarqube") version "5.0.0.4638"
}

// OWASP Dependency Check configuration
dependencyCheck {
    // Don't fail build - just report vulnerabilities
    failBuildOnCVSS = 11.0f  // CVSS max is 10, so this never fails

    // Output formats
    formats = listOf("HTML", "JSON")

    // Analyze all subprojects
    scanConfigurations = listOf("runtimeClasspath", "compileClasspath")

    // Skip if NVD rate limit hit
    failOnError = false
}

allprojects {
    group = "com.wcd"
    version = "1.0.0-SNAPSHOT"
}

subprojects {
    apply(plugin = "java")
    apply(plugin = "jacoco")

    repositories {
        mavenCentral()
    }

    java {
        toolchain {
            languageVersion.set(JavaLanguageVersion.of(21))
        }
    }

    tasks.withType<Test> {
        useJUnitPlatform()
        finalizedBy(tasks.named("jacocoTestReport"))
    }

    tasks.withType<JacocoReport> {
        reports {
            xml.required.set(true)
            html.required.set(true)
        }
    }
}
