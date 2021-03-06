<######################################################################
SYNOPSYS 
OBJECTIVE:
	- Build HTML Header for file and Email
	- Gather all Exchange Servers and for each server  
		*	Gather Disk Sub-System Information
		*	Get Backup Status (DB Name, Server DB is Mounted, Last Full Backup) of each DB  
		*	Get Database Copy Status (Name,Status,CopyQueueLength,CurrentReplayLogTime,LastInspectedLogTime,LatestAvailableLogTime,LastCopiedLogTime,LastReplayedLogTime,ActivationPreference) of each Non-Mounted DBfiles
		*	Get Passive 
	- Trigger Syncovery job for file

	$b = GET_MOUNT_BACKUP_STATUS $exchServers
	$c = GET_PASSIVE_DBS $exchServers
	$d = GET_REPLICATION_HEALTH $exchServers
	Add-Content $logcomplete $a
	Add-Content $logcomplete $b
	Add-Content $logcomplete $c
	Add-Content $logcomplete $d
	SEND_EMAIL $logComplete $timeStamp $header $b
.NOTES    
Name: Uptime_Report.ps1
Author: Paul Marcantonio

Version : 1.2
Update  : Added additional text
		: Check on WMI Query Status
Date	: 05-Dec-2020

Version	: 1.1
Date	: 02-Nov-2018

.ServerList
Add List of Servers in ServerList.txt file and keep on same directory

.EXECUTION
Exchange_DB_Check.ps1
#>

FUNCTION INITIALIZE ()#(DONE)
{
	#	Add-Type -AssemblyName PresentationFramework
	#	Add-Type -AssemblyName Microsoft.VisualBasic
	#	Add-Type -AssemblyName System.Windows.Forms
	#	Add-Type -AssemblyName System.Drawing
	if (Test-Path $env:ExchangeInstallPath\bin\RemoteExchange.ps1)
    {
	    . $env:ExchangeInstallPath\bin\RemoteExchange.ps1
	    Connect-ExchangeServer -auto -AllowClobber
    }
    else
    {
        Write-Warning "Exchange Server management tools are not installed on this computer."
    }
}

