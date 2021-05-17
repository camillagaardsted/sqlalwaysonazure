param(
    [string]$adminADaccount
    , [string]$password
    , [string]$domainname 
    , [string]$DNSServerIP
)

# add to domain
$Password = ConvertTo-SecureString -AsPlainText $password -Force

$Credential = New-Object -TypeName PSCredential -ArgumentList "$domainname\$adminADAccount",$Password

Set-DnsClientServerAddress -InterfaceAlias "Ethernet 2" -ServerAddresses ($DNSServerIP)

Add-Computer -DomainName $domainname -credential $Credential -restart