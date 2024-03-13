<#
.Synopsis
Takes bulk Procdump(s) of services in a given state.

.Description
Based on the specified target process status, services will have memory dumps taken via Procdump.
Optionally, the services can be killed once the dumps are taken. This very likely can lead to OS instability, so use with caution.
Memory dumps generates will be placed in the current dirtory, unless specificied otherwise.

Made by: jamesimmer@microsoft.com

.Parameter TargetStatus
Desired status for target services.

Options:
- Stopped
- Running
- Paused
- StartPending
- StopPending
- ContinuePending
- PausePending

.Parameter EnableLogging
Runs a Powershell transcript while the script runs. Recomended for debugging only. (Disabled by default)

.Parameter OutputDir
Target directory for the memory dumps. (Defaults to Current path.)

.Parameter ProcKill
Kills the processes once **ALL** the per-process memory dumps are taken.

.Example
PS> bulkProcdump.ps1 -TargetStatus StopPending
Take procdump(s) on all services with the `StopPending` state.

.Example
PS> bulkProcdump.ps1 -TargetStatus StopPending -ProcKill
Take procdump(s) on all services with the `StopPending` state. When done, kill the processes.

.Example
PS> bulkProcdump.ps1 -TargetStatus StopPending -EnableLogging
Take procdump(s) on all services with the `StopPending` state. Runs Transcript of the script run.

.Link
https://github.com/jasmir/dumpster

#>

# ensure shell is elevated
#Requires -RunAsAdministrator

# Ensures assemby is loaded into .net
# prevents issues with the [System.ServiceProcess.ServiceControllerStatus] enum

param (
    # Target status for a service
    [String]$TargetStatus = $null,
    # enable transcript logging
    [switch]$EnableLogging,
    # Output path for dump
    [string]$OutputDir = $PWD.Path,
    # kills process(s) once the dump is taken.
    [switch]$ProcKill
)

# Import lib
Import-Module -name "$PSScriptRoot\lib\procdump.psm1"
Import-Module -name "$PSScriptRoot\lib\prochandlers.psm1"


# Enable logging if requested
if ($EnableLogging) {
    Start-Transcript -Path ("{0}\bulkProcdump_{1}.log" -f $OutputDir, (Get-Date -Format "yyyyMMdd_HHmmss"))
}


# Ensure $targetstatus is not $null
if (!($TargetStatus)) {
    Write-Error "The -TargetStatus parameter is required. Valid states: ($List)"
    Clear-House $true $EnableLogging
}


# Check input state is valid
if (!(Confirm-TargetProcState $TargetStatus)) {
    $List = $(Get-TargetProcState)
    # state is not valid
    Write-Error "[$TargetStatus] is not a valid state. Valid states: ($List)"
    Clear-House $true $EnableLogging
}


# Get all services with the requested status
$Services = (Get-Service | Where-Object { $_.Status -eq $TargetStatus }).ServiceName
#
# Catch for no services matching the provided tag + verbose output
if ($Services.count -eq 0) {
    Write-Warning ("No [{0}] services found. No Procdump(s) will be taken." -f $TargetStatus)
    # Off board script
    Clear-House $true $EnableLogging
}
else {
    Write-Host ("[{0}] Services are in {1} state." -f $Services.count, $TargetStatus)
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
    $result = Get-ProcDump
    if (!$result) {
        # Proc dump was not successful
        # Off board script
        Clear-House $true $EnableLogging
    }
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


# Get proc info
$ServiceLs = @()
Write-Host "Gathering Information on [${TargetStatus}] services."
foreach ($ServiceName in $Services) {
    $ServicePID = Get-ProcPID -ProcName $ServiceName
    $ServiceExec = Get-ProcExe -ProcPid $ServicePID
    $ServiceLs += [System.Tuple]::Create($ServiceName, $ServicePID, $ServiceExec)
}
# $ServiceLs is now a list of tuples. Item1 == Name, Item2 == PID, Item3 == executable


# Take procdump(s)
$ServiceLs | ForEach-Object {
    Start-ProcDump -ServiceName $_.item1 -ServicePID $_.item2 -ServiceExec $_.item3 -TargetStatus $TargetStatus
}


# Kill Processes if requested
if ($ProcKill) {
    $ServiceLs | ForEach-Object {
        Stop-Procs -ServiceName $_.item1 -ServicePID $_.item2
    } 
}


# Off board script
Clear-House $LocalDir $EnableLogging
