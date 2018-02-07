Function hostfile-or-adhoc {
	if ($host_list.length -eq 0){
		Write-Host "You do not have a host list defined." -ForegroundColor Magenta
		$answer = Read-Host "Would you like to build a list of hosts [Y/n]"
		Switch ($answer.ToLower()){
		"y" {
			$host_list = retrieve-hosts-adhoc
			return $host_list
		}
		
		"n" { return }
		
		Default {
			Write-Warning "Using default [Y] choice."
			sleep -milliseconds 750
			$host_list = retrieve-hosts-adhoc
			return $host_list	
			}
		} #switch
		
	} else {
		Write-Host "You do have a host list defined." -ForegroundColor Green
		$answer = Read-Host "Would you like to use this list of hosts [Y/n]"
		Switch ($answer.ToLower()){
		"y" {  }		
		"n" { $host_list = retrieve-hosts-adhoc }		
		Default {
			Write-Warning "Using default [Y] choice."
			sleep -milliseconds 750
			}
			
		} #switch
		
		return $host_list
	}
}
Function retrieve-hosts-adhoc{
$add_more_hosts = $True
$hosts = @()

	Do {
		$answer = Read-Host "Enter the hostname or IP address to add. Leave blank if finished."
		if (![string]::IsNullOrEmpty($answer)){
			$hosts += @($answer)
		} else {
			$add_more_hosts = $False
		}
	} while ($add_more_hosts)
	
	return $hosts
}

Function retrieve-hosts-file {
	$file_path = Read-Host "What is the file path"
	if (Test-Path $file_path){
		$host_list = Get-Content $file_path
		if ($host_list.Length -eq 0){
			Write-Host "The file path provided does not contain any hosts!" -ForegroundColor Red		
		} else {
			Write-Host "Successfully retrieved host list."
			return $host_list
		}	
	} else {
		Write-Host "File path was not provided or is invalid or couldn't be found. Please try again." -ForegroundColor Red
	}
}

Function install-sysmon {
$sysmon_src_path = "\\path\to\sysmon\sysmon.exe"

$dict = @{}
	foreach ($h in $host_list){
		$sysmon_dst_path = "\\{0}\c$\mss\" -f $h
		if (Test-Connection -Cn $h -buffersize 16 -count 1 -ea 0 -quiet){
			copy-item $sysmon_src_path $sysmon_dst_path
			start-sleep -s 3
			#invoke-command -computer $h {start-process "C:\mss\sysmon.exe" -argumentlist "-i" -WindowStyle hidden}
			([WMICLASS]"\\$h\ROOT\CIMV2:Win32_Process").Create("C:\path\sysmon.exe -i -accepteula")
			invoke-command -computer $h {net localgroup "Event Log Readers" /add domain.com\wef_collector_server_name$}
			invoke-command -computer $h {winrm qc}
			
		} else {
			Write-Host ("{0} is not responding to PING" -f $h)
			log-this-data $log_file ("{0} is not responding to PING" -f $h)
		}
	}
	return $dict
}


Function press-any-key {
	Write-Host "Press any key to continue ..."
	$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

Function Show-Menu {

Param(
[Parameter(Position=0,Mandatory=$True,HelpMessage="Enter your menu text")]
[ValidateNotNullOrEmpty()]
[string]$Menu,
[Parameter(Position=1)]
[ValidateNotNullOrEmpty()]
[string]$Title="Menu",
[switch]$ClearScreen
)

if ($ClearScreen) {Clear-Host}

#build the menu prompt
$menuPrompt=$title
#add a return
$menuprompt+="`n"
#add an underline
$menuprompt+="-"*$title.Length
$menuprompt+="`n"
#add the menu
$menuPrompt+=$menu

Read-Host -Prompt $menuprompt

} #end function

################
## Variables
################

$menu = @"
1. Ingest host list from file path
2. Install Sysmon
3. Print Host Dictionary
Q. To Quit the script

Select a task by number or Q to quit
"@

$host_list = ""
$log_file = (get-location).path + "\sysmon_helper.log"

################
## Main loop
################

Do {

	#use a Switch construct to take action depending on what menu choice is selected.
	Switch (Show-Menu $menu "My Sysmon Helper Tasks" -clear) {
		"1" {Write-Host "** Ingest host list from file path **" -ForegroundColor Green
		$host_list = retrieve-hosts-file
		foreach ($h in $host_list){	Write-Host $h }		
		press-any-key
	}
		"2" {Write-Host "** Install Sysmon **" -ForegroundColor Green
		$host_list = hostfile-or-adhoc
		if (![string]::IsNullOrEmpty($host_list)){
			$host_dict = install-sysmon
		}
		press-any-key
	}
		"3" {Write-Host "** Checking existence of host dictionary **" -ForegroundColor Yellow
		if (![string]::IsNullOrEmpty($host_dict)){
			Write-Host "** Printing host dictionary **" -ForegroundColor Green
			$host_dict.GetEnumerator() | % {Write-Host $($_.key) $($_.value)}
		} else {
			Write-Host "** Host dictionary does not exist **" -ForegroundColor Red
		}
		press-any-key
	}
		"Q" {Write-Host "** Goodbye **" -ForegroundColor Cyan
			Return
		}
	
	Default {Write-Warning "Invalid Choice. Try again."  -ForegroundColor Red
			sleep -milliseconds 750}
	} #switch
	
} While ($True)
