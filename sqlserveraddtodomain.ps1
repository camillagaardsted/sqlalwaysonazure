param(
    [string]$adminADaccount
    , [string]$password
    , [string]$domainname 
    , [string]$DNSServerIP
)

# add to domain
$PasswordSecure = ConvertTo-SecureString -AsPlainText $password -Force
$user = "$domainname\$adminADAccount"
$Credential = New-Object -TypeName PSCredential -ArgumentList $user,$PasswordSecure

Set-DnsClientServerAddress -InterfaceAlias "Ethernet 2" -ServerAddresses ($DNSServerIP)

Add-Computer -DomainName $domainname -credential $Credential -restart