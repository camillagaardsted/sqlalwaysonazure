# domaincontroller.ps1
param(
    [string]$password,
    [string]$domainname # .com is appended to this domainname
)

Install-WindowsFeature -Name AD-Domain-Services

$Password = ConvertTo-SecureString -AsPlainText $password -Force
# take first part of domainname as biosdomainname
$domainnameBIOS=$domainname.split(".")[0]
$Params = @{
 CreateDnsDelegation = $false
 DatabasePath = 'C:\Windows\NTDS'
 DomainMode = 'WinThreshold'
 DomainName = $domainname
 DomainNetbiosName = $domainnameBIOS
 ForestMode = 'WinThreshold'
 InstallDns = $true
 LogPath = 'C:\Windows\NTDS'
 NoRebootOnCompletion = $true
 SafeModeAdministratorPassword = $Password
 SysvolPath = 'C:\Windows\SYSVOL'
 Force = $true
}
Install-ADDSForest @Params

restart-computer