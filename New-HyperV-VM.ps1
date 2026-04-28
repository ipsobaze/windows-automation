#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Erstellt eine neue Hyper-V Virtual Machine.

.DESCRIPTION
    Dieses Skript erstellt eine neue VM auf einem Hyper-V Host mit konfigurierbaren
    Parametern wie Name, RAM, CPU, Festplattengrösse und Netzwerk.

.PARAMETER VMName
    Name der neuen VM (Standard: "NewVM")

.PARAMETER Generation
    VM-Generation: 1 oder 2 (Standard: 2)
    - Generation 1: BIOS, legacy, kompatibel mit älteren OS
    - Generation 2: UEFI, Secure Boot, empfohlen für moderne OS

.PARAMETER MemoryGB
    RAM in GB (Standard: 4)

.PARAMETER CPUCount
    Anzahl virtueller Prozessoren (Standard: 2)

.PARAMETER DiskSizeGB
    Grösse der virtuellen Festplatte in GB (Standard: 60)

.PARAMETER VMPath
    Pfad für VM-Konfigurationsdateien (Standard: C:\Hyper-V\VMs)

.PARAMETER VHDPath
    Pfad für virtuelle Festplatten (Standard: C:\Hyper-V\VHDs)

.PARAMETER SwitchName
    Name des virtuellen Switches (Standard: erster verfügbarer Switch)

.PARAMETER ISOPath
    Optionaler Pfad zu einer ISO-Datei (Boot-Medium)

.PARAMETER DynamicMemory
    Dynamischen Arbeitsspeicher aktivieren (Standard: $false)

.EXAMPLE
    .\New-HyperV-VM.ps1 -VMName "WebServer01" -MemoryGB 8 -CPUCount 4 -DiskSizeGB 100

.EXAMPLE
    .\New-HyperV-VM.ps1 -VMName "TestVM" -Generation 1 -ISOPath "C:\ISOs\ubuntu.iso"
#>

param (
    [string]$VMName       = "NewVM",
    [ValidateSet(1, 2)]
    [int]$Generation      = 2,
    [int]$MemoryGB        = 4,
    [int]$CPUCount        = 2,
    [int]$DiskSizeGB      = 60,
    [string]$VMPath       = "C:\Hyper-V\VMs",
    [string]$VHDPath      = "C:\Hyper-V\VHDs",
    [string]$SwitchName   = "",
    [string]$ISOPath      = "",
    [bool]$DynamicMemory  = $false
)

# ============================================================
# Hilfsfunktionen
# ============================================================

function Write-Step {
    param([string]$Message)
    Write-Host "`n[*] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Failure {
    param([string]$Message)
    Write-Host "[FEHLER] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "     $Message" -ForegroundColor Gray
}

# ============================================================
# Header
# ============================================================

Write-Host "`n=================================================" -ForegroundColor Yellow
Write-Host "   Hyper-V VM Erstellungsskript" -ForegroundColor Yellow
Write-Host "=================================================`n" -ForegroundColor Yellow

# ============================================================
# Voraussetzungen prüfen
# ============================================================

Write-Step "Hyper-V wird geprüft..."
if (-not (Get-Command Get-VM -ErrorAction SilentlyContinue)) {
    Write-Failure "Hyper-V ist nicht installiert oder das PowerShell-Modul ist nicht verfügbar."
    exit 1
}
Write-Success "Hyper-V ist installiert."

# VM-Name auf Duplikat prüfen
Write-Step "Prüfe ob VM-Name bereits existiert..."
if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
    Write-Failure "Eine VM mit dem Namen '$VMName' existiert bereits."
    exit 1
}
Write-Success "VM-Name '$VMName' ist verfügbar."

# ISO prüfen falls angegeben
if ($ISOPath -ne "" -and -not (Test-Path $ISOPath)) {
    Write-Failure "ISO-Datei nicht gefunden: $ISOPath"
    exit 1
}

# Virtuellen Switch bestimmen
Write-Step "Virtuellen Switch bestimmen..."
if ($SwitchName -eq "") {
    $switch = Get-VMSwitch | Select-Object -First 1
    if ($null -eq $switch) {
        Write-Host "     [WARNUNG] Kein virtueller Switch gefunden. VM wird ohne Netzwerk erstellt." -ForegroundColor Yellow
        $SwitchName = $null
    } else {
        $SwitchName = $switch.Name
        Write-Info "Verwende Switch: $SwitchName"
    }
} else {
    if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
        Write-Failure "Switch '$SwitchName' nicht gefunden."
        Write-Info "Verfügbare Switches:"
        Get-VMSwitch | ForEach-Object { Write-Info "  - $($_.Name)" }
        exit 1
    }
    Write-Success "Switch '$SwitchName' gefunden."
}

# ============================================================
# Verzeichnisse erstellen
# ============================================================

