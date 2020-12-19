<h2>Exchange 2016 Database Check</h2>
<strong><u>Description</u>:</strong> 
  <br/>&nbsp;&nbsp;&nbsp;&nbsp;Exchange Database Health Check  
  
<strong><u>Usage</u>:</strong> 
  <br/>&nbsp;&nbsp;&nbsp;&nbsp;Can be launched in a Powershell session on a system that has Exchange Shell also installed on the System. Also great as a task manager task to run on schedule. This will provide some key insight on Db backup status, Mount locations and more.

<strong><u>Programmer</u>:</strong>
     <br/>&nbsp;&nbsp;&nbsp;&nbsp;Paul Marcantonio
     
<strong><u>Date</u>:</strong>
     <br/>&nbsp;&nbsp;&nbsp;&nbsp;June 2 2019
     
<strong><u>Version</u>:</strong>
     <br/>&nbsp;&nbsp;&nbsp;&nbsp;2.7

<strong><u>Pre-Condition</u>:</strong>
  <br/>&nbsp;&nbsp;&nbsp;&nbsp;Powershell be installed and with execution policy set to remote signed
  Exchange Powershell Shell (version to match Exchange Server version) is installed on this system as well
  User that this script runs under has Exchange enterprise Level rights to retrieve information (in this case, member of Domain Admins Group)

<strong><u>Project Title</u>:</strong>
<br/>&nbsp;&nbsp;&nbsp;&nbsp;Exchange 2016 Database Check

<strong><u>Objective</u>:</strong>
    <br/>&nbsp;&nbsp;&nbsp;&nbsp;Obtain the following Information from each Db and Exchange Server in DAG
	<ul>
		<li>Server DB Disk Subsystem usage (DB Data and/or Logs)</li> 
		<li>DB Backup Time Stamp (time the backup bit was flipped. NOTE: need to cross ref backup software validation)</li>
		<li>DB Copy Status (across all servers)</li>
		<li>DB Replication Health Check (across all servers)</li>
	</ul>
	&nbsp;&nbsp;&nbsp;&nbsp;Send Email to team with html table results and HTML file attachement

<strong><u>Pre-Condition(s)</u>:</strong>
     <br/>&nbsp;&nbsp;&nbsp;&nbsp;Powershell Execution Policy set to Remove Signed (Get-ExecutionPolicy, Set-ExecutionPolicy RemoteSigned)
     <br/>&nbsp;&nbsp;&nbsp;&nbsp;Exchange Management Shell installed on the scripting server (Using the Exchange ISO and choose management console only)
     <br/>&nbsp;&nbsp;&nbsp;&nbsp;User this script executes under should have Exchange Enterprise rights (https://docs.microsoft.com/en-us/powershell/exchange/find-exchange-cmdlet-permissions?view=exchange-ps)
     <br/>&nbsp;&nbsp;&nbsp;&nbsp;The server this script runs on must be on the "allow relay" on any and all load balancers infront of exchange and within exchange

<strong><u>Post-Condition(s)</u>:</strong>
     <br/>&nbsp;&nbsp;&nbsp;&nbsp;New HTML file with script data included
     <br/>&nbsp;&nbsp;&nbsp;&nbsp;Email sent to the desired email list with:
          <ul>
            <li>HTML backup summary table included in message body</li>
            <li>Copy of the HTML file with all details from script.</li>
          </ul>
 <strong><u>Installation</u>:</strong>
     <br/>&nbsp;&nbsp;&nbsp;&nbsp;Make sure Powershell version 3 or above is installed on the server (Server Role and Features (Windows Powershell)
     <br/>&nbsp;&nbsp;&nbsp;&nbsp;Install Exchange 2016 Management tools https://docs.microsoft.com/en-us/Exchange/plan-and-deploy/post-installation-tasks/install-management-tools?view=exchserver-2019
     
<strong><u>Contributing</u>:</strong>
    <br/>&nbsp;&nbsp;&nbsp;&nbsp;None

<strong><u>Citations</u>:</strong>
     <br/>&nbsp;&nbsp;&nbsp;&nbsp;None
	 
<strong><u>Output Examples</u>:</strong>
    <br/>&nbsp;&nbsp;&nbsp;&nbsp;Healthy results from script run (Exchange_DB_Check2020-12-04_T16_00_09-Healthy.html)
    <br/>&nbsp;&nbsp;&nbsp;&nbsp;Errors found from script run (Exchange_DB_Check2020-11-20_T14_49_54 Errors.html) 
    
	 
