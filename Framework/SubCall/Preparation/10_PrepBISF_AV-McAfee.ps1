﻿<#
	.SYNOPSIS
		Prepare McAfee Agent for Image Managemement
	.DESCRIPTION
	  	Delete computer specific entries
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
	  	Company: Login Consultants Germany GmbH

		History
		10.12.2014 JP: Script created
		15.12.2014 JP: Added automatic virus definitions updates
		06.02.2015 MS: Reviewed script
		19.02.2015 MS: Fixed some errors and add progress bar for running scan
		01.10.2015 MS: Rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		05.01.2017 JP: Added maconfig.exe See https://community.mcafee.com/external-link.jspa?url=https%3A%2F%2Fkc.mcafee.com%2Fresources%2Fsites%2FMCAFEE%2Fcontent%2Flive%2FPRODUCT_DOCUMENTATION%2F25000%2FPD25187%2Fen_US%2Fma_500_pg_en-us.pdf
		& https://kc.mcafee.com/corporate/index?page=content&id=KB84087
		10.01.2017 MS: Added Script to BIS-F for McAfee 5.0 Support, thx to Jonathan Pitre
		11.01.0217 MS: $reg_agent_version = move (Get-ItemProperty "$reg_agent_string").AgentVersion after Product Installation check, otherwise error in POSH Output RegKey does not exist
		13.01.2017 FF: Search for maconfig.exe under x86 and x64 Program Files
		01.18.2017 JP: Added the detected agent version in the log message
		06.03.2017 MS: Bugfix read Variable $varCLI = ...
		08.01.2017 JP: Fixed typos
		15.10.2018 MS: Bugfix 58 - remove hardcoded maconfig.exe path
		28.03.2019 MS: FRQ 83 - McAfee Move integration
	.LINK
		https://eucweb.com
#>

Begin {
	$Script_Path = $MyInvocation.MyCommand.Path
	$Script_Dir = Split-Path -Parent $Script_Path
	$Script_Name = [System.IO.Path]::GetFileName($Script_Path)

	# Product specIfied
	$Product = "McAfee VirusScan Enterprise"
	$Product2 = "McAfee Agent"
	$reg_product_string = "$hklm_sw_x86\Network Associates\ePolicy Orchestrator\Agent"
	$reg_agent_string = "$hklm_sw_x86\McAfee\Agent"
	$Product_Path = "$ProgramFilesx86\McAfee\VirusScan Enterprise"
	$ServiceName1 = "McAfeeFramework"
	$ServiceName2 = "McShield"
	$ServiceName3 = "McTaskManager"
	$PrepApp = "maconfig.exe"
	$PrepAppSearchFolder = @("${env:ProgramFiles}\McAfee\Common Framework", "${env:ProgramFiles(x86)}\McAfee\Common Framework")
	[array]$reg_product_name = "AgentGUID"
	[array]$reg_product_name += "MacAddress"
	[array]$reg_product_name += "ComputerName"
	[array]$reg_product_name += "IPAddress"
	[array]$reg_product_name += "LastASCTime"
	[array]$reg_product_name += "SequenceNumber"
	[array]$reg_product_name += "SubnetMask"

	#McAfee MOVE with installed agent
	$ServiceName10 = "mvagtsvc"
	$Product10 = "McAfee MOVE"
	$HKLMAgent10path1 = "$HKLM_sw_x86\Network Associates\ePolicy Orchestrator\Agent"
	$HKLMAgent10key1 = "AgentGUID"
	$HKLMAgent10path2 = "HKLM:\SYSTEM\CurrentControlSet\Services\mvagtdrv\Parameters"
	$HKLMAgent10key2_1 = "ServerAddress1"
	$HKLMAgent10key2_2 = "ServerAddress2"
	$HKLMAgent10key2_3 = "ODSUniqueId"

}

