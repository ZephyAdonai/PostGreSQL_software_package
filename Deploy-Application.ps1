<#
.SYNOPSIS

PSApppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION

- The script is provided as a template to perform an install or uninstall of an application(s).
- The script either performs an "Install" deployment type or an "Uninstall" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.

PSApppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2024 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham and Muhammad Mashwani).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.PARAMETER DeploymentType

The type of deployment to perform. Default is: Install.

.PARAMETER DeployMode

Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.

.PARAMETER AllowRebootPassThru

Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode

Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging

Disables logging to file for the script. Default is: $false.

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"

.EXAMPLE

Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
- 69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
- 70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1

.LINK

https://psappdeploytoolkit.com
#>


[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [String]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [String]$DeployMode = 'Silent',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false
)

Try {
    ## Set the script execution policy for this process
    Try {
        Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop'
    } Catch {
    }

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [String]$appVendor = 'PostgreSQL Global Development Group'
    [String]$appName = 'PostgreSQL 15'
    [String]$appVersion = '5.13.1'
    [String]$appArch = 'x64'
    [String]$appLang = 'EN'
    [String]$appRevision = '01'
    [String]$appScriptVersion = '1.0.0'
    [String]$appScriptDate = '5/20/2025'
	[String]$appScriptAuthor = 'Zephanyah Nelms'
	[string]$saicRegKey = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\RITS\SAIC"
	[string]$ProcessList = ''
	[string]$SAICTemplate = '1.1.0'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [String]$installName = ''
    [String]$installTitle = ''
	
	#region : Initial Registry Key entries
	
	if (!(Test-Path "$saicRegKey\$appVendor\$appName\$appVersion"))
	{
		New-Item "$saicRegKey\$appVendor\$appName\$appVersion" -Force | Out-Null
	}
	Set-ItemProperty "$saicRegKey\$appVendor\$appName\$appVersion" -Name "AppTitle" -Value $appNameWithSpaces -Force
	Set-ItemProperty "$saicRegKey\$appVendor\$appName\$appVersion" -Name "ComputerName" -Value $env:COMPUTERNAME -Force
	Set-ItemProperty "$saicRegKey\$appVendor\$appName\$appVersion" -Name "StartTime" -Value "$(Get-Date)" -Force
	Set-ItemProperty "$saicRegKey\$appVendor\$appName\$appVersion" -Name "ScriptVersion" -Value $appScriptVersion -Force
	Set-ItemProperty "$saicRegKey\$appVendor\$appName\$appVersion" -Name "SourcePath" -Value $(Split-Path $script:MyInvocation.MyCommand.path) -Force
	Set-ItemProperty "$saicRegKey\$appVendor\$appName\$appVersion" -Name "UserID" -Value ([Environment]::UserDomainName + "\" + [Environment]::UserName) -Force
	$appVer = $appVersion
	$appVendorfinal = $appvendor
	$appnamefinal = $appName
	
	#endregion	
	
	#region : Variables: System Information
	$SerialNumber = (gwmi win32_bios).serialnumber
	$Manufacturer = (gwmi win32_bios).Manufacturer
	$BIOsVerison = (gwmi win32_bios).SMBIOSBIOSVersion
	$Model = (gwmi win32_computersystem).Model
	$Name = (gwmi win32_computersystem).Name
	$GB = gwmi win32_LogicalDisk | Measure-Object -Sum Size
	$GB2 = gwmi win32_LogicalDisk | Measure-Object -Sum freespace
	$Disk = "{0:N2}" -f ($GB.Sum / 1GB) + " GB"
	$FreeSpace = "{0:N2}" -f ($gb2.sum / 1GB) + " GB"
	#endregion	
		
    ##* Do not modify section below
    #region DoNotModify
	#region Check for Process for Interactive or Non Interactive
	[psobject[]]$processObjects = @()
	ForEach ($process in ($ProcessList -split ',' | Where-Object { $_ }))
	{
		If ($process.Contains('='))
		{
			[string[]]$ProcessSplit = $process -split '='
			$processObjects += New-Object -TypeName 'PSObject' -Property @{
				ProcessName = $ProcessSplit[0]
				ProcessDescription = $ProcessSplit[1]
			}
		}
		Else
		{
			[string]$ProcessInfo = $process
			$processObjects += New-Object -TypeName 'PSObject' -Property @{
				ProcessName	       = $process
				ProcessDescription = ''
			}
		}
	}
	[string[]]$processNames = $processobjects | ForEach-Object { $_.ProcessName }
	[Diagnostics.Process[]]$runningProcesses = Get-Process | Where-Object { $processnames -contains $_.ProcessName }
	$who = whoami
	if ($runningProcesses)
	{
		[string]$DeployMode = 'Interactive'
	}
	if (($who -ne "nt authority\system") -and (($PSBoundParameters.ContainsValue("Silent") -or ($PSBoundParameters.ContainsValue("silent")))))
	{
		[string]$DeployMode = 'Silent'
	}
	if (($who -ne "nt authority\system") -and ((!$PSBoundParameters.ContainsValue("Silent") -or (!$PSBoundParameters.ContainsValue("silent")))))
	{
		[string]$DeployMode = 'Interactive'
	}
	#endregion	
	
    ## Variables: Exit Code
    [Int32]$mainExitCode = 0

    ## Variables: Script
    [String]$deployAppScriptFriendlyName = 'Deploy Application'
    [Version]$deployAppScriptVersion = [Version]'3.10.1'
    [String]$deployAppScriptDate = '05/03/2024'
    [Hashtable]$deployAppScriptParameters = $PsBoundParameters
	If ($deployAppScriptParameters)
	{
		[string]$PSKeys = ($deployAppScriptParameters.GetEnumerator() | ForEach-Object {
				If ($_.Value.GetType().Name -eq 'SwitchParameter') { "-$($_.Key):`$" + "$($_.Value)".ToLower() }
				ElseIf ($_.Value.GetType().Name -eq 'Boolean') { "-$($_.Key) `$" + "$($_.Value)".ToLower() }
				ElseIf ($_.Value.GetType().Name -eq 'Int32') { "-$($_.Key) $($_.Value)" }
				Else { "-$($_.Key) `"$($_.Value)`"" }
			}) -join ' '
	}

	## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') {
        $InvocationInfo = $HostInvocation
    }
    Else {
        $InvocationInfo = $MyInvocation
    }
    [String]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [String]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) {
            Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]."
        }
        If ($DisableLogging) {
            . $moduleAppDeployToolkitMain -DisableLogging
        }
        Else {
            . $moduleAppDeployToolkitMain
        }
    }
    Catch {
        If ($mainExitCode -eq 0) {
            [Int32]$mainExitCode = 60008
        }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') {
            $script:ExitCode = $mainExitCode; Exit
        }
        Else {
            Exit $mainExitCode
        }
    }
	If ($DeployMode -eq 'Interactive')
	{
		Show-InstallationWelcome
		
		If ($ProcessList -ne '')
		{
			Show-InstallationWelcome -customtext -CloseApps $ProcessList
		}
	}
	#endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================
	
	#region : InstallLog: Package Information
	Write-Log -Message "****************************************************************" -Source $deployAppScriptFriendlyName
	Write-Log -Message "********** Package Information *********************************" -Source $deployAppScriptFriendlyName
	Write-Log -Message "****************************************************************" -Source $deployAppScriptFriendlyName
	Write-Log -Message "********** INFO: [$appTitle] ***********************************" -Source $deployAppScriptFriendlyName
	Write-Log -Message "********** INFO: SAIC Template version: [$SAICTemplate] *****" -Source $deployAppScriptFriendlyName
	Write-Log -Message "********** INFO: Installation Path: [$scriptParentPath] ********" -Source $deployAppScriptFriendlyName
	Write-Log -Message "********** INFO: Install Parameters: [$PSkeys] *****************" -Source $deployAppScriptFriendlyName
	Write-Log -Message "********** INFO: Script Author: [$appScriptAuthor] *************" -Source $deployAppScriptFriendlyName
	Write-Log -Message "****************************************************************" -Source $deployAppScriptFriendlyName
	Write-Log -Message "********** System Information **********************************" -Source $deployAppScriptFriendlyName
	Write-Log -Message "****************************************************************" -Source $deployAppScriptFriendlyName
	Write-Log -Message "********** Name = [$Name] **************************************" -Source $deployAppScriptFriendlyName
	Write-Log -Message "********** OS Name= [$envOSName] *******************************" -Source $deployAppScriptFriendlyName
	Write-Log -Message "********** OS Version= [$envOSVersion] *************************" -Source $deployAppScriptFriendlyName
	Write-Log -Message "********** Serial Number= [$SerialNumber] **********************" -Source $deployAppScriptFriendlyName
	Write-Log -Message "********** BIOS Version = [$BIOsVerison] ***********************" -Source $deployAppScriptFriendlyName
	Write-Log -Message "********** Manufacturer = [$Manufacturer ***********************" -Source $deployAppScriptFriendlyName
	Write-Log -Message "********** Model = [$Model] ************************************" -Source $deployAppScriptFriendlyName
	Write-Log -Message "********** Total Disk Size = [$Disk] ***************************" -Source $deployAppScriptFriendlyName
	Write-Log -Message "********** Free Disk Space = [$FreeSpace] **********************" -Source $deployAppScriptFriendlyName
	Write-Log -Message "****************************************************************" -Source $deployAppScriptFriendlyName
	
	#endregion	
	
    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Installation'
		
		<# 
        	Determine if installation is running from a task sequence.
        	If detected as true, set "$DeployMode = NonInteractive".
			
			*NOTE: The $runningTaskSequence variable is created by the 'AppDeployToolkitMain.ps1', which is dot-sourced at the beginning phase of the script's execution.
        #>		
		
		If ($runningTaskSequence -eq $true)
		{
			Write-Log -Message 'Application installation is running from task sequence. Setting $DeployMode to NonInteractive. ' -Source $deployAppScriptFriendlyName
			$DeployMode = "NonInteractive"
		}
		
		If ($DeployMode -eq "Interactive")
		{
			## Show Progress Message (with the default message)
			Show-InstallationProgress
		}
		
		## <Perform Pre-Installation tasks here>
		
		########################################################
		##### Uninstall previous versions of PostgreSQL 15 #####
		########################################################	
		
		Write-Log -Message "##### Remove previous versions of PostgreSQL 15. #####" -Source $deployAppScriptFriendlyName

		[version]$VERSION = "15.13.1"
		$Path = "C:\Program Files*\PostgreSQL\*\uninstall-postgresql.exe" | Resolve-Path 
		$Apps = Get-InstalledApplication -Name 'PostgreSQL'
		ForEach ($App in $Apps)
		{
			$InstalledVersion = ($App.DisplayVersion -replace "-", ".")
			$NormalizedVersion = if ($InstalledVersion -notmatch "\.") { "$InstalledVersion.0" } else { $InstalledVersion }
			If (($($App.UninstallString) -notlike "MsiExec*") -and ([version]$NormalizedVersion -lt "$VERSION") -and ($($App.DisplayName) -notlike "PostgreSQL ODBC*") -and ($Path -ne $null))
			{
				Write-Log -Message "[AppToolkit] Uninstall Product: $($App.DisplayName) | Version: $($App.DisplayVersion)" -Source $deployAppScriptFriendlyName
				$UninstallPath = $($App.UninstallString).trim('"') ## "C:\Program Files\PostgreSQL\15\uninstall-postgresql.exe"
				Execute-Process -Path $UninstallPath -Parameters "--unattendedmodeui none --mode unattended" | Out-Null
			}
		}

		######################################################################
		##### Install Microsoft Visual C++ 2015-2022 (x86) - 14.42.34438 #####
		######################################################################
		
		Write-Log -Message "##### Check to see if Microsoft Visual C++ 2015-2022 (x86) - 14.42.34438 is installed and install if not present. #######" -Source $deployAppScriptFriendlyName
		
		$VER = '14.42.34438'
		$vc_red2022x86 = Get-InstalledApplication -Name '2022 Redistributable (x86)'
		$Install2022x86 = $vc_red2022x86 | Where { $_.DisplayVersion -ge "14.42.34438.0" }
		
		
		If (([version]$vc_red2022x86.DisplayVersion) -ge [version]$VER)
		{
			Write-Log -Message "##### Microsoft Visual C++ 2022 x86 Redistributable - 14.42.34438 or newer version found.  Do not perform install. #######" -Source $deployAppScriptFriendlyName
		}
		
		If ($Install2022x86 -eq $null) ## If Newer Version Not Found Perform Install
		{
			$argumentlist = "REBOOT=ReallySuppress /QN ADDEPLOY=1 ALLUSERS=1"
			Execute-MSI -Action Install "$dirFiles\VCRedist_2015-2022_x86\vcRuntimeMinimum_x86\vc_runtimeMinimum_x86_14.42.34438.msi" -Parameters $argumentlist | Out-Null
			Execute-MSI -Action Install "$dirFiles\VCRedist_2015-2022_x86\vcRuntimeAdditional_x86\vc_runtimeAdditional_x86_14.42.34438.msi" -Parameters $argumentlist | Out-Null
			Execute-Process -Path "$dirFiles\VCRedist_2015-2022_x86\ARP\VC_redist.x86.exe" -Parameters "/S"
		}
		
		######################################################################
		##### Install Microsoft Visual C++ 2015-2022 (x64) - 14.42.34438 #####
		######################################################################
		
		Write-Log -Message "##### Check to see if Microsoft Visual C++ 2015-2022 (x64) - 14.42.34438 is installed and install if not present. #######" -Source $deployAppScriptFriendlyName
		
		$VER = '14.42.34438'
		$vc_red2022x64 = Get-InstalledApplication -Name '2022 Redistributable (x64)'
		$Install2022x64 = $vc_red2022x64 | Where { $_.DisplayVersion -ge "14.42.34438.0" }
		
		
		If (([version]$vc_red2022x64.DisplayVersion) -ge [version]$VER)
		{
			Write-Log -Message "##### Microsoft Visual C++ 2022 x64 Redistributable - 14.42.34438 or newer version found.  Do not perform install. #######" -Source $deployAppScriptFriendlyName
		}
		
		If ($Install2022x64 -eq $null) ## If Newer Version Not Found Perform Install
		{
			$argumentlist = "REBOOT=ReallySuppress /QN ADDEPLOY=1 ALLUSERS=1"
			Execute-MSI -Action Install "$dirFiles\VCRedist_2015-2022_x64\vcRuntimeMinimum_x64\vc_runtimeMinimum_x64_14.42.34438.msi" -Parameters $argumentlist | Out-Null
			Execute-MSI -Action Install "$dirFiles\VCRedist_2015-2022_x64\vcRuntimeAdditional_x64\vc_runtimeAdditional_x64_14.42.34438.msi" -Parameters $argumentlist | Out-Null
			Execute-Process -Path "$dirFiles\VCRedist_2015-2022_x64\ARP\VC_redist.x64.exe" -Parameters "/S"
		}

		
		##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        ## Handle Zero-Config MSI Installations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) {
                $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ }
            }
        }

        ## <Perform Installation tasks here>

		#########################################
		##### Install PostgreSQL 15 15.13-1 #####
		#########################################		
		
		Write-Log -Message "##### Check to see if $appName $appVersion or greater is installed and install if not present. #######" -Source $deployAppScriptFriendlyName
		
		[version]$VERSION = "15.13.1"
		$Found = $false
		$Apps = Get-InstalledApplication -Name "PostgreSQL 15" 
		ForEach ($App in $Apps)
		{
			$InstalledVersion = ($App.DisplayVersion -replace "-", ".")
			If (([version]$InstalledVersion -ge $VERSION) -and ($($App.UninstallString) -notlike "MsiExec*"))
			{
				Write-Log -Message "##### The $($App.DisplayName) $($App.DisplayVersion) or greater is already installed. #######" -Source $deployAppScriptFriendlyName
				$Found = $true
			}
		}
	
		If ($Found -eq $false)
		{
			Write-Log -Message "##### Please wait... Installing $appName $appVersion ... #######" -Source $deployAppScriptFriendlyName
			
			$Arguments = '--mode unattended --unattendedmodeui none  --servicepassword ""'
			Execute-Process -Path "$dirFiles\postgresql-15.13-1-windows-x64.exe" -Parameters $Arguments | Out-Null
				
			## Check for the installation of PostgreSQL 15  15.13-1 install
			$App = Get-InstalledApplication -Name 'PostgreSQL 15'
			If ($App -eq $null)
			{
				Write-Log -Message "##### The installation of $appName $appVersion failed. #####" -Source $deployAppScriptFriendlyName
			}
			elseif (($($App.UninstallString) -notlike "MsiExec*") -and ([version]$($App.DisplayVersion -replace "-", ".") -eq $VERSION))
			{
				Write-Log -Message "##### The installation of $($App.DisplayName) $($App.DisplayVersion) was successful. #######" -Source $deployAppScriptFriendlyName
			}
		}
		
		##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>
		
		
        ## Display a message at the end of the install
		If ((-not $useDefaultMsi) -and ($DeployMode -eq "Interactive"))
		{
			Show-InstallationPrompt -Message "The $appVendor $appName $appVersion installation completed successfully." -ButtonRightText 'OK' -Icon Information -NoWait
        }
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Uninstallation tasks here>


        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'

        ## Handle Zero-Config MSI Uninstallations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }

        ## <Perform Uninstallation tasks here>
		
		###########################################
		##### Uninstall PostgreSQL 15 15.13-1 #####
		###########################################
		
		Write-Log -Message "##### Uninstall $appName $appVersion #####" -Source $deployAppScriptFriendlyName

		[version]$VERSION = "15.13.1"
		$Path = "C:\Program Files\PostgreSQL\15\uninstall-postgresql.exe"
		$Apps = Get-InstalledApplication  -Name "PostgreSQL 15"
		ForEach ($App in $Apps)
		{
			$InstalledVersion = ($App.DisplayVersion -replace "-", ".")
			If (($($App.UninstallString) -notlike "MsiExec*") -and ([version]$InstalledVersion -eq "$VERSION") -and ($Path -ne $null))
			{
				Write-Log -Message "[AppToolkit] Uninstall Product: $($App.DisplayName) | Version: $($App.DisplayVersion)" -Source $deployAppScriptFriendlyName
				$UninstallPath = $($App.UninstallString).trim('"') ## "C:\Program Files\PostgreSQL\15\uninstall-postgresql.exe"
				$Arguments = '--mode unattended --unattendedmodeui none'
				Execute-Process -Path $UninstallPath -Parameters $Arguments | Out-Null	
				
				########################################################
				##### Delete C:\Program Files\PostgreSQL\15 folder #####
				########################################################
				
				Write-Log -Message "##### Delete C:\Program Files\PostgreSQL\15 folder. #####" -Source $deployAppScriptFriendlyName
				
				$FolderPath = "C:\Program Files\PostgreSQL\15"
				Remove-Folder -Path "$FolderPath"
			}
		}
		
		
		##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'

        ## <Perform Post-Uninstallation tasks here>
		
		If ((-not $useDefaultMsi) -and ($DeployMode -eq "Interactive")) { Show-InstallationPrompt -Message "The $appVendor $appName $appVersion uninstallation completed successfully." -ButtonRightText 'OK' -Icon Information -NoWait }
		
	}
	ElseIf ($deploymentType -ieq 'Repair')
	{
		##*===============================================
		##* PRE-REPAIR
		##*===============================================
		[String]$installPhase = 'Pre-Repair'
		
		## Show Progress Message (with the default message)
		Show-InstallationProgress
		
		## <Perform Pre-Repair tasks here>
		
		
		##*===============================================
		##* REPAIR
		##*===============================================
		[String]$installPhase = 'Repair'
		
		## Handle Zero-Config MSI Repairs
		If ($useDefaultMsi)
		{
			[Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile)
			{
				$ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
			}
			Execute-MSI @ExecuteDefaultMSISplat
		}
		## <Perform Repair tasks here>
		
		########################################
		##### Repair PostgreSQL 15 15.13-1 #####
		########################################
		
		Write-Log -Message "##### Please wait... Repairing $appName $appVersion ... #######" -Source $deployAppScriptFriendlyName
		
		$Arguments = '--mode unattended --unattendedmodeui none  --servicepassword ""'
		Execute-Process -Path "$dirFiles\postgresql-15.13-1-windows-x64.exe" -Parameters $Arguments | Out-Null
		
		## Check for PostgreSQL 15 install
		[version]$VERSION = "15.13.1"
		$App = Get-InstalledApplication -Name 'PostgreSQL 15'
		$InstalledVersion = ($App.DisplayVersion -replace "-", ".")
		If ($App -eq $null)
		{
			Write-Log -Message "##### The repair of $appName $appVersion failed. #####" -Source $deployAppScriptFriendlyName
		}
		elseif (($($App.UninstallString) -notlike "MsiExec*") -and ([version]$InstalledVersion -eq $VERSION))
		{
			Write-Log -Message "##### The repair of $($App.DisplayName) $($App.DisplayVersion) was successful. #######" -Source $deployAppScriptFriendlyName
		}
		

		##*===============================================
		##* POST-REPAIR
		##*===============================================
		[String]$installPhase = 'Post-Repair'
		
		## <Perform Post-Repair tasks here>
		
		If ((-not $useDefaultMsi) -and ($DeployMode -eq "Interactive")) { Show-InstallationPrompt -Message "The $appVendor $appName $appVersion repair completed successfully." -ButtonRightText 'OK' -Icon Information -NoWait }
		
	}
	##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================
	
	#region Final Registry Key Entries 
	If ($DeploymentType -eq 'Install')
	{
		Set-ItemProperty "$saicRegKey\$appVendorfinal\$appnamefinal\$appVer" -Name "EndTime" -Value "$(Get-Date)" -Force
		Set-ItemProperty "$saicRegKey\$appVendorfinal\$appnamefinal\$appVer" -Name "Installed" -Value "1" -Force
	}
	elseif ($DeploymentType -eq 'Uninstall')
	{
		Set-ItemProperty "$saicRegKey\$appVendorfinal\$appnamefinal\$appVer" -Name "EndTime" -Value "$(Get-Date)" -Force
		Set-ItemProperty "$saicRegKey\$appVendorfinal\$appnamefinal\$appVer" -Name "Installed" -Value "0" -Force
	}
	elseif ($DeploymentType -eq 'Repair')
	{
		Set-ItemProperty "$saicRegKey\$appVendorfinal\$appnamefinal\$appVer" -Name "EndTime" -Value "$(Get-Date)" -Force
		Set-ItemProperty "$saicRegKey\$appVendorfinal\$appnamefinal\$appVer" -Name "Installed" -Value "1" -Force
	}
	#endregion		
	
    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [Int32]$mainExitCode = 60001
    [String]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
