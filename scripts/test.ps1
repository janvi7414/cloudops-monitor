$ErrorActionPreference = "Stop"

Write-Host "Running backend tests..."

Set-Location "$PSScriptRoot\..\backend"

npm test
if ($LASTEXITCODE -ne 0) {
    Write-Host "Backend tests failed."
    exit 1
}

Write-Host "Running backend security audit..."

npm audit --audit-level=high
if ($LASTEXITCODE -ne 0) {
    Write-Host "Backend security audit failed."
    exit 1
}

Write-Host "Running frontend build..."

Set-Location "$PSScriptRoot\..\frontend"

npm run build
if ($LASTEXITCODE -ne 0) {
    Write-Host "Frontend build failed."
    exit 1
}

Write-Host "Running frontend security audit..."

npm audit --audit-level=high
if ($LASTEXITCODE -ne 0) {
    Write-Host "Frontend security audit failed."
    exit 1
}

Write-Host "All tests and security checks passed."