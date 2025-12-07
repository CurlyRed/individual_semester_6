# Comprehensive Verification and Setup Script for WCD Platform
# This script verifies everything before attempting deployment

$ErrorActionPreference = "Continue"
$script:hasErrors = $false

# Colors
function Write-Success { Write-Host "✓ $args" -ForegroundColor Green }
function Write-Error { Write-Host "✗ $args" -ForegroundColor Red; $script:hasErrors = $true }
function Write-Warning { Write-Host "⚠ $args" -ForegroundColor Yellow }
function Write-Info { Write-Host "→ $args" -ForegroundColor Cyan }
function Write-Section {
    Write-Host "`n========================================" -ForegroundColor Blue
    Write-Host "  $args" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
}

# Start verification
Write-Section "WCD Platform - Complete Verification"
$startTime = Get-Date

# 1. Check System Requirements
Write-Section "1. System Requirements"

# Check Docker
Write-Info "Checking Docker..."
try {
    $dockerVersion = docker version --format '{{.Server.Version}}'
    if ($dockerVersion) {
        Write-Success "Docker installed: v$dockerVersion"

        # Check Docker is running
        docker ps | Out-Null
        Write-Success "Docker daemon is running"

        # Check Docker resources
        $dockerInfo = docker system info 2>$null | Select-String "CPUs|Total Memory"
        Write-Info "Docker resources: $dockerInfo"
    }
} catch {
    Write-Error "Docker is not running or not installed"
    Write-Info "Please start Docker Desktop"
    exit 1
}

# Check available disk space
$disk = Get-PSDrive C
$freeGB = [math]::Round($disk.Free / 1GB, 2)
if ($freeGB -lt 10) {
    Write-Warning "Low disk space: ${freeGB}GB free (recommend 20GB+)"
} else {
    Write-Success "Disk space: ${freeGB}GB free"
}

# Check memory
$totalRAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
Write-Info "System RAM: ${totalRAM}GB"
if ($totalRAM -lt 8) {
    Write-Warning "Low RAM: ${totalRAM}GB (recommend 8GB+ for Kind)"
}

# 2. Check Tools Installation
Write-Section "2. Tools Installation"

# Check kubectl
try {
    $kubectlVersion = kubectl version --client -o json | ConvertFrom-Json
    Write-Success "kubectl installed: $($kubectlVersion.clientVersion.gitVersion)"
} catch {
    Write-Warning "kubectl not found - will install"
    $installKubectl = $true
}

# Check Kind
try {
    $kindVersion = kind version
    Write-Success "Kind installed: $kindVersion"
} catch {
    Write-Warning "Kind not found - will install"
    $installKind = $true
}

# Check Git
try {
    $gitVersion = git --version
    Write-Success "Git installed: $gitVersion"
} catch {
    Write-Warning "Git not found"
}

# 3. Check Project Structure
Write-Section "3. Project Structure"

# Get current location
$currentPath = Get-Location
Write-Info "Current directory: $currentPath"

# Verify we're in k8s directory
if ($currentPath.Path -notlike "*\k8s") {
    Write-Warning "Not in k8s directory. Attempting to navigate..."
    if (Test-Path "k8s") {
        Set-Location k8s
        Write-Success "Navigated to k8s directory"
    } else {
        Write-Error "k8s directory not found"
    }
}

# Check backend directory
$backendPath = "..\backend"
if (Test-Path $backendPath) {
    Write-Success "Backend directory found"

    # List backend contents
    Write-Info "Backend structure:"
    $backendItems = Get-ChildItem $backendPath -Name
    foreach ($item in $backendItems) {
        Write-Host "    - $item" -ForegroundColor Gray
    }

    # Check for gradlew
    $gradlewBat = "$backendPath\gradlew.bat"
    $gradlewSh = "$backendPath\gradlew"

    if (Test-Path $gradlewBat) {
        Write-Success "gradlew.bat found"
    } else {
        Write-Warning "gradlew.bat not found"
        $needsGradleWrapper = $true
    }

    if (Test-Path $gradlewSh) {
        Write-Success "gradlew (Unix) found"
    } else {
        Write-Warning "gradlew (Unix) not found"
    }

    # Check for gradle wrapper jar
    $wrapperJar = "$backendPath\gradle\wrapper\gradle-wrapper.jar"
    if (Test-Path $wrapperJar) {
        Write-Success "gradle-wrapper.jar found"
    } else {
        Write-Warning "gradle-wrapper.jar not found"
        $needsGradleWrapper = $true
    }

    # Check for services
    $services = @("ingest-service", "projector-service", "query-service")
    foreach ($service in $services) {
        if (Test-Path "$backendPath\$service") {
            Write-Success "$service directory found"

            # Check for Dockerfile
            if (Test-Path "$backendPath\$service\Dockerfile") {
                Write-Success "  - Dockerfile found"
            } else {
                Write-Warning "  - Dockerfile missing"
            }

            # Check for source code
            $srcPath = "$backendPath\$service\src\main"
            if (Test-Path $srcPath) {
                Write-Success "  - Source code found"
            } else {
                Write-Warning "  - Source code missing"
            }
        } else {
            Write-Error "$service directory not found"
        }
    }
} else {
    Write-Error "Backend directory not found at $backendPath"
}