FUNCTION BUILD_HTML_HEADER ($timeStamp, $htmlLog)
{
	$htmlHeader += '<!DOCTYPE html>'+"`n"
	$htmlHeader += '<html xmlns="http://www.w3.org/1999/xhtml">'+"`n"
	$htmlHeader += '<head>'+"`n"
	$htmlHeader += '<title>Exchange DB Summary Report</title>'+"`n"
	$htmlHeader += '<script src="../Scripts/sorttable.js"></script>'
	$htmlHeader += '</head>'+"`n"
	$htmlHeader += '<style>
			div.container {width: 80%; border: 1px solid gray; margin: auto;}
			div.header {background-color:#b5dcb3;}
			div.leftSection {background-color:#ffffff; height:auto;width:25%;float:left;}
			div.mainHeaderSection {background-color:#D4DFDA; height:auto; width:73%; float:right;}
			
			div.DB_TO_DISK_SUBSYSTEM {background-color:#D4DFDA; height: auto; width:90%; display: block; margin-left: auto; margin-right: auto;  overflow: scroll;}
			div.active_DBS  {background-color:#afdec9; height:auto; width:90%; display: block; margin-left: auto; margin-right: auto;  overflow: scroll;}
			div.passive_DBS  {background-color:#c1dde3; height:auto; width:90%; display: block; margin-left: auto; margin-right: auto;  overflow: scroll;}
			div.replication_Results {background-color:#b6c9e3; height:auto; width:90%; display: block; margin-left: auto; margin-right: auto;  overflow: scroll;}
			
			div.mainSection {background-color:#D4DFDA; height:auto; width:90%; display: block; margin-left: auto; margin-right: auto;  overflow: scroll;}
			
			div.footer {background-color:#b5dcb3; height:auto; width:100%;}
			header, footer {padding: 1em; clear: left;text-align: center;}
			nav {float: left;max-width: 160px;margin: 0;padding: 1em;}
			nav ul {list-style-type: none;padding: 0;}
			nav ul a {text-decoration: none;}
			article {margin-left: 170px; border-left: 1px solid gray;padding: 1em;overflow: hidden;}
			th.noPing {background-color: #AD2A1A; font-weight: #ffffff;}
			th.subTotals {background-color: #43ABC9; font-weight: #ffffff;}
			th.summary {background-color: #107896; font-weight: #ffffff;}
			
			td.unhealthy {background-color: #ff3347;}
			td.healthy {background-color: #33ffb1;}
			
			caption {font-weight: bold;}
			h2.DB_Header_Focus {text-align: center;font-size: 2em; margin-left: 0; margin-right: 0; font-weight: bold;}
			h3 {text-align: center;}</style>'
	$htmlHeader += '<body>'+"`n"
	$htmlHeader += '<div class="container">
		<div class="header">
		<header><H1 align="center">Metro Information Technology Exchange Database Health Report</H1><H2 align="center">This report was last run on '+$timeStamp+'</H2>'+"`n"
	$htmlHeader += '<p align="center">
						   		<h2 align="center">Click here for past (7 day) Reports <a href="file:///\\1168-poweradmin\Web Pages\Exchange\Health Checks\Database"> here</a>.<br /></h2>
								<b>Script Details:</b> Runs daily on <u>'+$ENV:COMPUTERNAME+'</u> Script Name and Location => <u>'+$MyInvocation.ScriptName.ToString()+'</u>.</br>
				   		   </p></header></div>'+"`n"
	Add-Content $htmlLog $htmlHeader
	RETURN $htmlHeader								   
}	
<#
	OBTAIN DATE TIME OF LAST SYSTEM BOOT
#>
FUNCTION GET_SYSTEM_BOOT_TIME ($svr)
{
	$result
	try{
		#Get-Service -computer $svr -Name WinRM -ErrorAction Stop
		$results = Invoke-Command -ComputerName $svr -ScriptBlock {SystemInfo | find /i "System Boot"}
	}
	catch {
	$result = "Not Able to Obtain!"
	}
	RETURN $result
}

<#
	OBTAIN SERVER DISK DRIVES DETAILS (SERVER NAME, DRIVE LETTER, DRIVE LABEL, SIZE (GB), FREE SPACE (GB), FREE SPACE (%)
	RETURN OBJECT WITH ABOVE DETAILS
#>
FUNCTION GET_DISK_SUBSYSTEM ($eSvr) #(DONE)
{
	$diskDriveResults = @()
	$disks = Get-WmiObject Win32_Volume -computername $eSvr | Select-Object __SERVER, Name, Label, @{Name=”Size(GB)”;Expression={“{0:N1}” -f($_.Capacity/1gb)}},@{Name=”FreeSpace(GB)”;Expression={“{0:N1}” -f($_.freespace/1gb)}},@{Name=”FreeSpacePerCent”;Expression={“{0:P0}” -f($_.freespace/$_.capacity)}} | Sort-Object Name
	foreach ($disk in $disks)
	{
		#if ($disk.name -like "*$drive*") {
		if ($disk.Name -notlike "*\\?\*"){
			$driveObject  = New-Object -TypeName psobject
			$driveObject | Add-Member -MemberType NoteProperty -Name Server -Value $disk.__SERVER
			$driveObject | Add-Member -MemberType NoteProperty -Name Drive -Value $disk.Name
			$driveObject | Add-Member -MemberType NoteProperty -Name DriveLabel -Value $disk.Label
			$driveObject | Add-Member -MemberType NoteProperty -Name Size -Value $disk.'Size(GB)'
			$driveObject | Add-Member -MemberType NoteProperty -Name FreeSpace -Value $disk.'FreeSpace(GB)'
			$driveObject | Add-Member -MemberType NoteProperty -Name PercentFree -Value $disk.'FreeSpacePercent'
			
			$diskDriveResults += $driveObject
		}
	}
	RETURN $diskDriveResults
}

#FOREACH EXCHANGE SERVER DISPLAY DBs (Mounted and Copies) AND DISK SUBSYSTEM INFORMATION
FUNCTION GET_DB_TO_DISK_SUBSYSTEM ($exchServers)
{
	$dbDiskSubsystemResults = @()
	$dbDiskSubsystemResults += '<div class="DB_TO_DISK_SUBSYSTEM">'+"`n"
	$dbDiskSubsystemResults += '<h2 class="DB_Header_Focus">Databases to Exchange Server Disk Subsystem</h2>'
	$dbDiskSubsystemResults += '<TABLE align="center">'+"`n"
	#	$dbDiskSubsystemResults = '<col>'+"`n"
	#  	$dbDiskSubsystemResults = '<colgroup span="2"></colgroup>'+"`n"
	#  	$dbDiskSubsystemResults = '<colgroup span="2"></colgroup>'+"`n"
	$dbDiskSubsystemResults += '<thead>'+"`n"
	$dbDiskSubsystemResults += '<tr>'+"`n"
	$dbDiskSubsystemResults += 	'<th class="summary" title="DB Name" rowspan="2">Server Name</th>'+"`n"
	$dbDiskSubsystemResults += 	'<th class="summary" title="" rowspan="2">DB Name</th>'+"`n"
	$dbDiskSubsystemResults += 	'<th class="summary" title="" rowspan="2">DB Size</th>'+"`n"
	$dbDiskSubsystemResults += 	'<th class="summary" title=" " rowspan="2">DB Free Space</th>'+"`n"
	$dbDiskSubsystemResults += 	'<th class="summary" title="" colspan="4" align="center">DB Data File Physical Drive Details</th>'+"`n"
	$dbDiskSubsystemResults += 	'<th class="summary" title="" colspan="4" align="center">DB Log File Physical Drive Details</th>'+"`n"
	$dbDiskSubsystemResults += '</tr>'+"`n"
	
	$dbDiskSubsystemResults += '<tr>'+"`n"
	$dbDiskSubsystemResults += 	'<th class="summary" title="">Drive Letter</th>'+"`n"
	$dbDiskSubsystemResults += 	'<th class="summary" title="">Capacity (GB)</th>'+"`n"
	$dbDiskSubsystemResults += 	'<th class="summary" title="">Free(GB)</th>'+"`n"
	$dbDiskSubsystemResults += 	'<th class="summary" title="">Free (&#37;)</th>'+"`n"
	$dbDiskSubsystemResults += 	'<th class="summary" title="">Drive Letter</th>'+"`n"
	$dbDiskSubsystemResults += 	'<th class="summary" title="">Capcity (GB)</th>'+"`n"
	$dbDiskSubsystemResults += 	'<th class="summary" title="">Free (GB)</th>'+"`n"
	$dbDiskSubsystemResults += 	'<th class="summary" title="">Free (&#37;)</th>'+"`n"
	$dbDiskSubsystemResults += '</tr>'+"`n"
	$dbDiskSubsystemResults += '</thead>'+"`n"
	$dbDiskSubsystemResults += '<tbody>'+"`n"	
	FOREACH ($eServer in $exchServers)
	{
	#GET DISK SUBSYSTEM
		$svrDrives = GET_DISK_SUBSYSTEM $eServer
	#GET EXCHANGE DBs (Both Mounted and Copy)
	#$svrDBS = Get-MailboxDatabase -Server $eServer
		$svrDBS = Get-MailboxDatabase -Server $eServer -Status
	#BUILD HTML TABLE
		FOREACH ($db in $svrDBS)
		{
			$dbName = $db.Name
			if ($db.DatabaseSize -ne $null)
			{
				$dbSize = $db.DatabaseSize.ToString().SubString(0,$db.DatabaseSize.ToString().IndexOf('('))
			}
			else 
			{
				$dbSize = $db.DatabaseSize
			}
			if ($db.AvailableNewMailboxSpace -ne $null)
			{
				$dbAvailable = $db.AvailableNewMailboxSpace.ToString().SubString(0,$db.AvailableNewMailboxSpace.ToString().IndexOf('('))
			}
			else
			{
				$dbAvailable = $db.AvailableNewMailboxSpace
			}
			$dataDriveLetter = $db.edbFilePath.ToString().SubString(0, 3)
			$logDriveLetter = $db.LogFolderPath.ToString().SubString(0,3)
					
			$dataDriveDetails = ($svrDrives | Where-Object {$_.Drive -eq $dataDriveLetter})
			$logDriveDetails = ($svrDrives | Where-Object {$_.Drive -eq $logDriveLetter})
			$dataDrvFree = $null
			$logDrvFree = $null
			if ($dataDriveDetails.PercentFree -le 30 )
			{
				$dataDrvFree = '<td align="center" bgcolor="#ff3347">'+$dataDriveDetails.PercentFree+'</td>'
			}
			if ($dataDriveDetails.PercentFree -gt 30 )
			{
				$dataDrvFree = '<td align="center" bgcolor="#33ffb1">'+$dataDriveDetails.PercentFree+'</td>'
			}
			if ($logDriveDetails.PercentFree -le 30 )
			{
				$logDrvFree = '<td align="center" bgcolor="#ff3347">'+$logDriveDetails.PercentFree+'</td>'
			}
			if ($logDriveDetails.PercentFree -gt 30 )
			{
				$logDrvFree = '<td align="center" bgcolor="#33ffb1">'+$logDriveDetails.PercentFree+'</td>'
			}
			$dbDiskSubsystemResults += '<tr><td>'+$eServer+'</td><td align="center">'+$dbName+'</td><td align="right">'+$dbSize+'</td><td align="right">'+$dbAvailable+'</td><td align="center">'+$dataDriveDetails.Drive+'</td><td align="center">'+$dataDriveDetails.Size+'</td><td align="center">'+$dataDriveDetails.FreeSpace+'</td>'+$dataDrvFree+'<td align="center">'+$logDriveDetails.Drive+'</td><td align="center">'+$logDriveDetails.Size+'</td><td align="center">'+$logDriveDetails.FreeSpace+'</td>'+$logDrvFree+'</tr>'+"`n"
			#$dbDiskSubsystemResults += '<tr><td>'+$eServer+'</td><td align="center">'+$dbName+'</td><td align="right">'+$dbSize+'</td><td align="right">'+$dbAvailable+'</td><td align="center">'+$dataDriveDetails.Drive+'</td><td align="center">'+$dataDriveDetails.Size+'</td><td align="center">'+$dataDriveDetails.FreeSpace+'</td><td align="center">'+$dataDriveDetails.PercentFree+'</td><td align="center">'+$logDriveDetails.Drive+'</td><td align="center">'+$logDriveDetails.Size+'</td><td align="center">'+$logDriveDetails.FreeSpace+'</td><td align="center">'+$logDriveDetails.PercentFree+'</td></tr>'+"`n"
		}
	}
	$dbDiskSubsystemResults += '</tbody>'+"`n"
	$dbDiskSubsystemResults += '</TABLE>'+"`n"
	$dbDiskSubsystemResults += '</div>'+"`n"
	RETURN $dbDiskSubsystemResults
}

FUNCTION GET_MAILBOXSPACE_HEALTH ($exchServers)
{
	#Get-ServerHealth -Identity mcuexch2 -HealthSet "MailboxSpace"|Sort-Object Server, Name, TargetResource, HealthSetName, AlertValue | ft -auto
	$mailboxSpaceResults = @()
	
	$mailboxSpaceResults += '<div class="active_DBS">'+"`n"
	$mailboxSpaceResults += '<h2 class="DB_Header_Focus">Mailbox Space Health Check</h2>'
	$mailboxSpaceResults += '<TABLE align="center">'+"`n"
	
	#$mailboxSpaceResults += '<TABLE>'+"`n"
	$mailboxSpaceResults += '<thead>'+"`n"
	$mailboxSpaceResults += '<tr>'+"`n" 
	$mailboxSpaceResults += 	'<th class="summary" title="">Server</th>'+"`n"
	$mailboxSpaceResults += 	'<th class="summary" title="">DataBase</th>'+"`n"
	$mailboxSpaceResults += 	'<th class="summary" title="">Monitor Type</th>'+"`n"
	$mailboxSpaceResults += 	'<th class="summary" title="">Status</th>'+"`n"
	$mailboxSpaceResults += 	'<th class="summary" title="">Last Transition Time</th>'+"`n"
	$mailboxSpaceResults += '</tr>'+"`n"
	$mailboxSpaceResults += '</thead>'+"`n"
	$mailboxSpaceResults += '<tbody>'+"`n"
	
	$results = @()
	$unhealthy = @()
	$other = @()
	$healthy = @()
	
	foreach ($svr in $exchServers){
	
	foreach ($item in (Get-ServerHealth -Identity $svr -HealthSet "MailboxSpace")){  #| Where-Object {$_.AlertValue -like "Unhealthy"})){
#		if ($item.TargetResource -like "*MDATA*")
#		{
			$server = $item.Server
			$name = $item.Name
			$TargetResource = $item.TargetResource 
			$AlertValue = $item.AlertValue
			$ltt = $item.LastTransitionTime
			if ($item.AlertValue.ToString().Trim() -like "Unhealthy")
			{
				$unhealthy += '<tr><td>'+$server+'</td><td>'+$TargetResource+'</td><td>'+$name+'</td><td class="unhealthy">'+$AlertValue+'</td><td>'+$ltt+'</td></tr>'+"`n"
				Write-Host "$server | $name | $TargetResource | $AlertValue | $ltt" -ForegroundColor Red
			}
			if ($item.AlertValue.ToString().Trim() -like "Healthy")
			{
				$healthy += '<tr><td>'+$server+'</td><td>'+$TargetResource+'</td><td>'+$Name+'</td><td class="healthy">'+$AlertValue+'</td><td>'+$ltt+'</td></tr>'+"`n"
				Write-Host "$server | $name | $TargetResource | $AlertValue | $ltt" -ForegroundColor green
			}
	}
	}
	$mailboxSpaceResults += $unhealthy
	$mailboxSpaceResults += $other
	$mailboxSpaceResults += $healthy
	return $mailboxSpaceResults
}
	
#GET_MOUNT_BACKUP_STATUS
FUNCTION GET_MOUNT_BACKUP_STATUS ($exchServers)
{
	#https://docs.microsoft.com/en-us/exchange/high-availability/manage-ha/configure-db-properties?view=exchserver-2019
	$activeResults = @()
	
	$activeResults += '<div class="active_DBS">'+"`n"
	$activeResults += '<h2 class="DB_Header_Focus">Database Mount Location and Backup History</h2>'
	$activeResults += '<TABLE align="center">'+"`n"
	
	#$activeResults += '<TABLE>'+"`n"
	$activeResults += '<thead>'+"`n"
	$activeResults += '<tr>'+"`n" 
	$activeResults += 	'<th class="summary" title="DB Name">Name</th>'+"`n"
	$activeResults += 	'<th class="summary" title="Server this Active DB is mounted on">Mounted On Server</th>'+"`n"
	$activeResults += 	'<th class="summary" title="Time Stamp of Last Full Backup taken from Enterprise Backup Software. (Green = Backed up within 24 hours RED = Not Backed up within 24 hours">Last Full Backup</th>'+"`n"
	$activeResults += '</tr>'+"`n"
	$activeResults += '</thead>'+"`n"
	$activeResults += '<tbody>'+"`n"
	$dbs = Get-MailboxDatabase -Status | Select-Object Name, MountedOnServer, LastFullBackup | Sort-Object Name
	foreach ($db in $dbs)
	{
		
		if (($db.LastFullBackup -lt (Get-Date).Addhours(-15)) -or ([string]::IsNullOrEmpty($db.LastFullBackup)))
		{
			if (([string]::IsNullOrEmpty($db.LastFullBackup)))
			{
				$activeResults += '<tr><td>'+$db.Name+'</td><td>'+$db.MountedOnServer+'</td><td bgcolor="#ff3347">N/A or Never Backed up</td></tr>'+"`n"
			}
			else
			{
				$activeResults += '<tr><td>'+$db.Name+'</td><td>'+$db.MountedOnServer+'</td><td bgcolor="#ff3347">'+$db.LastFullBackup+'</td></tr>'+"`n"
			}
		}
		else
		{
			$activeResults += '<tr><td>'+$db.Name+'</td><td>'+$db.MountedOnServer+'</td><td bgcolor="#33ffb1">'+$db.LastFullBackup+'</td></tr>'+"`n"
		}
	}
	$activeResults += '</tbody>'+"`n"
	$activeResults += '</TABLE>'+"`n"
	$activeResults += '</div>'
	RETURN $activeResults
}

FUNCTION GET_PASSIVE_DBS ($exchServers)
{
	#https://docs.microsoft.com/en-us/exchange/client-developer/management/exchange-management-shell-cmdlet-input-and-output-types
	#https://docs.microsoft.com/en-us/exchange/high-availability/manage-ha/configure-db-properties?view=exchserver-2019
	$passiveResults = @()
	$passiveResults += '<div class="passive_DBS">'+"`n"
	$passiveResults += '<h2 class="DB_Header_Focus">Database Copy Status</h2>'
	$passiveResults += '<TABLE>'+"`n"
	$passiveResults += '<thead>'+"`n"
	$passiveResults += '<tr>'+"`n"
	$passiveResults += 	'<th class="summary" title="DB Copy Name and Server we are reporting on">DB Copy &amp; Server</th>'+"`n"
	$passiveResults += 	'<th class="summary" title="Status of the DB copy during time of this report">Status</th>'+"`n"
	$passiveResults += 	'<th class="summary" title="Indicates the number of log files waiting to be copied to the selected database copy. This field is relevant only for passive database copies.">Copy in Queue</th>'+"`n"
	$passiveResults += 	'<th class="summary" title="Indicates the number of log files waiting to be replayed into the selected database copy. This field is relevant only for passive database copies. DOUBLE-DIGIT VALUES WILL BE HIGHLIGHTED IN RED AS THESE NEED TO BE INVESTIGATED! ">Replay in Queue</th>'+"`n"
	$passiveResults += 	'<th class="summary" title="Displays the date and time stamp of the last log file that was inspected by the LogInspector on the selected database copy. This field is relevant only for passive database copies. On active database copies (replicated and stand-alone), this field will display never.">Last inspected Time</th>'+"`n"
	
	$passiveResults += 	'<th class="summary" title="">Current Replay Log Time</th>'+"`n"
	$passiveResults += 	'<th class="summary" title="">Latest Available Log Time</th>'+"`n"
	$passiveResults += 	'<th class="summary" title="">Last Copied Log Time</th>'+"`n"
	$passiveResults += 	'<th class="summary" title="">Last Replayed Log Time</th>'+"`n"
	$passiveResults += 	'<th class="summary" title="">Activation Preference</th>'+"`n"
	$passiveResults += '</tr>'+"`n"
	$passiveResults += '</thead>'+"`n"
	$passiveResults += '<tbody>'+"`n"
	
	foreach ($eServer in $exchServers)
	{
		$dbCopies = Get-MailboxDatabaseCopyStatus -server $eServer | Where-Object {$_.Status -notlike "Mounted"} | Sort-Object Name
		foreach ($item in $dbCopies)
		{
			$replayQueueLength = $null
			#CHUCK Ahern Double Digit "Replay Queue Length"  is not acceptible
			if ($item.ReplayQueueLength -ge 10)
			{
				$replayQueueLength = '<td bgcolor="#ff3347" align="center">'+$item.ReplayQueueLength+'</td>'
			}
			else
			{
				$replayQueueLength = '<td bgcolor="#33ffb1" align="center">'+$item.ReplayQueueLength+'</td>'
			}
			#RONNY 15min LAG between "Last Inspection Time" 
			$status = $item.Status.tostring().Trim()
			if ($status -notlike "Healthy")
			{
				$passiveResults += '<tr><td>'+$item.Name+'</td><td bgcolor="#ff3347">'+$item.Status+'</td><td align="center">'+$item.CopyQueueLength+'</td>'+$replayQueueLength+'<td>'+$item.CurrentReplayLogTime+'</td><td>'+$item.LastInspectedLogTime+'</td><td>'+$item.LatestAvailableLogTime+'</td><td>'+$item.LastCopiedLogTime+'</td><td>'+$item.LastReplayedLogTime+'</td><td align="right">'+$item.ActivationPreference+'</td></tr>'+"`n"
			}
			if ($status -like "Healthy")
			{
				$passiveResults += '<tr><td>'+$item.Name+'</td><td bgcolor="#33ffb1">'+$item.Status+'</td><td align="center">'+$item.CopyQueueLength+'</td>'+$replayQueueLength+'<td>'+$item.CurrentReplayLogTime+'</td><td>'+$item.LastInspectedLogTime+'</td><td>'+$item.LatestAvailableLogTime+'</td><td>'+$item.LastCopiedLogTime+'</td><td>'+$item.LastReplayedLogTime+'</td><td align="right">'+$item.ActivationPreference+'</td></tr>'+"`n"
			}
		}
	}
	$passiveResults += '</tbody>'+"`n"
	$passiveResults += '</TABLE>'+"`n"
	$passiveResults += '</div>'
	RETURN $passiveResults
}

FUNCTION GET_REPLICATION_HEALTH($exchServers)
{
	$repResults = @()
	$repResults += '<div class="replication_Results">'+"`n"
	$repResults += '<h2 class="DB_Header_Focus">Database Replication Health Check</h2>'
	$repResults += '<TABLE>'+"`n"
	$repResults += '<thead>'+"`n"
	$repResults += '<tr>'+"`n"
	$repResults += 	'<th class="summary" title="Exchange Server">Server</th>'+"`n"
	$repResults += 	'<th class="summary" title="Replication Health Check on Service Component">Replication Check</th>'+"`n"
	$repResults += 	'<th class="summary" title="Health Check Result for Service Component">Result</th>'+"`n"
	$repResults += 	'<th class="summary" title="If result is other than passed, text will be prosented about result condition">Error</th>'+"`n"
	$repResults += '</tr>'+"`n"
	$repResults += '</thead>'+"`n"
	$repResults += '<tbody>'+"`n"
	foreach ($svr in $exchServers)
	{
		foreach ($test in (Test-ReplicationHealth -server $svr))
		{
			if ($test.Result -notlike "*Passed*")
			{
				$repResults += '<tr><td>'+$test.Server+'</td><td>'+$test.Check+'</td><td bgcolor="#ff3347">'+$test.Result+'</td><td>'+$test.Error+'</td></tr>'+"`n"
			}
			else
			{
				$repResults += '<tr><td>'+$test.Server+'</td><td>'+$test.Check+'</td><td bgcolor="#33ffb1">'+$test.Result+'</td><td>'+$test.Error+'</td></tr>'+"`n"
			}
		}
	}
	$repResults += '</tbody>'+"`n"
	$repResults += '</TABLE>'+"`n"
	$repResults += '</div>'+"`n"
	RETURN $repResults
}

#SEND EMAIL
FUNCTION SEND_EMAIL ($htmlFile, $ts, $header, $body)
{
	#Add-Content $global:logfile1 "sendEmail Started"
	# --- Set Email Variables ---
	# Email Server
	$smtpServer = "owa.metrocu.org"													#Metro Email server used to process email
	$smtp = New-Object Net.Mail.SmtpClient($smtpServer)								#

	# Email Addresses
	$emailFrom = "Exchange_DB_Health_Check_Report_"+$env:COMPUTERNAME+"@Metrocu.org"				#from email address shown in the email
	$emailToSuccess = @("InformationTechnology@metrocu.org")
	#$emailToSuccess = @("PMarcantonio@metrocu.org","mpepi@metrocu.org")#,"mmcgovern@metrocu.org") #success email address that will recieve logs
	#$emailToSuccess = @("PMarcantonio@metrocu.org") #success email address that will recieve logs
 	
	#$emailBody += '<h2 align="center">Exchange_DB_Health_Check_Report</h2>
	#			<h3 align="center">Completed on '+ $ts + ' on Server '+$env:COMPUTERNAME+'</h3>
	#			<h3 align="center">Click <a href="file:///'+$htmlFile+'">here</a> for current and past reporting.</h3>'
    $emailbody += $header
    $emailBody += $body
	
	# Email Subject & Body Content 
	$subjectTextSuccess = "Exchange DB Health Check Script completed on server $serverName at $timeStamp"	#subject text for success messages
	foreach ($rcp in $emailToSuccess)
	{
		Send-MailMessage -from "$emailFrom" -to "$rcp" -subject "$subjectTextSuccess" -body $emailBody -BodyAsHtml -Attachments $htmlFile -smtpServer "$smtpServer"
	}
	#Add-Content $global:logfile1 "sendEmail Completed"
}

<#
	LAUNCH PAD OF PROGRAM
		- Pre-Condition 
			$webServer and $webDirectory are both set to the desired locations
		- Initialize Exchange dll for Exchange Shell Access
		- Obtain time stamps for email and html file name
		- Build HTML File to show results
		- Trigger building of HTML head details in HTML file
		- Obtain all Exchange Servers within DAG 
		- Obtain DISK_SUBSYSTEM details on each Exchange Server
		- Obtain DISK_SUBSYSTEM on each Exchange Server
		
#>
FUNCTION MAIN ()
{
	#https://www.oreilly.com/library/view/mastering-windows-powershell/9781787126305/7c8b356e-1d56-4262-92f4-53a14efa7f7e.xhtml
	INITIALIZE
	$webServer = "1168-POWERADMIN"
	$webDirectory = "Web Pages\Here"
	$timeStamp = get-date -uformat "%Y-%m-%d at %H:%M:%S"
	$fileTimeStamp = get-date -uformat "%Y-%m-%d_T%H_%M_%S"
	$logComplete = '\\'+$webServer+'\'+$webDirectory+'\Exchange_DB_Check'+$fileTimeStamp+'.html'
	#Remove-Item -LiteralPath $log -Force
	$header = BUILD_HTML_HEADER $timeStamp $logComplete
	$exchServers = (Get-ExchangeServer | Sort-Object Name).Name
	$a = GET_DB_TO_DISK_SUBSYSTEM $exchServers
	$b = GET_MOUNT_BACKUP_STATUS $exchServers
	$c = GET_PASSIVE_DBS $exchServers
	$d = GET_REPLICATION_HEALTH $exchServers
	Add-Content $logcomplete $a
	Add-Content $logcomplete $b
	Add-Content $logcomplete $c
	Add-Content $logcomplete $d
	SEND_EMAIL $logComplete $timeStamp $header $b
}
MAIN
