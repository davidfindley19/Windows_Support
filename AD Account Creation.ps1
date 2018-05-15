<#
.SYNOPSIS
    Scripted account and mailbox creation for new users.
.DESCRIPTION
    This is accomplished by prompting with a form for the new user's information. The script will truncate the full name to create the username based off company IT standards. After the username
    is created, based off the role, groups/permissions will be assigned to the user. The final step of this script is to create the mailbox on our Exchange server.
.NOTES
    Author: David Findley
    Date: May 15, 2018
#>

Write-Host "Manual Account and Mailbox Creation"

# Importing Active Directory module for AD manipulation.
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

# Just grabbing current user credentials. This is assuming user executing script has privileges to modify domain users.
$UserCredential = Get-Credential "$env:USERDOMAIN\$env:USERNAME"

# Prompting for new user's full name.
$FirstName = Read-Host -Prompt "Enter the user's first name:"
$LastName = Read-Host -Prompt "Enter the user's last name:"

# Creating username based off of first initial and last name standard.
$UserName = $($FirstName.Substring(0,1) + $LastName).ToLower()
$FullName = "$FirstName " + "$LastName"
$SamAccountName = $UserName
$GivenName = $FirstName
$Surname = $LastName
$EmailAddress = $UserName + "@business.com"
$StreetAddress = "12345 S. Road"
$City = "City"
$State = "State"
$Company = "Business Name"
$PhoneNumber = "555-555-5555"
$Account = (dsquery user -samid $UserName)
$AccountPass = "password1"
$EncryptPass = convertto-securestring $AccountPass -asplaintext -force

# Sanity check on username creation. 
if ($Account -eq $null) {
    Write-Host "The following username is available: $UserName. Would you like to continue? "
    $Readhost = Read-Host "[Y]es or [N]o"
    switch ($Readhost) {
        Y {Write-Host "Great! Continuing with this username. "; $Create = $true } # Much easier than a bunch of if/else statements
        N {Write-Warning "Let's try that again."; $Create = $false }
        Default {"Invalid response. Exiting script"; exit}
    }
}
else {
    Write-Warning "This username, $UserName, is not available. Please try again." # Right now this exits the script, but it will eventually allow manual entry of a username.
    exit
}
if ($Create -eq $true) {
    try {
        New-ADUser  -Name $FullName `
                    -SamAccountName $SamAccountName `
                    -GivenName $Surname 
        Write-Host "$FullName : Account created successfully."
        $JobTitle = Read-Host -Prompt "What is $FirstName $LastName's job title?"
        Write-Host "$FullName : Account created successfully." 
    }
        
    catch {
        Write-Warning "$FullName : Error occurred while creating account. $_"
        exit

    }
}
else {
    Write-Host "Exiting Script"
    exit
}

# We'll now fill in the missing information for the created account.
if (dsquery user -samid $UserName) {
    Get-ADUser $UserName | Set-ADUser   -GivenName $FirstName `
                                        -Surname  $LastName `
                                        -EmailAddress $EmailAddress `
                                        -Company $Company `
                                        -UserPrincipalName "$UserName@domain.com" `
                                        -Enable $true `
                                        -DisplayName "$FirstName $LastName"
                                        -ChangePasswordAtLogon:$false `
                                        -Title $JobTitle `
                                        -MobilePhone $PhoneNumber `
                                        -PasswordNeverExpires $true                                   
}   
else {
    Write-Host "User does not exist in AD."
 
# Setting user account password parameters
Get-ADUser $UserName | Set-ADAccountPassword -NewPassword $EncryptPass 

}
# Adding user to group(s) based off of the team they will be joining.
$TeamName = Read-Host "What group will $FirstName $LastName be a part of? Please enter one: Executive, Accounting, IT "
    if ($TeamName -eq "Executive") {
        Add-ADPrincipalGroupMembership -Identity:"CN=$FirstName $LastName,CN=Users,DC=servername,DC=local" -MemberOf:"CN=Full Gropu Name,CN=Users,DC=servername,DC=local", "CN=GIS Portal Publishers,CN=Users,DC=servername,DC=local", `
        "CN=GIS Map Services,CN=Users,DC=servername,DC=local", "CN=GIS Map Publishers,CN=Users,DC=servername,DC=local", "CN=GIS Internal Portal Users,CN=Users,DC=servername,DC=local", `
        "CN=GIS Foreign User Map Services,CN=Users,DC=servername,DC=local" -Server:"servername.domainname.local"
        Write-Host "Setting $FirstName $LastName's manager." # Added here since it adds manager based on role/team you select. 
        Set-ADUser -Identity:"CN=$FirstName $LastName,CN=Users,DC=servername,DC=local" -Manager:"CN=First Name,CN=Users,DC=servername,DC=local" -Department:"Deparment Name for user" -Server:"servername.domainname.local" #Full path for manager account.
        Write-Host "User, $FirstName $LastName, successfully added to group."
        }
            elseif ($TeamName -eq "Accounting"){
            Add-ADPrincipalGroupMembership -Identity:"CN=$FirstName $LastName,CN=Users,DC=servername,DC=local" -MemberOf:"CN=Full Group Name,CN=Users,DC=servername,DC=local", "CN=Full Group Name,CN=Users,DC=servername,DC=local", `
            "CN=Full Group Name,CN=Users,DC=servername,DC=local", "CN=Full Group Name,CN=Users,DC=servername,DC=local", "CN=Full Group Name,CN=Users,DC=servername,DC=local", `
            "CN=Full Group Name,CN=Users,DC=servername,DC=local" -Server:"servername.domainname.local"
            Write-Host "User, $FirstName $LastName, successfully added to Accounting Groups."
            }
                elseif ($TeamName -eq "IT") {
                Add-ADPrincipalGroupMembership -Identity:"CN=$FirstName $LastName,CN=Users,DC=servername,DC=local" -MemberOf:"CN=Full Group Name,CN=Users,DC=servername,DC=local", "CN=Full Group Name,CN=Users,DC=servername,DC=local", `
                "CN=Full Group Name,CN=Users,DC=servername,DC=local", "CN=Full Group Name,CN=Users,DC=servername,DC=local", "CN=Full Group Name,CN=Users,DC=servername,DC=local", `
                "CN=Full Group Name,CN=Users,DC=servername,DC=local" -Server:"servername.domainname.local"
                Write-Host "User, $FirstName $LastName, successfully added to IT Groups."
                }
        
    else {
    Write-Host "User not added to any groups."
    exit
    }

# Enabling new user's mailbox.
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://exchange/powershell -Authentication Kerberos -Credential $UserCredential # Connecting to remote powershell session on exchange server
Import-PSSession $Session
New-Mailbox -name $FullName -UserPrincipalName "$UserName@email.com" -SamAccountName $SamAccountName -FirstName $FirstName -LastName $LastName # Enabling the account
Remove-PSSession $Session # Closed. This wraps up the account creation script. 