# Check k8s manifests
Write-Info "`nKubernetes manifests:"
$k8sItems = Get-ChildItem "base" -Recurse -Filter "*.yaml" 2>$null | Select-Object -First 10
foreach ($item in $k8sItems) {
    Write-Host "    - $($item.FullName.Replace($currentPath, '.'))" -ForegroundColor Gray
}

# 4. Check for Blocking Processes
Write-Section "4. Port Availability"

$requiredPorts = @(6443, 80, 443, 30000, 30001, 30002, 8081, 8083)
$blockedPorts = @()

foreach ($port in $requiredPorts) {
    $tcpConnection = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if ($tcpConnection) {
        Write-Warning "Port $port is in use by PID: $($tcpConnection.OwningProcess)"
        $blockedPorts += $port

        # Try to identify the process
        try {
            $process = Get-Process -Id $tcpConnection.OwningProcess -ErrorAction SilentlyContinue
            Write-Info "  Process: $($process.ProcessName)"
        } catch {}
    } else {
        Write-Success "Port $port is available"
    }
}

# 5. Check Existing Docker/Kind Resources
Write-Section "5. Existing Resources"

# Check for existing Kind clusters
Write-Info "Checking for existing Kind clusters..."
$existingClusters = kind get clusters 2>$null
if ($existingClusters) {
    Write-Warning "Found existing Kind clusters:"
    foreach ($cluster in $existingClusters) {
        Write-Host "    - $cluster" -ForegroundColor Yellow
    }
    $cleanupNeeded = $true
} else {
    Write-Success "No existing Kind clusters"
}

# Check for Docker containers
$kindContainers = docker ps -a --filter "name=kind" --format "table {{.Names}}\t{{.Status}}"
if ($kindContainers -and $kindContainers.Count -gt 1) {
    Write-Warning "Found Kind-related containers:"
    Write-Host $kindContainers -ForegroundColor Yellow
    $cleanupNeeded = $true
}

# 6. Check Java/Gradle Build Requirements
Write-Section "6. Build Requirements"

# Check Java
try {
    $javaVersion = java -version 2>&1 | Select-String "version"
    Write-Success "Java found: $javaVersion"
} catch {
    Write-Warning "Java not found - Docker build will handle this"
}

# Check if services are already built
Write-Info "Checking for existing JAR files..."
if (Test-Path $backendPath) {
    foreach ($service in @("ingest-service", "projector-service", "query-service")) {
        $jarPath = "$backendPath\$service\build\libs"
        if (Test-Path $jarPath) {
            $jars = Get-ChildItem "$jarPath\*.jar" 2>$null
            if ($jars) {
                Write-Success "$service JAR found: $($jars[0].Name)"
            } else {
                Write-Info "$service JAR not built yet"
                $needsBuild = $true
            }
        } else {
            Write-Info "$service not built yet"
            $needsBuild = $true
        }
    }
}

# 7. Summary and Recommendations
Write-Section "Verification Summary"

if ($script:hasErrors) {
    Write-Error "Critical issues found that need to be fixed"
} else {
    Write-Success "No critical issues found"
}

Write-Host "`nActions needed:" -ForegroundColor Yellow

if ($installKubectl) {
    Write-Host "  1. Install kubectl" -ForegroundColor Yellow
}

if ($installKind) {
    Write-Host "  2. Install Kind" -ForegroundColor Yellow
}

if ($needsGradleWrapper) {
    Write-Host "  3. Create Gradle wrapper" -ForegroundColor Yellow
}

if ($needsBuild) {
    Write-Host "  4. Build Java services" -ForegroundColor Yellow
}

if ($cleanupNeeded) {
    Write-Host "  5. Clean up existing Kind resources" -ForegroundColor Yellow
}

if ($blockedPorts.Count -gt 0) {
    Write-Host "  6. Free up blocked ports: $($blockedPorts -join ', ')" -ForegroundColor Yellow
}

# 8. Ask to proceed with fixes
Write-Section "Auto-Fix Available"

$continue = Read-Host "`nDo you want me to automatically fix these issues? (y/n)"
if ($continue -ne 'y') {
    Write-Info "Exiting. Please fix issues manually and run again."
    exit 0
}

