using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
# Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME -message "Accessed this API" -Sev "Debug"

$Table = get-cipptable 'cachebpav2'
$name = $Request.query.Report
if ($name -eq $null) { $name = "CIPP Best Practices v1.0 - Table view" }

# Get all possible JSON files for reports, find the correct one, select the Columns
$JSONFields = @()
(Get-ChildItem -Path "Config\*.BPATemplate.json" -Recurse | Select-Object -ExpandProperty FullName | ForEach-Object { 
    $Template = $(Get-Content $_) | ConvertFrom-Json
    if ($Template.Name -eq $NAME) {
        $JSONFields = $Template.Fields | Where-Object { $_.StoreAs -eq 'JSON' } | ForEach-Object { $_.name }
    }
})

$Data = (Get-AzDataTableEntity @Table -Filter "RowKey eq '$NAME'") | ForEach-Object {
    $row = $_
    $JSONFields | ForEach-Object {
        $jsonContent = $row.$_
        if ($jsonContent -ne $null -and $jsonContent -ne "FAILED") {
            $row.$_ = $jsonContent | ConvertFrom-Json -Depth 15
        }
    }
    $row
}

$Columns = $null
(Get-ChildItem -Path "Config\*.BPATemplate.json" -Recurse | Select-Object -ExpandProperty FullName | ForEach-Object { 
    $Template = $(Get-Content $_) | ConvertFrom-Json
    if ($Template.Name -eq $NAME) { 
        $Columns = $Template.fields.FrontendFields | Where-Object -Property name -NE $null
    }
})

$Results = [PSCustomObject]@{
    Data    = $Data
    Columns = $Columns
}

if (!$Results) {
    $Results = @{
        Columns = @( value = "Results"; name = "Results")
        Data    = @(@{ Results = "The BPA has not yet run." })
    }
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = ($Results | ConvertTo-Json -Depth 15)
    })
