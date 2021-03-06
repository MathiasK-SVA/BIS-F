﻿<#
    .SYNOPSIS
        Prepare F-Secure AntiVirus for Image Managemement
	.DESCRIPTION
      	Scan system and stop services
    .EXAMPLE
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH
		
		History:
      	29.07.2017 MS: Script created
	.LINK
        https://eucweb.com
#>

Begin {
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)

	# Product specified
	$Product = "F-Secure Anti-Virus"
	$Inst_path = "$ProgramFilesx86\F-Secure\Anti-Virus"
	$ServiceNames = @("FSAUA","FSMA","F-Secure Network Request Broker","FSORSPClient","F-Secure WebUI Daemon","F-Secure Gatekeeper Handler Starter")	
}

Process {
####################################################################
####### functions #####
####################################################################

	
	function RunFullScan
	{
	
	Write-BISFLog -Msg "Check Silentswitch..."
		$varCLI = $LIC_BISF_CLI_AV
		IF (($varCLI -eq "YES") -or ($varCLI -eq "NO")) 
		{
			Write-BISFLog -Msg "Silentswitch would be set to $varCLI"
		} ELSE {
           	Write-BISFLog -Msg "Silentswitch not defined, show MessageBox"
			$MPFullScan = Show-BISFMessageBox -Msg "Would you like to to run a Full Scan ? " -Title "$Product" -YesNo -Question
        	Write-BISFLog -Msg "$MPFullScan would be choosen [YES = Running Full Scan] [NO = No scan would be performed]"
		}
        if (($MPFullScan -eq "YES" ) -or ($varCLI -eq "YES"))
		{
			Write-BISFLog -Msg "Running Fullscan... please Wait"
			Start-Process -FilePath "$Inst_path\fsav.exe" -ArgumentList "c:\ /REPORT=C:\Windows\Logs\fsavlog.txt"
			Show-BISFProgressBar -CheckProcess "$ScanProcess" -ActivityText "$Product is scanning the system...please wait"
		    Get-BISFLogContent -GetLogFile "C:\Windows\Logs\fsavlog.txt"
            remove-item -Path "C:\Windows\Logs\fsavlog.txt" -Force
        } ELSE {
			Write-BISFLog -Msg "No Full Scan would be performed"  
		}
	
	}
    
	

    function StopService
    {
		ForEach ($ServiceName in $ServiceNames)
		{
			$svc = Test-BISFService -ServiceName "$ServiceName"
			IF ($svc -eq $true) {Invoke-BISFService -ServiceName "$($ServiceName)" -Action Stop}
		}
    }

	####################################################################
	####### end functions #####
	####################################################################

	#### Main Program
	$svc = Test-BISFService -ServiceName $ServiceNames[1] -ProductName "$product"
	IF ($svc -eq $true)
	{
		RunFullScan
		StopService
	}
}


End {
	Add-BISFFinishLine
}
