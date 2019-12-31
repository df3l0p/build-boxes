Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
trap {
    #Write-Host
    #Write-Host 'whoami from autounattend:'
    #Get-Content C:\whoami-autounattend.txt | ForEach-Object { Write-Host "whoami from autounattend: $_" }
    #Write-Host 'whoami from current WinRM session:'
    #whoami /all >C:\whoami-winrm.txt
    #Get-Content C:\whoami-winrm.txt | ForEach-Object { Write-Host "whoami from winrm: $_" }
    Write-Host
    Write-Host "ERROR: $_"
    Write-Host (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Host (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Write-Host
    Write-Host 'Sleeping for 60m to give you time to look around the virtual machine before self-destruction...'
    Start-Sleep -Seconds (60*60)
    Exit 1
}

# enable TLS 1.1 and 1.2.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol `
    -bor [Net.SecurityProtocolType]::Tls11 `
    -bor [Net.SecurityProtocolType]::Tls12

if (![Environment]::Is64BitProcess) {
    throw 'this must run in a 64-bit PowerShell session'
}

if (!(New-Object System.Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'this must run with Administrator privileges (e.g. in a elevated shell session)'
}

Add-Type -A System.IO.Compression.FileSystem

# install Guest Additions.
$systemVendor = (Get-WmiObject Win32_ComputerSystemProduct Vendor).Vendor
if ($systemVendor -eq 'QEMU') {
    # install drivers.
    if (Test-Path 'C:\Windows\Temp\virtio\virtio.zip') {
        function Install-Driver($path) {
            # trust the driver certificate.
            $catPath = $path.Replace('.inf', '.cat')
            $cerPath = $path.Replace('.inf', '.cer')
            $certificate = (Get-AuthenticodeSignature $catPath).SignerCertificate
            [System.IO.File]::WriteAllBytes($cerPath, $certificate.Export('Cert'))
            Import-Certificate -CertStoreLocation Cert:\LocalMachine\TrustedPublisher $cerPath | Out-Null

            # install the driver.
            pnputil -i -a $path
            if ($LASTEXITCODE) {
                throw "Failed with exit code $LASTEXITCODE"
            }
        }

        [IO.Compression.ZipFile]::ExtractToDirectory('C:\Windows\Temp\virtio\virtio.zip', 'C:\Windows\Temp\virtio')
        $virtioDestinationDirectory = "$env:ProgramFiles\virtio"
        Get-ChildItem -Recurse -File C:\Windows\Temp\virtio\drivers.tmp | ForEach-Object {
            $driverName = $_.Directory.Parent.Parent.Name
            $driverSourceDirectory = $_.Directory
            $driverDestinationDirectory = "$virtioDestinationDirectory\$driverName"
            if (Test-Path $driverDestinationDirectory) {
                return
            }
            Write-Host "Installing the $driverName driver..."
            mkdir -Force $driverDestinationDirectory | Out-Null
            Copy-Item "$driverSourceDirectory\*" $driverDestinationDirectory
            Install-Driver (Resolve-Path "$driverDestinationDirectory\*.inf").Path
        }

        Write-Host 'Installing the Balloon service...'
        &"$virtioDestinationDirectory\Balloon\blnsvr.exe" -i
    }

    # install qemu-qa.
    $qemuAgentSetupUrl = "http://$env:PACKER_HTTP_ADDR/drivers/guest-agent/qemu-ga-x64.msi"
    $qemuAgentSetup = "$env:TEMP\qemu-ga-x64.msi"
    Write-Host "Downloading the qemu-kvm Guest Agent from $qemuAgentSetupUrl..."
    Invoke-WebRequest $qemuAgentSetupUrl -OutFile $qemuAgentSetup
    Write-Host 'Installing the qemu-kvm Guest Agent...'
    msiexec.exe /i $qemuAgentSetup /qn | Out-String -Stream

    # install spice-vdagent.
    $spiceAgentZipUrl = 'https://www.spice-space.org/download/windows/vdagent/vdagent-win-0.9.0/vdagent-win-0.9.0-x64.zip'
    $spiceAgentZip = "$env:TEMP\vdagent-win-0.9.0-x64.zip"
    $spiceAgentDestination = "C:\Program Files\spice-vdagent"
    Write-Host "Downloading the spice-vdagent from $spiceAgentZipUrl..."
    Invoke-WebRequest $spiceAgentZipUrl -OutFile $spiceAgentZip
    Write-Host 'Installing the spice-vdagent...'
    [IO.Compression.ZipFile]::ExtractToDirectory($spiceAgentZip, $spiceAgentDestination)
    Move-Item "$spiceAgentDestination\vdagent-win-*\*" $spiceAgentDestination
    Get-ChildItem "$spiceAgentDestination\vdagent-win-*" -Recurse | Remove-Item -Force -Recurse
    Remove-Item -Force "$spiceAgentDestination\vdagent-win-*"
    &"$spiceAgentDestination\vdservice.exe" install | Out-String -Stream # NB the logs are inside C:\Windows\Temp
    Start-Service vdservice
} elseif ($systemVendor -eq 'innotek GmbH') {
    Write-Host 'Importing the Oracle (for VirtualBox) certificate as a Trusted Publisher...'
    E:\cert\VBoxCertUtil.exe add-trusted-publisher E:\cert\vbox-sha1.cer
    if ($LASTEXITCODE) {
        throw "failed to import certificate with exit code $LASTEXITCODE"
    }

    Write-Host 'Installing the VirtualBox Guest Additions...'
    E:\VBoxWindowsAdditions-amd64.exe /S | Out-String -Stream
    if ($LASTEXITCODE) {
        throw "failed to install with exit code $LASTEXITCODE. Check the logs at C:\Program Files\Oracle\VirtualBox Guest Additions\install.log."
    }
} elseif ($systemVendor -eq 'VMware, Inc.') {
    Write-Output 'Installing VMware Tools...'
    # silent install without rebooting.
    E:\setup64.exe /s /v '/qn reboot=r' `
        | Out-String -Stream
} else {
    throw "Cannot install Guest Additions: Unsupported system ($systemVendor)."
}