Process {
	####################################################################
	####### Functions #####
	####################################################################

	Function DefUpdates {
		Invoke-BISFService -ServiceName "$ServiceName1" -Action Start
		Write-BISFLog -Msg "Updating virus definitions...please wait"
		Start-Process -FilePath "$Product_Path\mcupdate.exe" -ArgumentList "/update /quiet"
		Show-BISFProgressBar -CheckProcess "mcupdate" -ActivityText "$Product is updating the virus definitions...please wait"
		Start-Sleep -s 3
	}

	Function RunFullScan {

		Write-BISFLog -Msg "Check Silentswitch..."
		$varCLI = $LIC_BISF_CLI_AV
		If (($varCLI -eq "YES") -or ($varCLI -eq "NO")) {
			Write-BISFLog -Msg "Silentswitch will be set to $varCLI"
		}
		Else {
			Write-BISFLog -Msg "Silentswitch not defined, show MessageBox"
			$MPFullScan = Show-BISFMessageBox -Msg "Would you like to to run a Full Scan ? " -Title "$Product" -YesNo -Question
			Write-BISFLog -Msg "$MPFullScan will be choosen [YES = Run Full Scan] [NO = No scan will be performed]"
		}
		If (($MPFullScan -eq "YES" ) -or ($varCLI -eq "YES")) {
			Write-BISFLog -Msg "Running Full Scan...please wait"
			Start-Process -FilePath "$Product_Path\Scan32.exe" -ArgumentList "c:\"
			If ($OSBitness -eq "32-bit") { $ScanProcess = "Scan32" } Else { $ScanProcess = "Scan64" }
			Show-BISFProgressBar -CheckProcess "$ScanProcess" -ActivityText "$Product is scanning the system...please wait"
		}
		Else {
			Write-BISFLog -Msg "No Full Scan will be performed"
		}

	}

	Function DeleteVSEData {
		If ($reg_agent_version -lt "5.0") {
			Invoke-BISFService -ServiceName "$ServiceName1" -Action Stop
			Invoke-BISFService -ServiceName "$ServiceName2" -Action Stop
			Invoke-BISFService -ServiceName "$ServiceName3" -Action Stop
			ForEach ($key in $reg_product_name) {
				Write-BISFLog -Msg "Delete specIfied registry items in $reg_product_string..."
				Write-BISFLog -Msg "Delete $key"
				Remove-ItemProperty -Path $reg_product_string -Name $key -ErrorAction SilentlyContinue
			}
		}
		If ($reg_agent_version -ge "5.0") {

			$found = $false
			Write-BISFLog -Msg "Searching for $PrepApp on the system" -ShowConsole -Color DarkCyan -SubMsg
			$PrepAppExists = Get-ChildItem -Path "$PrepAppSearchFolder" -filter "$PrepApp" -ErrorAction SilentlyContinue | % { $_.FullName }

			IF (($PrepAppExists -ne $null) -and ($found -ne $true)) {

				If (Test-Path ("$PrepAppExists") -PathType Leaf ) {
					Write-BISFLog -Msg "$PrepApp found in $PrepAppExists" -ShowConsole -Color DarkCyan -SubMsg
					Write-BISFLog -Msg "Removed $Product GUID"
					$found = $true
					& Start-Process -FilePath "$PrepAppExists" -ArgumentList "-enforce -noguid" -Wait
				}
			}
		}
	}

	Function Delete-Agent10Data {
		Write-BISFLog -Msg "Remove Registry $HKLMAgent10path1 - Key $HKLMAgent10key1" -ShowConsole -Color DarkCyan -SubMsg
		Remove-ItemProperty -Path $HKLMAgent10path1 -Name $HKLMAgent10key1 -ErrorAction SilentlyContinue

		Write-BISFLog -Msg "Update Registry $HKLMAgent10path2 - Key $HKLMAgent10key2_1"
		Set-ItemProperty -Path $HKLMAgent10path2 -Name $HKLMAgent10key2_1 -value "" -Force

		Write-BISFLog -Msg "Update Registry $HKLMAgent10path2 - Key $HKLMAgent10key2_2"
		Set-ItemProperty -Path $HKLMAgent10path2 -Name $HKLMAgent10key2_2 -value "" -Force

		Write-BISFLog -Msg "Update Registry $HKLMAgent10path2 - Key $HKLMAgent10key2_3"
		Set-ItemProperty -Path $HKLMAgent10path2 -Name $HKLMAgent10key2_3 -value "" -Force


	}

	####################################################################
	####### End functions #####
	####################################################################

	#### Main Program
	If (Test-Path ("$Product_Path\shstat.exe") -PathType Leaf) {
		Write-BISFLog -Msg "Product $Product installed" -ShowConsole -Color Cyan
		$reg_agent_version = (Get-ItemProperty "$reg_agent_string").AgentVersion
		Write-BISFLog -Msg "Product $Product2 $reg_agent_version installed" -ShowConsole -Color Cyan
		DefUpdates
		RunFullScan
		DeleteVSEData
	}
	Else {
		Write-BISFLog -Msg "Product $Product NOT installed"
	}

	$svc = Test-BISFService -ServiceName $servicename10 -ProductName "$product10"
	IF ($svc -eq $true) {
		Write-BISFLog -Msg "Information only: Unselect 'Enable Selfprotection' on the McAfee Management Server and/or in the Policy for MOVE AV Common" -ShowConsole -Color DarkCyan -SubMsg
		Write-BISFLog -Msg "Perform an  On Demand Scan (ODS) before you run this script to build up the cache"
		Delete-Agent10Data
	}
	Else {
		Write-BISFLog -Msg "Product $Product10 NOT installed"
	}

}

End {
	Add-BISFFinishLine
}