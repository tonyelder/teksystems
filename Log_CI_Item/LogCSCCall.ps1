###########################################################################################################################################
# ASSUMPTIONS
#
# This script assumes the following:
# 
# The server(s) to be added are VM(s) in the EDC
# They are all part of the same project (based on Clarity Code and iServ)
# It assumes that you are using your _a account (this will change!!)
# It assumes that you are building a standard VM - this is then classified as a Distributed server
# At present no validation is carried out on user input
# You have the PowerCLI and AD modules installed and imported
# The machine is on the domain 
# The VLAN XML file is required to get the default gateway
# The scope for VIServers must be multiple to allow searching of VMs
#
###########################################################################################################################################

function Get-UserInput 
	{
		# Derive user info from _a account (this is used to log in to CSC)
		$user = whoami
		$usernodomain = $user.TrimStart("euro\")
		$standarduser = $usernodomain.TrimEnd("_a")
		$standarduserobject = (Get-ADUser $standarduser -Properties *)
		$script:Customer = $standarduserobject.EmployeeID
		$script:CustomerEmail = $standarduserobject.EmailAddress
		$script:engineer = $standarduserobject.GivenName + " " + $standarduserobject.Surname
		$PhoneNumberCheck = $standarduserobject.telephoneNumber
		if ($PhoneNumberCheck) 
			{$script:CustomerPhone = $PhoneNumberCheck}
		else
			{$script:CustomerPhone = Read-Host "Please enter your office telephone number"}
		$script:servername = Read-Host "Please enter the server name"
		
		$Environmentoptions = [System.Management.Automation.Host.ChoiceDescription[]]($Destructive,$Development,$Integration,$PVS,$Production,$PFIX,$Release,$Sys,$Training)
		$Environmentresult = $host.ui.PromptForChoice($Environmenttitle, $EnvironmentMessage, $Environmentoptions, 0) 
		switch ($Environmentresult)
			{
				0 {$script:serverEnvironment = "Destructive"}
				1 {$script:serverEnvironment = "Development"}
			}
		
		$script:serverApps = (Read-Host "Please enter the application that this server is for")
		$script:appOwner = (Read-Host "Please enter the application owner")
		$script:clarityCode = (Read-Host "Please enter the project Clarity Code")
		$script:iServ = (Read-Host "Please enter the project iServ code")

		$Environmenttitle = "Environment"
		$EnvironmentMessage = "Please enter the Environment for the server"


		$Destructive = New-Object System.Management.Automation.Host.ChoiceDescription "D&estructive"
		$Development = New-Object System.Management.Automation.Host.ChoiceDescription "&Development"
		$Integration = New-Object System.Management.Automation.Host.ChoiceDescription "&Integration"
		$PVS = New-Object System.Management.Automation.Host.ChoiceDescription "P&VS"
		$Production = New-Object System.Management.Automation.Host.ChoiceDescription "&Production"
		$PFIX = New-Object System.Management.Automation.Host.ChoiceDescription "P&FIX"
		$Release = New-Object System.Management.Automation.Host.ChoiceDescription "&Release"
		$Sys = New-Object System.Management.Automation.Host.ChoiceDescription "&Sys"
		$Training = New-Object System.Management.Automation.Host.ChoiceDescription "&Training"

		$Environmentoptions = [System.Management.Automation.Host.ChoiceDescription[]]($Destructive,$Development,$Integration,$PVS,$Production,$PFIX,$Release,$Sys,$Training)
		$Environmentresult = $host.ui.PromptForChoice($Environmenttitle, $EnvironmentMessage, $Environmentoptions, 0) 
		switch ($Environmentresult)
			{
				0 {$script:serverEnvironment = "Destructive"}
				1 {$script:serverEnvironment = "Development"}
				2 {$script:serverEnvironment = "Integration+Testing"}
				3 {$script:serverEnvironment = "Performance+Volume+Stress+(PVS)"}
				4 {$script:serverEnvironment = "Production"}
				5 {$script:serverEnvironment = "Production+Fix"}
				6 {$script:serverEnvironment = "Release+Management"}
				7 {$script:serverEnvironment = "System+Testing"}
				8 {$script:serverEnvironment = "Training"}
			}
	}

function Get-ServerInfo 
    {
		# Connect to the vCenter servers (assumption made here)
		Write-Output "Connecting to vSphere instances and retrieving server info....."
		Set-PowerCLIConfiguration -DefaultVIServerMode Multiple -Scope Session -confirm:$false
		Connect-VIServer -force vcenter1 -WarningAction SilentlyContinue | Out-Null
		Connect-VIServer -force vcenter2 -WarningAction SilentlyContinue | Out-Null
		# SUPPRESS/TIDY UP OUTPUT HERE
		
		# Retrieve the OS
		$script:OperatingSystem = (Get-VM $servername ).GuestId
		if ($OperatingSystem -like "windows*")
			{			
			$script:serverOS = "Windows"
			}
		elseif 	($OperatingSystem -like "rhel*")
			{			
			$script:serverOS = "Linux"
			}		
	
		# Retrieve hardware information
		$script:ramSize 	= (Get-VM $servername).MemoryGB
		$script:numberCpu 	= (Get-VM $servername).NumCPU
		$script:cpuType	= (Get-VMHost (Get-VM $servername).VMHost).ProcessorType
		$script:IPAddress 	= (Test-Connection -Count 1 $servername).IPV4Address.IPAddressToString	
		
		# Pull vCenterName from Uid property of VM and manipulate string
		$vcenter = (Get-VMHost (get-vm $servername).VMHost).Uid
		$vcentersplit1 = $vcenter.Split('@')[1]
		$script:vCenterName = $vcentersplit1.Split(':')[0]
		
		if ($vCenterName -match "vcenter1")
			{$script:sitecode = "SITE1"}
		elseif ($vCenterName -match "vcenter2")
			{$script:sitecode = "SITE2"}
		
		# Retrieve vCenter cluster
		$script:clusterName = ((Get-VMHost (get-vm $servername).VMHost).Parent).Name
		
		# Calculate build date from VI event log
		$vmevents = Get-VIEvent $servername -MaxSamples([int]::MaxValue) | Where-Object {$_.FullFormattedMessage -like "Deploying*"} 
		#$vmevents.CreatedTime
		$script:serverAddDate = get-date ($vmevents.CreatedTime) -Format MM/dd/yyyy
		
		# Assumed constants (since assumption is that these are VMs
		$script:serverHwModel="VMware Virtual Platform" #constant
		$script:serverHWType="x64-based PC" #constant
		$script:CSCFormURL = "redacted"
		$script:serverType = "Distributed"
		$script:serverDomain = "domain.com"
		$script:virtualMachine = "Yes"
		# Retrieve Default gateway from VLAN
		$VLANXML = [XML](Get-Content C:\Scripting\CIAutomation\VLANs.xml)
		$VLAN = (Get-VM $servername | Get-NetworkAdapter).NetworkName
		$script:gateway = $VLANXML.DataCentre.$sitecode.VLAN.$VLAN.DefaultGateway
		Write-Output "The server name is $servername"
		Write-Output "The VLAN is $VLAN"
		Write-Output "The sitecode is $sitecode"
		Write-Output "The gateway is $gateway"
    }


# Function to submit call and return SD numbers	
function Submit-Request	
	{
# Don't move the string below - it's a here-string!!	
$NewDescriptionString = @"
Server Type: $serverType
Device/Service Name(Computer Name): $servername
IP Address: $IPAddress
Domain: $serverDomain
Environment: $serverEnvironment
Default Gateway: $gateway
Subtype: $serverOS
Is server a virtual machine? $virtualMachine	
Cluster Name: $clusterName	
V Center Name: $vCenterName	
Site Code: $sitecode
Server Hardware Model: $serverHwModel
Server Hardware Type: $serverHWType
RAM Size: $ramSize
CPU Type: $cpuType
Number of CPUs: $numberCpu
Application(s): $serverApps
Application Owner: $appOwner	
Engineer: $engineer
Clarity Code: $clarityCode
iServ / Project Number: $iServ
Server Add Date: $serverAddDate	
"@

		Write-Output $NewDescriptionString
		# Connect to CSC and log in
		$CSCURL = "redacted"
		$CSC = Invoke-WebRequest $CSCURL -SessionVariable SessionVariable
		$Form = $CSC.Forms[0]
		$Form.Fields["EIDPIN"]=$Customer
		$GetLoggedIn = Invoke-WebRequest -Uri ("redacted" + $Form.Action) -WebSession $SessionVariable -Method POST -Body $Form.Fields

		# Go to Distributed Server registration form and fill in with details from previous functions
		$ServerForm = Invoke-WebRequest -Uri ($CSCFormURL) -WebSession $SessionVariable
		$SubmitForm = $ServerForm.Forms[0]

		$SubmitForm.Fields["AutoRouting"]="OHD1097.5,OHD1097.8"
		$SubmitForm.Fields["Description"]=$NewDescriptionString
		$SubmitForm.Fields["Escalate"]="1"
		$SubmitForm.Fields["QuestionCount"]="0"
		$SubmitForm.Fields["CaseCount"]="2"
		$SubmitForm.Fields["Customer"]=$Customer
		$SubmitForm.Fields["CustomerEmail"]=$CustomerEmail
		$SubmitForm.Fields["CustomerPhone"]=$CustomerPhone
		$SubmitForm.Fields["computername"]=$servername
		$SubmitForm.Fields["ip_add"]=$IPAddress
		$SubmitForm.Fields["serverDomain"]=$serverDomain
		$SubmitForm.Fields["serverEnvironment"]=$serverEnvironment
		$SubmitForm.Fields["gateway"]=$gateway
		$SubmitForm.Fields["serverOS"]=$serverOS
		$SubmitForm.Fields["virtualMachine"]=$virtualMachine
		$SubmitForm.Fields["clusterName"]=$clusterName
		$SubmitForm.Fields["vCenterName"]=$vCenterName
		$SubmitForm.Fields["sitecode"]=$sitecode
		$SubmitForm.Fields["serverHwModel"]=$serverHwModel
		$SubmitForm.Fields["serverHWType"]=$serverHWType
		$SubmitForm.Fields["ramSize"]=$ramSize
		$SubmitForm.Fields["cpuType"]=$cpuType
		$SubmitForm.Fields["numberCpu"]=$numberCpu
		$SubmitForm.Fields["serverApps"]=$serverApps
		$SubmitForm.Fields["appOwner"]=$appOwner
		$SubmitForm.Fields["engineer"]=$engineer
		$SubmitForm.Fields["clarityCode"]=$clarityCode
		$SubmitForm.Fields["iServ"]=$iServ
		$SubmitForm.Fields["serverAddDate"]=$serverAddDate
		$SubmitForm.Fields["dateReq"]=$dateReq

		# Submit the info and log the call!
        $LogCall = Invoke-WebRequest -Uri ("redacted" + $ServerForm.Forms[0].Action) -WebSession $SessionVariable -Method POST -Body $SubmitForm.Fields
        
        # Take the response and pull out the call reference(s)
        $TicketNos = $LogCall.ParsedHtml.body.innerText -Split("\n") | where {$_ -match "following ticket"}	
        $string = $TicketNos.Split(":")[1].Trim().Replace(" ","")
        $separator = ","
        $option = [System.StringSplitOptions]::RemoveEmptyEntries
        $CallReferences = $string.Split($separator,$option)
        Write-Output "The following call(s) have been logged in CSC: $string"
}
	
Get-UserInput
Get-ServerInfo
Submit-Request

		
