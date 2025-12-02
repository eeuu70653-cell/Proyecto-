# cleanup.ps1 - Limpieza mensual de evidencias
$ErrorActionPreference = 'SilentlyContinue'

# Limpiar logs de VirtualBox
Remove-Item "$env:USERPROFILE\.VirtualBox\*.log" -Force

# Limpiar historial de PowerShell
Remove-Item (Get-PSReadlineOption).HistorySavePath -Force -ErrorAction SilentlyContinue

# Limpiar prefetch
Get-ChildItem "$env:SystemRoot\Prefetch\*" | Remove-Item -Force

# Limpiar temp
Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

# Limpiar event logs (solo los relacionados)
wevtutil el | Where-Object {$_ -like "*VirtualBox*"} | ForEach-Object { wevtutil cl $_ }

# Rotar logs propios
$logPath = "$env:ProgramData\Microsoft\WindowsUpdate\logs"
if (Test-Path $logPath) {
    Get-ChildItem $logPath -Filter "*.log" | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-7)} | Remove-Item -Force
}
