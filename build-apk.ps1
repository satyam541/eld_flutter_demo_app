# Builds a release APK for sideloading on your Android phone.
# Output: build\app\outputs\flutter-apk\app-release.apk
#
# Usage from PowerShell:
#   .\build-apk.ps1
#   .\build-apk.ps1 -PortalUrl "http://192.168.1.50:3000"   # for LAN testing
#
param(
    [string]$PortalUrl = "https://eld-reboot.satyamsuri.com"
)

$ErrorActionPreference = "Stop"

Write-Host "→ Cleaning previous build..." -ForegroundColor Cyan
flutter clean

Write-Host "→ Fetching dependencies..." -ForegroundColor Cyan
flutter pub get

Write-Host "→ Building release APK with PORTAL_URL=$PortalUrl ..." -ForegroundColor Cyan
flutter build apk --release --dart-define=PORTAL_URL=$PortalUrl --split-per-abi

Write-Host ""
Write-Host "Done. APKs are in:" -ForegroundColor Green
Get-ChildItem -Path "build\app\outputs\flutter-apk\*.apk" | ForEach-Object {
    $sizeMB = [math]::Round($_.Length / 1MB, 2)
    Write-Host "    $($_.FullName)  $sizeMB MB"
}
Write-Host ""
Write-Host "Most modern phones need: app-arm64-v8a-release.apk" -ForegroundColor Yellow
Write-Host "  Copy that to your phone (USB / Drive / Telegram-to-self) and tap to install."
Write-Host "  You'll need to allow 'Install unknown apps' for whichever app opened it."
