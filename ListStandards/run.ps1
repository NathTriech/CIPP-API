using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME -message 'Accessed this API' -Sev 'Debug'
$Table = Get-CippTable -tablename 'standards'
#Migrate old standards to table Storage
if (Test-Path 'Cache_Standards\*.Standards.json') {
    $Migrate = Get-ChildItem 'Cache_Standards\*.Standards.json' | ForEach-Object {
        $StandardsFile = Get-Content "$($_)"
        $Entity = @{
            JSON         = "$StandardsFile"
            RowKey       = "$(($StandardsFile | ConvertFrom-Json).Tenant)"
            PartitionKey = 'standards'
        }
        Add-AzDataTableEntity @Table -Entity $Entity -Force
    }
}
$Filter = "PartitionKey eq 'standards'" 

try { 
    if ($Request.query.TenantFilter) { 
        $tenants = (Get-AzDataTableRow @Table -Filter $Filter).JSON | ConvertFrom-Json -ErrorAction Stop | Where-Object Tenant -EQ $Request.query.tenantFilter
    }
    else {
        $Tenants = (Get-AzDataTableRow @Table -Filter $Filter).JSON | ConvertFrom-Json -ErrorAction Stop
    }
}
catch {}

$CurrentStandards = foreach ($tenant in $tenants) {
    [PSCustomObject]@{
        displayName = $tenant.tenant
        appliedBy   = $tenant.addedBy
        appliedAt   = $tenant.appliedAt
        standards   = $tenant.Standards
    }
}
if (!$CurrentStandards) {
    $CurrentStandards = [PSCustomObject]@{
        displayName = 'No Standards applied'
        appliedBy   = $null
        appliedAt   = $null
        standards   = @{none = $null }
    }
}



# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @($CurrentStandards)
    })
