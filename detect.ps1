$Installed = $false
$tmp = 0
[boolean]$64bit = [boolean]((Get-WmiObject -Class 'Win32_Processor' -ErrorAction 'SilentlyContinue' | Where-Object { $_.DeviceID -eq 'CPU0' } | Select-Object -ExpandProperty 'AddressWidth') -eq 64)
# Search for PostgreSQL 17 15.13-1 or greater is installed.
[version]$VERSION = "15.13.1"
If ($64bit)
{
	$pCodes = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" |`
	? { $_.DisplayName -like "PostgreSQL 15*" } | Select-Object PSChildName, DisplayName, DisplayVersion, UninstallString -ExpandProperty PSChildName
	ForEach ($pCode in $pCodes)
	{
		If ($pCode)
		{
			$InstalledVersion = ($pCode.DisplayVersion -replace "-", ".")
			If (([version]$InstalledVersion -ge $VERSION) -and ($pCode.UninstallString -notlike "MsiExec*"))
			{
				$tmp++
			}
		}
	}
}
If ($tmp -eq 1)
{
	$Installed = $true
	Write-Output $Installed
}
else{
}