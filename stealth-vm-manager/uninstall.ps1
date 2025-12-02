# uninstall.ps1 - Desinstalador Completo y Seguro
param([switch]$Force = $false)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "   DESINSTALADOR STEALTH VM MANAGER     " -ForegroundColor White
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar admin
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "ERROR: Debes ejecutar como Administrador" -ForegroundColor Red
    Write-Host "Botón derecho -> Ejecutar como administrador" -ForegroundColor Yellow
    pause
    exit 1
}

# Mostrar qué se eliminará
if (-not $Force) {
    Write-Host "Esto eliminará:" -ForegroundColor Yellow
    Write-Host "1. Servicio: WindowsUpdateAssistant" -ForegroundColor Gray
    Write-Host "2. Tarea programada: WindowsUpdateTask" -ForegroundColor Gray
    Write-Host "3. Carpeta: C:\ProgramData\Microsoft\WindowsUpdate" -ForegroundColor Gray
    Write-Host "4. VirtualBox (opcional)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "NOTA: Tus archivos personales NO se tocarán." -ForegroundColor Green
    Write-Host ""
    
    $confirm = Read-Host "¿Continuar? (escribe 'SI' para confirmar)"
    if ($confirm -ne 'SI') {
        Write-Host "Desinstalación cancelada." -ForegroundColor Yellow
        exit 0
    }
}

# ========== DESINSTALACIÓN ==========
Write-Host "`nIniciando desinstalación..." -ForegroundColor Cyan

# 1. Detener y eliminar servicio
Write-Host "1. Eliminando servicio..." -NoNewline
try {
    Stop-Service "WindowsUpdateAssistant" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    sc.exe delete "WindowsUpdateAssistant" 2>$null
    Write-Host " ✓" -ForegroundColor Green
} catch {
    Write-Host " ✗ (No encontrado)" -ForegroundColor DarkYellow
}

# 2. Eliminar tarea programada
Write-Host "2. Eliminando tarea..." -NoNewline
try {
    Unregister-ScheduledTask -TaskName "WindowsUpdateTask" -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host " ✓" -ForegroundColor Green
} catch {
    Write-Host " ✗ (No encontrada)" -ForegroundColor DarkYellow
}

# 3. Preguntar si eliminar VirtualBox
Write-Host "3. ¿Desinstalar VirtualBox? (S/N)" -ForegroundColor Yellow
$removeVBox = Read-Host "   (Recomendado: S para limpieza completa)"
if ($removeVBox -eq 'S' -or $removeVBox -eq 's') {
    Write-Host "   Desinstalando VirtualBox..." -NoNewline
    try {
        # Método 1: Desinstalador oficial
        $uninstallString = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Oracle VM VirtualBox" -ErrorAction SilentlyContinue).UninstallString
        if ($uninstallString) {
            $uninstallString = $uninstallString -replace "/I", "/x"
            Start-Process "msiexec.exe" -ArgumentList "$uninstallString /qn /norestart" -Wait -NoNewWindow
        }
        
        # Método 2: Forzar eliminación
        Remove-Item "${env:ProgramFiles}\Oracle\VirtualBox" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "${env:ProgramFiles}\Oracle" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host " ✓" -ForegroundColor Green
    } catch {
        Write-Host " ✗ (Ya eliminado o no instalado)" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "   Saltando VirtualBox..." -ForegroundColor Gray
}

# 4. Eliminar carpetas de datos
Write-Host "4. Eliminando archivos..." -NoNewline
$folders = @(
    "C:\ProgramData\Microsoft\WindowsUpdate",
    "C:\ProgramData\Oracle",
    "$env:USERPROFILE\.VirtualBox"
)

$deletedCount = 0
foreach ($folder in $folders) {
    if (Test-Path $folder) {
        Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
        $deletedCount++
    }
}
Write-Host " ✓ ($deletedCount carpetas)" -ForegroundColor Green

# 5. Limpiar registros
Write-Host "5. Limpiando registro..." -NoNewline
$regPaths = @(
    "HKLM:\SYSTEM\CurrentControlSet\Services\WindowsUpdateAssistant",
    "HKLM:\SOFTWARE\Oracle",
    "HKCU:\Software\Oracle"
)

foreach ($path in $regPaths) {
    Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host " ✓" -ForegroundColor Green

# 6. Limpiar archivos temporales
Write-Host "6. Limpiando temporales..." -NoNewline
Remove-Item "$env:TEMP\VirtualBox*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\Oracle*" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host " ✓" -ForegroundColor Green

# ========== FINAL ==========
Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "     DESINSTALACIÓN COMPLETADA ✓         " -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Resumen
Write-Host "Resumen:" -ForegroundColor Yellow
Write-Host "• Servicio eliminado: WindowsUpdateAssistant" -ForegroundColor Gray
Write-Host "• Tarea eliminada: WindowsUpdateTask" -ForegroundColor Gray
Write-Host "• Carpetas eliminadas: $deletedCount" -ForegroundColor Gray
Write-Host "• Registro limpiado" -ForegroundColor Gray
Write-Host ""

# Recomendación
Write-Host "Recomendación:" -ForegroundColor Yellow
Write-Host "Reinicia tu laptop para completar la limpieza." -ForegroundColor Gray
Write-Host ""

# Preguntar por reinicio
$reboot = Read-Host "¿Reiniciar ahora? (S/N)"
if ($reboot -eq 'S' -or $reboot -eq 's') {
    Write-Host "Reiniciando en 5 segundos..." -ForegroundColor Cyan
    Start-Sleep -Seconds 5
    Restart-Computer -Force
} else {
    Write-Host "Reinicia manualmente cuando puedas." -ForegroundColor Yellow
}

pause
