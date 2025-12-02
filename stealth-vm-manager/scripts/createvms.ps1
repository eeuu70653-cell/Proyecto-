# create-vm.ps1
param(
    [string]$Name = "default-vm",
    [int]$CPU = 2,
    [int]$RAM = 2048,
    [int]$Disk = 20000,
    [string]$OSType = "Ubuntu_64"
)

$VBoxPath = "${env:ProgramFiles}\Oracle\VirtualBox"
$VMsPath = "${env:ProgramData}\Microsoft\WindowsUpdate\VMs"

# Crear directorio para VM
New-Item -Path "$VMsPath\$Name" -ItemType Directory -Force | Out-Null

# Crear VM
& "$VBoxPath\VBoxManage.exe" createvm --name $Name --ostype $OSType --register --basefolder "$VMsPath"

# Configurar recursos
& "$VBoxPath\VBoxManage.exe" modifyvm $Name --cpus $CPU --memory $RAM --vram 16
& "$VBoxPath\VBoxManage.exe" modifyvm $Name --nic1 bridged --bridgeadapter1 (Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | Select-Object -First 1).Name

# Crear disco
& "$VBoxPath\VBoxManage.exe" createhd --filename "$VMsPath\$Name\$Name.vdi" --size $Disk --format VDI

# Configurar almacenamiento
& "$VBoxPath\VBoxManage.exe" storagectl $Name --name "SATA Controller" --add sata --controller IntelAhci
& "$VBoxPath\VBoxManage.exe" storageattach $Name --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$VMsPath\$Name\$Name.vdi"

# Configurar DVD para instalación (si se necesita)
# & "$VBoxPath\VBoxManage.exe" storageattach $Name --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium "path\to\iso"

# Configurar para inicio headless
& "$VBoxPath\VBoxManage.exe" modifyvm $Name --defaultfrontend headless

Write-Host "VM '$Name' creada exitosamente"
