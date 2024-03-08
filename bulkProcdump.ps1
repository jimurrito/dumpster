<#
.Description
Takes bulk Procdump(s) of services in a given state.
#>

param (
    # Target status for a service
    [string]$TargetStatus = "StopPending",
    # enable transcript logging
    [switch]$EnableLogging,
    # Output path for dump
    [string]$OutputDir = $PWD.Path,
    # Skip killing processes once the dump is taken.
    [switch]$SkipProcKill
)

# Import lib
Import-Module -name "$PSScriptRoot\lib\procdump.psm1"

# Enable logging if requested
if ($EnableLogging) {
    Start-Transcript -Path ("{0}\bulkProcdump_{1}.log" -f $OutputDir, (Get-Date -Format "yyyyMMdd_HHmmss"))
}

# Check input state is valid
if (!(Confirm-TargetProcState $TargetStatus)) {
    $List = $(Get-TargetProcState)
    # state is not valid
    throw "[$TargetStatus] is not a valid state.`n$List" 
}

# Check if procdump is already downloaded
$LocalDir = Find-Procdump
$ChildDir = Find-Procdump .\Procdump\
#
# Its these moments I wish powershell was functional λ
#
# if not, download + nav to dir
if (!($LocalDir -or $ChildDir)) {
    # No procdump found - get it
    Get-ProcDump
    Set-Location  .\Procdump\
}
elseif (!$LocalDir -and $ChildDir) {
    Write-Host "Procdump.exe already downloaded. Found at $PWD\Procdump"
    # Procdump found in child dir
    Set-Location  .\Procdump\
}
else {
    # Any other scenario has procdump.exe in the current dir
    Write-Host "Procdump.exe already downloaded. Found at $PWD"
}

# Get all services with the requested status
$Services = (Get-Service | Where-Object { $_.Status -eq $TargetStatus }).ServiceName
#
# Catch for no services matching the provided tag + verbose output
if ($Services.count -eq 0) {
    Write-Host ("No {0} services found. No Procdump(s) will be taken. Exiting Script..." -f $TargetStatus)
    break
}
else {
    Write-Host ("[{0}] Services are in {1} state." -f $Services.count, $TargetStatus)
}

# Take procdump(s)
foreach ($Service in $Services) {
    Start-ProcDump -ServiceName $Services -TargetStatus $TargetStatus
}

# revert back a dir when done - if not local .exe
if (!$LocalDir) {
    Set-Location ..
}


