function Get-KeePassEntryByTitle {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline=$True,
        Mandatory=$True)]
        [PSObject]$InputObject
    )
    # Parameters
    # DBProfile set default
    # GroupPath set default
    # Title limit options - VMC, Munich, Romania, VTLab
    BEGIN {
        # Ask for Keepass password
        $VaultPassword = Read-Host -Prompt "Please enter your vault password" -AsSecureString
        # Set the Keepass DBProfile name
        $DBProfile = 'vSphere'
        # TODO - check that Keepass is all in place
        # TODO - check that modules are installed - 
        #           Install-Module -Name PoShKeePass -Scope CurrentUser
        #           Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
        #           Import-Module poshkeepass
        #           New-KeePassDatabaseConfiguration -DatabaseProfileName vSphere -Default -DatabasePath "PathTo\keepassdb.kdbx" -UseMasterKey
        # TODO - ensure that the profile exists -   New-KeePassDatabaseConfigurationProfile -DatabaseProfileName vSphere -Default -DatabasePath "C:\Users\tony\Proton Drive\anthony.elder\My files\AAPD\WorkingFolders\NTTData\VMWare\virtualinsanity.kdbx"
        # TODO - update this to include AD accounts too
    }

    PROCESS {
       foreach ($item in $InputObject) {
        # Retrieve the Keepass entry details and pull from KeePass
        $KeepassTitle = $_.KeePassEntry
        $KeepassEntry = Get-KeePassEntry -Title $KeepassTitle -AsPlainText -DatabaseProfileName $DBProfile -MasterKey $VaultPassword
        #Write-Output $KeepassEntry.userName, $KeepassEntry.Password
        # Convert to SecureString
        $secStringPassword = ConvertTo-SecureString $KeepassEntry.Password -AsPlainText -Force
        # Create the credential object
        $vCenterCredential = New-Object System.Management.Automation.PSCredential ($KeepassEntry.userName, $secStringPassword)
        # Add the Credential to the object
        $InputObject | Add-Member -MemberType NoteProperty -Name Credential -Value $vCenterCredential
       } #foreach
       return $InputObject
    } #PROCESS
    END {

    }
} #function

function Connect-ToVCenter {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [PSObject]$InputObject
    )
    begin{
    # Set the Power CLI config to avoid messages
    Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false | Out-Null
    Set-PowerCLIConfiguration -Scope User -DefaultVIServerMode Multiple -Confirm:$false | Out-Null
    Set-PowerCLIConfiguration -Scope User -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
    } #begin
    process {

        $Name = $_.name
        $Hostname = $_.hostname
        $Creds = $_.Credential

        Write-Output "Connecting to $Name, which is the $Hostname vCenter using the $UsingCreds credentials from KeePass which is $Creds"
        try {
            Write-Output "Connecting to $Name....."
            Connect-VIServer -Server $Hostname -Credential $Creds -ErrorAction Stop | Out-Null
            Write-Output "Connected to $Hostname"
        }
        catch {
           Write-Host "Failed to connect to $Hostname. Error: $_.Exception.Message"
        } # try/catch
    } # process
}# function


function Test-VPNConnection {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Filter,
        [bool] $VPNConnected = $false
    )

    $vpnConnection = Get-NetIPInterface | Where-Object {$_.InterfaceAlias -like $Filter}
    if ($vpnConnection) {
        $VPNConnected = $true
    }
    return $VPNConnected
}

function New-ObjectfromJSON {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline=$True,
        Mandatory=$True)]
        [string]$Filename
    )
    # Parameters
    BEGIN {
    }

    PROCESS {
        $OutputObject = Get-Content $Filename -Raw | ConvertFrom-Json
        return $OutputObject
        Write-Output "This is the object: $OutputObject"
    } #PROCESS
    END {

    }
} #function

# Main body of controller script
$JSONFile = "C:\\multiplevcenters.json"
# Check we are on the VPN first
if (Test-VPNConnection -Filter "*domain.com*"){
    $JSONFile | New-ObjectfromJSON  | Get-KeePassEntryByTitle | Connect-ToVCenter
    Write-Output $global:defaultviservers
}
else {
        Write-Output "You are not connected to the VPN. Exiting...."
        exit
}

