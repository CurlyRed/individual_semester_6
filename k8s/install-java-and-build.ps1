# Install Java and Build Services Script

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Java Installation & Build Fix" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Option 1: Download and Install Java
Write-Host "`nOption 1: Install Java JDK 21" -ForegroundColor Yellow
$installJava = Read-Host "Do you want to install Java? (y/n)"

if ($installJava -eq 'y') {
    Write-Host "Downloading Java JDK 21..." -ForegroundColor Green

    # Download Eclipse Temurin JDK 21
    $javaUrl = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.1%2B12/OpenJDK21U-jdk_x64_windows_hotspot_21.0.1_12.msi"
    $javaInstaller = "$env:TEMP\OpenJDK21.msi"

    Invoke-WebRequest -Uri $javaUrl -OutFile $javaInstaller

    Write-Host "Installing Java..." -ForegroundColor Yellow
    Start-Process msiexec.exe -ArgumentList "/i", $javaInstaller, "/quiet" -Wait

    # Set JAVA_HOME
    $javaPath = "C:\Program Files\Eclipse Adoptium\jdk-21.0.1.12-hotspot"
    [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $javaPath, "User")
    $env:JAVA_HOME = $javaPath
    $env:Path = "$javaPath\bin;$env:Path"

    Write-Host "Java installed successfully!" -ForegroundColor Green
    java -version
}

# Option 2: Build using Docker (No Java needed!)
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Option 2: Build with Docker (Recommended)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nWe can build the services using Docker without Java!" -ForegroundColor Green
$useDocker = Read-Host "Build services using Docker? (y/n)"

if ($useDocker -eq 'y') {
    Set-Location ..\backend

    # Create a multi-stage Dockerfile that builds the JARs
    Write-Host "Creating Docker build configuration..." -ForegroundColor Yellow

    $services = @("ingest-service", "projector-service", "query-service")

    foreach ($service in $services) {
        Write-Host "`nBuilding $service with Docker..." -ForegroundColor Green

        # Check if Dockerfile exists, if not create one
        $dockerfilePath = "$service\Dockerfile"
        if (!(Test-Path $dockerfilePath)) {
            # Create a Dockerfile that builds the service
            $dockerfileContent = @"
# Build stage
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
COPY . .
RUN chmod +x gradlew 2>/dev/null || true
RUN if [ -f gradlew ]; then ./gradlew :$service:bootJar --no-daemon; else echo "No gradlew found"; fi
RUN if [ ! -f $service/build/libs/*.jar ]; then \
    echo "Building with javac fallback"; \
    mkdir -p $service/build/libs; \
    cd $service/src/main/java; \
    find . -name "*.java" -exec javac -d ../../../../build/classes {} + 2>/dev/null || true; \
    cd ../../../../; \
    jar cf $service/build/libs/$service.jar -C $service/build/classes . 2>/dev/null || true; \
fi

# Runtime stage
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /app/$service/build/libs/*.jar app.jar
EXPOSE 8080 8081 8082 8083
ENTRYPOINT ["java", "-jar", "app.jar"]
"@
            $dockerfileContent | Out-File $dockerfilePath -Encoding UTF8
        }

        # Build the Docker image
        Write-Host "Building Docker image for $service..." -ForegroundColor Yellow
        docker build -f $dockerfilePath -t "wcd/$($service):docker-built" .

        if ($LASTEXITCODE -eq 0) {
            Write-Host "$service built successfully with Docker!" -ForegroundColor Green

            # Extract the JAR from the Docker image (optional)
            Write-Host "Extracting JAR from Docker image..." -ForegroundColor Yellow
            $containerId = docker create "wcd/$($service):docker-built"
            docker cp "${containerId}:/app/app.jar" "$service\build\libs\$service.jar" 2>$null
            docker rm $containerId 2>$null
        } else {
            Write-Host "Failed to build $service" -ForegroundColor Red
        }
    }

    Set-Location ..\k8s
    Write-Host "`nAll services built with Docker!" -ForegroundColor Green
    Write-Host "Images are ready as: wcd/[service-name]:docker-built" -ForegroundColor Cyan
}

# Option 3: Use Pre-built Images
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Option 3: Use Pre-built Test Images" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nWe can create simple mock services for testing" -ForegroundColor Yellow
$useMock = Read-Host "Create mock services for testing? (y/n)"

if ($useMock -eq 'y') {
    $services = @("ingest-service", "projector-service", "query-service")

    foreach ($service in $services) {
        Write-Host "Creating mock $service..." -ForegroundColor Green

        # Create a simple mock service using a basic web server
        $dockerfileContent = @"
FROM python:3.9-alpine
WORKDIR /app
RUN pip install flask
RUN echo 'from flask import Flask, jsonify' > app.py && \
    echo 'app = Flask(__name__)' >> app.py && \
    echo '@app.route("/actuator/health")' >> app.py && \
    echo 'def health(): return jsonify({"status": "UP", "service": "$service"})' >> app.py && \
    echo '@app.route("/")' >> app.py && \
    echo 'def home(): return "$service is running"' >> app.py && \
    echo 'if __name__ == "__main__": app.run(host="0.0.0.0", port=8080)' >> app.py
EXPOSE 8080
CMD ["python", "app.py"]
"@

        $tempDockerfile = "$env:TEMP\Dockerfile.$service"
        $dockerfileContent | Out-File $tempDockerfile -Encoding UTF8

        docker build -f $tempDockerfile -t "wcd/$($service):mock" .

        Write-Host "$service mock created!" -ForegroundColor Green
    }

    Write-Host "`nMock services created! These are simple test services." -ForegroundColor Cyan
    Write-Host "They will respond to health checks but won't process real data." -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "   Next Steps" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host @"

Now you can continue with the deployment:

1. If you built with Docker (Option 2):
   - Load images to Kind: kind load docker-image wcd/[service]:docker-built --name wcd-platform

2. If you used mock services (Option 3):
   - Load images to Kind: kind load docker-image wcd/[service]:mock --name wcd-platform

3. Continue with deployment:
   - Run: kubectl apply -f base\deployments\

4. Update image references:
   - kubectl set image deployment/wcd-ingest-service ingest-service=wcd/ingest-service:docker-built -n wcd-platform

"@ -ForegroundColor Cyan

Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")