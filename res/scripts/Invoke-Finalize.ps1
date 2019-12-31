[CmdletBinding()]
<#
.DESCRIPTION

    This cmdlet create and setup the last elements required to sysprep the VM.
    It initializes the shutdown commands on $packerWindowsDir and initializes
    the first boot commands that will be executed after the VM has been booted
    (after the sysprep).

    A few notes about the finaliation.
    when using the images in Vagrant for example, on the first boot of the sysprep, 
    Vagrant will detect that WinRM is up and start connecting, and then the machine 
    will restart. This will make Vagrant think the machine has failed or isn’t in 
    the correct state.

    The trick to this is having WinRM blocked by the fw until the very last moment, 
    after the initial sysprep reboot.

    To open the fw after the boot, the idea is to drop scripts on a specific path
    that windows will execute a first boot
    https://technet.microsoft.com/en-us/library/cc766314(v=ws.10).aspx
    
.PARAMATER packerWindowsDir
    Base dir to store the finale answer file and the .bat to shutdown and finalize the
    build of the VM

#>

Param(
    $packerWindowsDir = 'C:\Windows\packer'
)

Function Initialize-ShutdownCommands
{
    Param(
        [String] $packerWindowsDir,
        [String] $shutdownCmd = @"
netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new action=block
C:/windows/system32/sysprep/sysprep.exe /generalize /oobe /unattend:C:/Windows/packer/unattended.xml /quiet /shutdown
"@,
        [String] $unattendedXML = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="generalize">
        <component name="Microsoft-Windows-Security-SPP" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SkipRearm>1</SkipRearm>
        </component>
        <!--
        <component name="Microsoft-Windows-PnpSysprep" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <PersistAllDeviceInstalls>false</PersistAllDeviceInstalls>
            <DoNotCleanUpNonPresentDevices>false</DoNotCleanUpNonPresentDevices>
        </component>
        -->
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <ProtectYourPC>3</ProtectYourPC>
                <NetworkLocation>Work</NetworkLocation>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <SkipUserOOBE>true</SkipUserOOBE>
                <SkipMachineOOBE>true</SkipMachineOOBE>
            </OOBE>
            <AutoLogon>
                <Password>
                    <Value>vagrant</Value>
                    <PlainText>true</PlainText>
                </Password>
                <Enabled>true</Enabled>
                <LogonCount>1</LogonCount>
                <Username>vagrant</Username>
            </AutoLogon>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>win-vagrant</ComputerName>
            <CopyProfile>false</CopyProfile>
        </component>
    </settings>
</unattend>
"@
    )
    Set-Content -Path "$($packerWindowsDir)\PackerShutdown.bat" -Value $shutdownCmd
    Set-Content -Path "$($packerWindowsDir)\unattended.xml" -Value $unattendedXML
}

Function Initialize-FirstBootCommands
{
    Param(
        [String] $setupComplete = @"
netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new action=allow
"@
    )
    New-Item -Path 'C:\Windows\Setup\Scripts' -ItemType Directory -Force
    Set-Content -path "C:\Windows\Setup\Scripts\SetupComplete.cmd" -Value $setupComplete
}

Function Set-WinrmDelayedAuto
{
    <#
    Not working at the moment
    #>
    if ($os -like "*Windows 10*") {
        Write-Host "[+] Setting winrm startup to delayed-auto"
        $cmdArgs = @('config', 'WinRM', 'start=delayed-auto')
        sc.exe $cmdArgs
    }
}

New-Item -Path $packerWindowsDir -ItemType Directory -Force

Initialize-ShutdownCommands -packerWindowsDir $packerWindowsDir
Initialize-FirstBootCommands
#Set-WinrmDelayedAuto