# 9. Apply Fixes
Write-Section "Applying Fixes"

# Fix 1: Install missing tools
if ($installKubectl) {
    Write-Info "Installing kubectl..."
    $kubectlUrl = "https://dl.k8s.io/release/v1.29.0/bin/windows/amd64/kubectl.exe"
    $installPath = "C:\tools"
    if (!(Test-Path $installPath)) {
        New-Item -ItemType Directory -Path $installPath -Force | Out-Null
    }
    Invoke-WebRequest -Uri $kubectlUrl -OutFile "$installPath\kubectl.exe"
    Write-Success "kubectl installed to $installPath"
}

if ($installKind) {
    Write-Info "Installing Kind..."
    $kindUrl = "https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64"
    $installPath = "C:\tools"
    Invoke-WebRequest -Uri $kindUrl -OutFile "$installPath\kind.exe"
    Write-Success "Kind installed to $installPath"
}

# Fix 2: Clean up existing resources
if ($cleanupNeeded) {
    Write-Info "Cleaning up existing Kind resources..."
    kind delete clusters --all 2>$null
    docker ps -aq --filter "name=kind" | ForEach-Object {
        docker stop $_ 2>$null
        docker rm $_ 2>$null
    }
    Write-Success "Cleanup complete"
}

# Fix 3: Free up ports
if ($blockedPorts.Count -gt 0) {
    Write-Info "Attempting to free up ports..."
    foreach ($port in $blockedPorts) {
        $tcpConnection = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
        if ($tcpConnection) {
            $process = Get-Process -Id $tcpConnection.OwningProcess -ErrorAction SilentlyContinue
            if ($process -and $process.ProcessName -like "*kind*" -or $process.ProcessName -like "*docker*") {
                try {
                    Stop-Process -Id $tcpConnection.OwningProcess -Force
                    Write-Success "Stopped process on port $port"
                } catch {
                    Write-Warning "Could not stop process on port $port"
                }
            }
        }
    }
}

# Fix 4: Create Gradle wrapper if needed
if ($needsGradleWrapper) {
    Write-Info "Creating Gradle wrapper..."
    Set-Location $backendPath

    # Download gradle wrapper
    $wrapperDir = "gradle\wrapper"
    if (!(Test-Path $wrapperDir)) {
        New-Item -ItemType Directory -Path $wrapperDir -Force | Out-Null
    }

    # Download wrapper files
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gradle/gradle/v8.5.0/gradle/wrapper/gradle-wrapper.jar" `
        -OutFile "$wrapperDir\gradle-wrapper.jar"

    # Create properties file
    @"
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https://services.gradle.org/distributions/gradle-8.5-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
"@ | Out-File -FilePath "$wrapperDir\gradle-wrapper.properties" -Encoding UTF8

    # Download gradlew scripts
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gradle/gradle/v8.5.0/gradlew.bat" -OutFile "gradlew.bat"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gradle/gradle/v8.5.0/gradlew" -OutFile "gradlew"

    Write-Success "Gradle wrapper created"
    Set-Location ..\k8s
}

# Fix 5: Build services if needed
if ($needsBuild -or $needsGradleWrapper) {
    Write-Info "Building Java services..."
    Set-Location $backendPath

    if (Test-Path "gradlew.bat") {
        Write-Info "Running Gradle build..."
        .\gradlew.bat clean build -x test

        # Verify JARs were created
        foreach ($service in @("ingest-service", "projector-service", "query-service")) {
            $jar = Get-ChildItem "$service\build\libs\*.jar" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($jar) {
                Write-Success "$service built: $($jar.Name)"
            } else {
                Write-Error "$service build failed"
            }
        }
    } else {
        Write-Error "gradlew.bat still not found"
    }

    Set-Location ..\k8s
}

# 10. Final Status
Write-Section "Final Verification"

$ready = $true

# Re-check critical components
if (!(docker ps 2>$null)) {
    Write-Error "Docker is not running"
    $ready = $false
}

if (!(kind version 2>$null)) {
    Write-Error "Kind is not available"
    $ready = $false
}

if (!(kubectl version --client 2>$null)) {
    Write-Error "kubectl is not available"
    $ready = $false
}

if ($ready) {
    Write-Success "System is ready for deployment!"
    Write-Host "`nNext steps:" -ForegroundColor Green
    Write-Host "  1. Run: .\setup-kind-simple.ps1" -ForegroundColor Green
    Write-Host "  2. Run: .\build-and-deploy.ps1" -ForegroundColor Green
} else {
    Write-Error "System is not ready. Please fix the issues above."
}

$endTime = Get-Date
$duration = $endTime - $startTime
Write-Host "`nVerification completed in $($duration.TotalSeconds) seconds" -ForegroundColor Cyan