[CmdletBinding()]
<#
.DESCRIPTION

This module installes updates on windows OS.

Multiple issues were detected during the installation of updates in Windows OS.
Thus, this script fixes those issues as well. You can find a brief description of them below:
- looping on installation of KB4493509
    Update: "(2019-04-09; 84670.31 MB): 2019-04 Cumulative Update for Windows 10 Version 1809 for x64-based Systems (KB4493509)"
    Solution: "https://windows101tricks.com/windows-10-update-failed-to-install/"


Here is the sequence of provisions you need to specify if you want to fully patch your OS
    {
      "type": "powershell",
      "script": "res/ps/Fix-WindowsUpdates.ps1"
    },
    {
      "type": "windows-update"
    },
Of course, you need the windows-update provisioner to be installed in order to make it work


.PARAMATER 

#>
Param (
    [String] $pathToFixKB4493509 = "c:\windows\softwaredistribution\download\"
)

function Install-WindowsUpdateDepedencies
{
    param(
        [bool] $confirm = $False
    )
    Install-PackageProvider -Name NuGet -Force -Confirm:$confirm | Out-Null
    Install-Module -Force -Confirm:$confirm PSWindowsUpdate | Out-Null
    Add-WUServiceManager -Confirm:$confirm -ServiceID 7971f918-a847-4430-9279-4a52d1efe18d | out-null
}

Write-Host "[+] Installing PS windows update depedencies"
Install-WindowsUpdateDepedencies

Write-Host "[+] Installing updates"
Install-WUUpdates -Updates (Start-WUScan)

Write-Host "[+] Setting trustedinstaller start to auto"
$cmdArgs = @("config", "trustedinstaller", "start=auto")
sc.exe $cmdArgs

Write-Host "[+] Cleaning database cache"
Remove-Item -ErrorAction SilentlyContinue -Force -Recurse $pathToFixKB4493509\*

