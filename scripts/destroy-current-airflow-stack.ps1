# Removes only the legacy EC2 Airflow demo resources recorded in this repository.
# Run locally after `aws configure`:
#   powershell -ExecutionPolicy Bypass -File .\scripts\destroy-current-airflow-stack.ps1

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Region = 'us-east-1'
)

$ErrorActionPreference = 'Stop'

$expected = @{
    InstanceId           = 'i-039047a80fcba9629'
    ElasticIpAllocation  = 'eipalloc-083e45134cc5a5c48'
    VpcId                = 'vpc-03afa00dd9ebcd2cb'
    SubnetId             = 'subnet-09ec44714b74a7236'
    SecurityGroupId      = 'sg-00e9af223b9d1ce94'
    RouteTableId         = 'rtb-00c7410bbccfae61c'
    RouteAssociationId   = 'rtbassoc-03362fb63419347b5'
    InternetGatewayId    = 'igw-0ea378511f9899e6a'
    KeyPairName          = 'airflow-prod-dev-key'
}

function Invoke-AwsJson {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $output = & aws @Arguments --region $Region --output json 2>&1
    if ($LASTEXITCODE -ne 0) { throw "AWS CLI failed: $output" }
    if ([string]::IsNullOrWhiteSpace($output)) { return $null }
    return $output | ConvertFrom-Json
}

Write-Host "Verifying caller identity..." -ForegroundColor Cyan
$identity = Invoke-AwsJson sts get-caller-identity
Write-Host "Authenticated as $($identity.Arn) in account $($identity.Account)." -ForegroundColor Green

Write-Host "Validating the recorded EC2 instance..." -ForegroundColor Cyan
$instanceResponse = Invoke-AwsJson ec2 describe-instances --instance-ids $expected.InstanceId
$instance = $instanceResponse.Reservations[0].Instances[0]
if (-not $instance) { throw "Expected instance $($expected.InstanceId) was not found. Stopping." }
if ($instance.VpcId -ne $expected.VpcId -or $instance.SubnetId -ne $expected.SubnetId) {
    throw 'Instance VPC/subnet does not match the recorded Airflow stack. Stopping.'
}

$securityGroupIds = @($instance.SecurityGroups | ForEach-Object GroupId)
if ($securityGroupIds -notcontains $expected.SecurityGroupId) {
    throw 'Instance security group does not match the recorded Airflow stack. Stopping.'
}

Write-Host "Validated instance $($instance.InstanceId), state: $($instance.State.Name)." -ForegroundColor Green

Write-Host "Validating Elastic IP allocation..." -ForegroundColor Cyan
$addressResponse = Invoke-AwsJson ec2 describe-addresses --allocation-ids $expected.ElasticIpAllocation
$address = $addressResponse.Addresses[0]
if (-not $address) { throw "Expected Elastic IP allocation $($expected.ElasticIpAllocation) was not found. Stopping." }
if ($address.InstanceId -and $address.InstanceId -ne $expected.InstanceId) {
    throw 'Elastic IP is associated with an unexpected instance. Stopping.'
}

if ($PSCmdlet.ShouldProcess("legacy Airflow stack in $Region", 'destroy')) {
    if ($address.AssociationId) {
        Write-Host "Disassociating Elastic IP $($address.PublicIp)..." -ForegroundColor Yellow
        & aws ec2 disassociate-address --association-id $address.AssociationId --region $Region | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Could not disassociate Elastic IP.' }
    }

    Write-Host "Releasing Elastic IP allocation..." -ForegroundColor Yellow
    & aws ec2 release-address --allocation-id $expected.ElasticIpAllocation --region $Region | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not release Elastic IP.' }

    if ($instance.State.Name -notin @('terminated', 'shutting-down')) {
        Write-Host "Terminating EC2 instance..." -ForegroundColor Yellow
        & aws ec2 terminate-instances --instance-ids $expected.InstanceId --region $Region | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Could not terminate EC2 instance.' }
        & aws ec2 wait instance-terminated --instance-ids $expected.InstanceId --region $Region
        if ($LASTEXITCODE -ne 0) { throw 'Timed out waiting for EC2 termination.' }
    }

    Write-Host "Deleting key pair, security group, route association/table, subnet, gateway, and VPC..." -ForegroundColor Yellow
    & aws ec2 delete-key-pair --key-name $expected.KeyPairName --region $Region 2>$null
    & aws ec2 delete-security-group --group-id $expected.SecurityGroupId --region $Region
    & aws ec2 disassociate-route-table --association-id $expected.RouteAssociationId --region $Region
    & aws ec2 delete-route-table --route-table-id $expected.RouteTableId --region $Region
    & aws ec2 delete-subnet --subnet-id $expected.SubnetId --region $Region
    & aws ec2 detach-internet-gateway --internet-gateway-id $expected.InternetGatewayId --vpc-id $expected.VpcId --region $Region
    & aws ec2 delete-internet-gateway --internet-gateway-id $expected.InternetGatewayId --region $Region
    & aws ec2 delete-vpc --vpc-id $expected.VpcId --region $Region

    if ($LASTEXITCODE -ne 0) { throw 'One of the network cleanup commands failed. Check the command output.' }
    Write-Host 'Legacy Airflow EC2 stack removed successfully.' -ForegroundColor Green
    Write-Host 'Next: rotate/delete the root access key that was exposed, then build the new EKS demo stack.' -ForegroundColor Yellow
}