Write-Step "Verzeichnisse erstellen..."
foreach ($path in @($VMPath, $VHDPath)) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Write-Info "Erstellt: $path"
    } else {
        Write-Info "Existiert bereits: $path"
    }
}

# ============================================================
# VM erstellen
# ============================================================

$memoryBytes  = $MemoryGB * 1GB
$diskBytes    = $DiskSizeGB * 1GB
$vhdFilePath  = "$VHDPath\$VMName.vhdx"

Write-Step "Virtuelle Festplatte wird erstellt..."
Write-Info "Pfad:   $vhdFilePath"
Write-Info "Grösse: $DiskSizeGB GB"

try {
    New-VHD -Path $vhdFilePath -SizeBytes $diskBytes -Dynamic -ErrorAction Stop | Out-Null
    Write-Success "VHDX erstellt."
} catch {
    Write-Failure "Fehler beim Erstellen der VHDX: $_"
    exit 1
}

Write-Step "VM wird erstellt..."
Write-Info "Name:       $VMName"
Write-Info "Generation: $Generation"
Write-Info "RAM:        $MemoryGB GB"
Write-Info "CPUs:       $CPUCount"
Write-Info "Disk:       $DiskSizeGB GB"

try {
    $vmParams = @{
        Name               = $VMName
        Generation         = $Generation
        MemoryStartupBytes = $memoryBytes
        VHDPath            = $vhdFilePath
        Path               = $VMPath
        ErrorAction        = "Stop"
    }
    if ($SwitchName) { $vmParams["SwitchName"] = $SwitchName }

    $vm = New-VM @vmParams
    Write-Success "VM '$VMName' erstellt."
} catch {
    Write-Failure "Fehler beim Erstellen der VM: $_"
    # Aufräumen: erstellte VHDX löschen
    Remove-Item $vhdFilePath -ErrorAction SilentlyContinue
    exit 1
}

# ============================================================
# VM konfigurieren
# ============================================================

Write-Step "VM wird konfiguriert..."

# CPU
Set-VMProcessor -VMName $VMName -Count $CPUCount
Write-Info "CPUs gesetzt: $CPUCount"

# Dynamischer Arbeitsspeicher
if ($DynamicMemory) {
    Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $true -MinimumBytes (512MB) -MaximumBytes ($memoryBytes * 2)
    Write-Info "Dynamischer Arbeitsspeicher aktiviert (min: 512 MB, max: $($MemoryGB * 2) GB)"
} else {
    Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $false
    Write-Info "Statischer Arbeitsspeicher: $MemoryGB GB"
}

# Secure Boot (nur Generation 2)
if ($Generation -eq 2) {
    Set-VMFirmware -VMName $VMName -EnableSecureBoot On -SecureBootTemplate "MicrosoftUEFICertificateAuthority"
    Write-Info "Secure Boot aktiviert (UEFI)"
}

# ISO einlegen falls angegeben
if ($ISOPath -ne "") {
    Write-Step "ISO wird eingelegt..."
    if ($Generation -eq 2) {
        Add-VMDvdDrive -VMName $VMName -Path $ISOPath
        # Boot-Reihenfolge: DVD zuerst
        $dvd = Get-VMDvdDrive -VMName $VMName
        $vhd = Get-VMHardDiskDrive -VMName $VMName
        Set-VMFirmware -VMName $VMName -BootOrder $dvd, $vhd
    } else {
        Set-VMDvdDrive -VMName $VMName -Path $ISOPath
    }
    Write-Success "ISO eingelegt: $ISOPath"
}

# ============================================================
# Zusammenfassung
# ============================================================

Write-Host "`n=================================================" -ForegroundColor Green
Write-Host " VM erfolgreich erstellt!" -ForegroundColor Green
Write-Host "=================================================`n" -ForegroundColor Green

$createdVM = Get-VM -Name $VMName
Write-Host " Name:       $($createdVM.Name)" -ForegroundColor White
Write-Host " Status:     $($createdVM.State)" -ForegroundColor White
Write-Host " Generation: $Generation" -ForegroundColor White
Write-Host " RAM:        $MemoryGB GB" -ForegroundColor White
Write-Host " CPUs:       $CPUCount" -ForegroundColor White
Write-Host " Disk:       $vhdFilePath" -ForegroundColor White
if ($SwitchName) {
Write-Host " Switch:     $SwitchName" -ForegroundColor White
}
if ($ISOPath -ne "") {
Write-Host " ISO:        $ISOPath" -ForegroundColor White
}

# VM starten?
$answer = Read-Host "`n VM jetzt starten? (j/n)"
if ($answer -match "^[jJyY]") {
    Start-VM -Name $VMName
    Write-Success "VM '$VMName' wurde gestartet."
} else {
    Write-Info "VM kann später mit 'Start-VM -Name $VMName' gestartet werden."
}
