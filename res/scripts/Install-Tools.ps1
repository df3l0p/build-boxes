[CmdletBinding()]
<#
.DESCRIPTION
    This cmdlet install third party tools using chocolatey.

    There is two parameters available that allows specification of which
    tools to install according if it is a workstation or a server.

    Workstations are identified using WMI win32_operatingsystem class
    
.PARAMATER wksTools
    The tools to install if it is a workstation.
    The string represents the argument sent to choco.exe -y

.PARAMATER srvTools
    The tools to install if it is a server.
    The string represents the argument sent to choco.exe -y
#>

Param(
    $wksTools = @(
        "notepadplusplus",
        "sysinternals --params /InstallDir:C:\tools\sysinternals",
        "firefox",
        "googlechrome",
        "sumatrapdf",
        "7zip",
        "fiddler",
        #"burp-suite-free-edition",
        #"wireshark",
        "python",
        "greenshot",
        #"ghidra",
        #"visualstudiocommunity2013",
        #"windbg",
        "mingw",
        "cygwin --parms /InstallDir:C:\tools\cygwin",
        "officeproplus2013"
        ),
    $srvTools = @(
        "notepadplusplus",
        "sysinternals --params /InstallDir:C:\tools\sysinternals",
        "windbg",
        "7zip"
        )
)

# installation of chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

$apps = @()
$os = (gwmi win32_operatingsystem).caption
# We get the appropraite set of apps to install accodring if it is a workstation
# or a server
if ($os -like "*Windows 10*") {
    $apps = $wksTools
} else{
    $apps = $srvTools
}

# Loop trough each app and installs the $app with chocolatey
foreach ($app in $apps){
    "[+] installing {0}..." -f $app
    $p = Start-Process -NoNewWindow -Wait -PassThru cmd.exe @("/c", "choco.exe install -y $app")
    if ($p.ExitCode -eq 0){
        "[+] {0} installed" -f $app
    }
    else {
        "[!] $app not installed. Error output: {0}" -f $p.StandardError
    }
}

