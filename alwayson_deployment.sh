#alwayson_deployment.sh

# May 2021

#Update based on your organizational requirements
Location=northeurope
ResourceGroupName=SQLEurope
NetworkSecurityGroup=NSG-EuropeGroup
VNetName=VNet-AzureVMsEurope
VNetAddress=10.10.0.0/16
SubnetName=Subnet-AzureEurope
SubnetAddress=10.10.10.0/24
VMSize=Standard_DS3_v2
DataDiskSize=20
AdminUsername=suadmin
AdminPassword=SuperUsers1234..
SQLNODE1=SQL01
SQL1IP=10.10.10.4
SQLNODE2=SQL02
SQL2IP=10.10.10.5
AvailabilitySet=AvSetEurope
DCVMSize=Standard_DS1_v2
DCName=AZDC01
DCIP=10.10.10.10
DomainName=contoso.com

# Create a resource group.
az group create --name $ResourceGroupName \
                --location $Location

# Create a network security group
az network nsg create --name $NetworkSecurityGroup \
                      --resource-group $ResourceGroupName \
                      --location $Location

# Create a network security group rule for port 3389.
az network nsg rule create --name PermitRDP \
                           --nsg-name $NetworkSecurityGroup \
                           --priority 1000 \
                           --resource-group $ResourceGroupName \
                           --access Allow \
                           --source-address-prefixes "*" \
                           --source-port-ranges "*" \
                           --direction Inbound \
                           --destination-port-ranges 3389

# Create a virtual network.
az network vnet create --name $VNetName \
                       --resource-group $ResourceGroupName \
                       --address-prefixes $VNetAddress \
                       --location $Location \

# Create a subnet
az network vnet subnet create --address-prefix $SubnetAddress \
                              --name $SubnetName \
                              --resource-group $ResourceGroupName \
                              --vnet-name $VNetName \
                              --network-security-group $NetworkSecurityGroup

# Create an availability set.
az vm availability-set create --name $AvailabilitySet \
                              --resource-group $ResourceGroupName \
                              --location $Location


# Create a domaincontroller
az vm create \
    --resource-group $ResourceGroupName \
    --name $DCName \
    --size $DCVMSize \
    --image Win2019Datacenter \
    --admin-username $AdminUsername \
    --admin-password $AdminPassword \
    --data-disk-sizes-gb $DataDiskSize \
    --data-disk-caching None \
    --nsg $NetworkSecurityGroup \
    --private-ip-address $DCIP \
    --subnet $SubnetName \
    --vnet-name $VNetName \
    --no-wait


# Create two virtual machines.
az vm create \
    --resource-group $ResourceGroupName \
    --availability-set $AvailabilitySet \
    --name $SQLNODE1 \
    --size $VMSize \
    --image MicrosoftSQLServer:SQL2017-WS2016:SQLDEV:14.1.210218 \
    --admin-username $AdminUsername \
    --admin-password $AdminPassword \
    --data-disk-sizes-gb $DataDiskSize \
    --data-disk-caching None \
    --nsg $NetworkSecurityGroup \
    --private-ip-address $SQL1IP \
    --subnet $SubnetName \
    --vnet-name $VNetName \
    --no-wait

# Create two virtual machines.
az vm create \
    --resource-group $ResourceGroupName \
    --availability-set $AvailabilitySet \
    --name $SQLNODE2 \
    --size $VMSize \
    --image MicrosoftSQLServer:SQL2017-WS2016:SQLDEV:14.1.210218 \
    --admin-username $AdminUsername \
    --admin-password $AdminPassword \
    --data-disk-sizes-gb $DataDiskSize \
    --data-disk-caching None \
    --nsg $NetworkSecurityGroup \
    --private-ip-address $SQL2IP \
    --subnet $SubnetName \
    --vnet-name $VNetName

wget https://raw.githubusercontent.com/camillagaardsted/sqlalwaysonazure/main/domaincontroller.ps1
# https://docs.microsoft.com/en-us/cli/azure/vm/run-command?view=azure-cli-latest
az vm run-command invoke  --command-id RunPowerShellScript --name $DCName -g $ResourceGroupName --scripts @domaincontroller.ps1 --parameters 'password='$AdminPassword 'domainname='$DomainName

# while the dc reboots we create a storage account 

# create storage account
az storage account create -n $StorageAccountName -g $ResourceGroupName -l $Location --sku Standard_LRS --kind StorageV2 --access-tier Hot --https-only true

Key1=$(az storage account keys list --account-name $StorageAccountName --query [0].value -o tsv)

serviceAccountAD=sqlserver@$DomainName
adminAccountAD=$AdminUsername@$DomainName

# create group for the cluster
az sql vm group create -n agcluster -l $Location -g $ResourceGroupName --image-offer SQL2017-WS2016 --image-sku Developer --domain-fqdn $DomainName --operator-acc $adminAccountAD --bootstrap-acc $adminAccountAD --service-acc $serviceAccountAD --sa-key $Key1 --storage-account 'https://'$StorageAccountName'.blob.core.windows.net'


# create user in AD for sql server 

#az vm run-command invoke  --command-id RunPowerShellScript --name $DCName -g $ResourceGroupName --scripts 'param($password) $PasswordSecure = ConvertTo-SecureString -AsPlainText $password -Force;new-aduser -name sqlserver -samaccountname sqlserver -AccountPassword $PasswordSecure -Enabled $true' --parameters 'password='$AdminPassword


wget https://raw.githubusercontent.com/camillagaardsted/sqlalwaysonazure/main/sqlserveraddtodomain.ps1

az vm run-command invoke  --command-id RunPowerShellScript --name $SQLNODE1 -g $ResourceGroupName --scripts @sqlserveraddtodomain.ps1 --parameters 'adminADaccount='$AdminUsername 'password='$AdminPassword 'domainname='$DomainName 'DNSServerIP='$DCIP

az vm run-command invoke  --command-id RunPowerShellScript --name $SQLNODE2 -g $ResourceGroupName --scripts @sqlserveraddtodomain.ps1 --parameters 'adminADaccount='$AdminUsername 'password='$AdminPassword 'domainname='$DomainName 'DNSServerIP='$DCIP


# Register Enterprise or Standard self-installed VM in Lightweight mode
az sql vm create --name $SQLNODE1 --resource-group $ResourceGroupName --location $Location --license-type payg
az sql vm create --name $SQLNODE2 --resource-group $ResourceGroupName --location $Location --license-type payg


az sql vm add-to-group -n $SQLNODE1 -g $ResourceGroupName --sqlvm-group agcluster -b $AdminPassword -p $AdminPassword -s $AdminPassword
az sql vm add-to-group -n $SQLNODE2 -g $ResourceGroupName --sqlvm-group agcluster -b $AdminPassword -p $AdminPassword -s $AdminPassword


