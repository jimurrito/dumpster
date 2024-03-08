# Functions for running bulk procdumps

$ValidStateList = ("Stopped", "StartPending", "StopPending", "Running", "ContinuePending", "PausePending", "Paused")

function Get-ProcDump {
    <#
    .Description
    Downloads, extracts, and navigates to the dir for procdump
    #>

    Write-Host ("Downloading Procdump to system directory: {0}" -f $OutputDir)
    
    try {
        invoke-webrequest http://download.sysinternals.com/files/Procdump.zip -Outfile Procdump.zip -ErrorAction Stop
        expand-archive Procdump.zip -ErrorAction Stop -Force
    }
    catch {
        throw ("An error occurred while downloading Procdump: {0}" -f $_)
    }
    finally {
        Write-Host ("Download and extraction of Procdump was successful.")
    }
    
}

function Find-Procdump {
    <#
    .Description
    Checks if procdump is in the current location
    Returns bool
    #>
    param (
        [String]$Path = $1
    )
    (Get-ChildItem -Path $Path -Filter procdump.exe -erroraction 'silentlycontinue').count -gt 0

}

function Confirm-TargetProcState {
    <#
    .Description
    Checks if target state for services is a valid state
    Returns bool
    #>
    param (
        [String]$State = $1
    )
    $ValidStateList -contains $State
}

function Get-TargetProcState {
    "Valid service states for Procdump.`n`n$ValidStateList"
}

function Start-ProcDump {
    <#
    .Description
    Takes a single procdump of a named service
    #>
    param (
        [string]$ServiceName,    
        [string]$TargetStatus = "StopPending"
    )

    # Resolve PID from name
    $srvc_pid = Get-CimInstance -Class Win32_Service -Filter "Name LIKE '$srvc_name'" | Select-Object -ExpandProperty ProcessId
    # Resolve the executable that is linked to the PID
    $srvc_path = (Get-Process -Id $srvc_pid).Path | Split-Path -Leaf
    
    # Try and take the dump
    try {
        write-host ("Taking Procdump for [{0}:{1}]." -f $srvc_name , $srvc_pid)
        .\procdump.exe -s 5 -n 3 -ma $srvc_pid -accepteula ("{0}-{1}_{2}.dmp" -f "$srvc_name", "$srvc_path", (Get-Date -Format "yyyyMMdd_HHmmss"))
    }
    catch {
        throw ("Running procdump for [{0}:{1}] failed with the following reason: {2}" -f $srvc_name , $srvc_pid, $_)
    }
    finally{
        Write-Host "Procdump for [{0}:{1}] done."
    }
}