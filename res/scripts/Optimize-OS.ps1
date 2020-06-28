[CmdletBinding()]
<#
.DESCRIPTION
    This cmdlet optimize the OS by:
    - Setting local account properties (password expiration, enable accounts, ...)
    - Disable autologin
    - Disable APIPA (network)
    - Disable IPv6
    - Disable hibernation
    - Set power plan to high performance
    - Execute multiple debloat scripts available on githubs
    

.PARAMATER 

#>
Param(

)

Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
trap {
    Write-Host
    Write-Host "ERROR: $_"
    Write-Host (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Host (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Write-Host
    Write-Host 'Sleeping for 60m to give you time to look around the virtual machine before self-destruction...'
    Start-Sleep -Seconds (60*60)
    Exit 1
}


Function Set-LocalAccountsProperties
{
    Param(
        $accounts = @("vagrant", "administrator")
    )
    Function Set-LocalAccountProperties
    {
        Param(
            [String] $accountName,
            $AdsScript              = 0x00001,
            $AdsAccountDisable      = 0x00002,
            $AdsNormalAccount       = 0x00200,
            $AdsDontExpirePassword  = 0x10000
        )
        Write-Host "Setting the $accountName account properties..."
        $account = [ADSI]"WinNT://./$accountName"
        $account.Userflags = $AdsNormalAccount -bor $AdsDontExpirePassword
        $account.SetInfo()
    }

    foreach ($account in $accounts){
        Set-LocalAccountProperties -accountName $account
    }
}

Function Disable-AutoLogon
{
    Param(
    )
    Write-Host 'Disabling auto logon...'
    $autoLogonKeyPath = 'HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    Set-ItemProperty -Path $autoLogonKeyPath -Name AutoAdminLogon -Value 0
    @('DefaultDomainName', 'DefaultUserName', 'DefaultPassword') | ForEach-Object {
        Remove-ItemProperty -Path $autoLogonKeyPath -Name $_ -ErrorAction SilentlyContinue
    }
}

Function Disable-APIPA
{
    Write-Host 'Disabling Automatic Private IP Addressing (APIPA)...'
    Set-ItemProperty `
        -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' `
        -Name IPAutoconfigurationEnabled `
        -Value 0
}

Function Disable-IPv6
{
    Param(

    )
    Write-Host 'Disabling IPv6...'
    Set-ItemProperty `
    -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' `
    -Name DisabledComponents `
    -Value 0xff
}

Function Disable-Hibernation
{
    Param(
    )
    Write-Host 'Disabling hibernation...'
    powercfg /hibernate off
}

Function Set-PowerPlanToHighPerformance
{
    Param(
    )
    Write-Host 'Setting the power plan to high performance...'
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
}

Function Disable-BootManager
{
    Param(

    )
    Write-Host 'Disabling the Windows Boot Manager menu...'
    # NB to have the menu show with a lower timeout, run this instead: bcdedit /timeout 2
    #    NB with a timeout of 2 you can still press F8 to show the boot manager menu.
    bcdedit /set '{bootmgr}' displaybootmenu no
}

Function Unlock-WindowsWithW4RH4WK
{
    Param(
        
        [Array] $scripts = @(
            "block-telemetry.ps1",
            #"disable-services.ps1",
            #"disable-windows-defender.ps1",
            #"fix-privacy-settings.ps1",
            "optimize-user-interface.ps1",
            "remove-default-apps.ps1"
        )

    )
    $os = (gwmi win32_operatingsystem).caption
    # We remove windows defender if it is a server
    if ($os -notlike "*Windows 10*") {
        $scripts = @(
            "block-telemetry.ps1",
            "optimize-user-interface.ps1"
            #"remove-default-apps.ps1",
        )
    }
    # If hyperv is the hypervisor, then we do not debloat windows (things might be broken)
    if ($env:PACKER_BUILDER_TYPE -And $($env:PACKER_BUILDER_TYPE).startsWith("hyperv")) {
        Write-Host Skip debloat steps in Hyper-V build
        return
    }
    
    Write-Host "Downloading debloat zip"
    # GitHub requires TLS 1.2 as of 2/1/2018
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $url="https://github.com/W4RH4WK/Debloat-Windows-10/archive/master.zip"
    (New-Object System.Net.WebClient).DownloadFile($url, "$env:TEMP\debloat.zip")
    Expand-Archive -Path $env:TEMP\debloat.zip -DestinationPath $env:TEMP -Force

    foreach ($script in $scripts){
        . $env:TEMP\Debloat-Windows-10-master\scripts\$script 
    }

}

Function Unlock-WindowsWithSycnex
{
    Param(
        [Array] $scriptArgs = @('-Debloat', '-Sysprep')
    )
    # If hyperv is the hypervisor, then we do not debloat windows (things might be broken)
    if ($env:PACKER_BUILDER_TYPE -And $($env:PACKER_BUILDER_TYPE).startsWith("hyperv")) {
        Write-Host Skip debloat steps in Hyper-V build
        return
    }

    $os = (gwmi win32_operatingsystem).caption
    # Stop execution if it is not a windows 10 (not working on windows server)
    if ($os -notlike "*Windows 10*") {
        Write-Host "[+] Skiping Unlock-depWindowsWithSycnexoad - windows 10 not detected"
        return
    }
    
    Write-Host "Downloading debloat zip"
    # GitHub requires TLS 1.2 as of 2/1/2018
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $url="https://github.com/Sycnex/Windows10Debloater/archive/master.zip"
    (New-Object System.Net.WebClient).DownloadFile($url, "$env:TEMP\debloat.zip")
    Expand-Archive -Path $env:TEMP\debloat.zip -DestinationPath $env:TEMP -Force

    Write-host "Running debloating script"
    . $env:TEMP\Windows10Debloater-master\Windows10SysPrepDebloater.ps1 $scriptArgs

}

Set-LocalAccountsProperties
Disable-AutoLogon
Disable-APIPA
Disable-IPv6
Disable-Hibernation
Set-PowerPlanToHighPerformance
Disable-BootManager
Unlock-WindowsWithW4RH4WK
# todo: bug Removing CloudStore from registry if it exists. ERROR: Cannot convert the "Explorer.exe" value of type "System.String" to type "System.Diagnostics.Process".
#Unlock-WindowsWithSycnex
