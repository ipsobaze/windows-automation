#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Setzt Zeitzone, Land und Regionalformat auf Schweiz (Deutsch).
#>

# ============================================================
# Zeitzone
# ============================================================
Write-Host "[*] Setze Zeitzone auf Mitteleuropäische Zeit..." -ForegroundColor Cyan
Set-TimeZone -Id "W. Europe Standard Time"
Write-Host "[OK] Zeitzone gesetzt: $(Get-TimeZone | Select-Object -ExpandProperty DisplayName)" -ForegroundColor Green

# ============================================================
# Land / Region = Schweiz (GeoID 223)
# ============================================================
Write-Host "[*] Setze Land auf Schweiz..." -ForegroundColor Cyan
Set-WinHomeLocation -GeoId 223
Write-Host "[OK] Land gesetzt: Schweiz" -ForegroundColor Green

# ============================================================
# Regionalformat = Deutsch (Schweiz)
# ============================================================
Write-Host "[*] Setze Regionalformat auf Deutsch (Schweiz)..." -ForegroundColor Cyan
Set-WinSystemLocale -SystemLocale "de-CH"
Set-Culture -CultureInfo "de-CH"
Write-Host "[OK] Regionalformat gesetzt: Deutsch (Schweiz)" -ForegroundColor Green

# ============================================================
# Zusammenfassung
# ============================================================
Write-Host "`n=================================================" -ForegroundColor Yellow
Write-Host " Regionseinstellungen erfolgreich gesetzt!" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Yellow
Write-Host " Zeitzone:       $(Get-TimeZone | Select-Object -ExpandProperty Id)"
Write-Host " Land (GeoID):   $(Get-WinHomeLocation | Select-Object -ExpandProperty GeoId) (Schweiz)"
Write-Host " Regionalformat: $(Get-Culture | Select-Object -ExpandProperty Name) (Deutsch Schweiz)"
Write-Host "`n Hinweis: Ein Neustart kann nötig sein damit alle Änderungen wirksam werden." -ForegroundColor Yellow
