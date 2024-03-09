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
        Write-Error ("An error occurred while downloading Procdump: {0}" -f $_)
        return $false
    }
    finally {
        Write-Host ("Download and extraction of Procdump was successful.")
        $true
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
    return $ValidStateList
}

function Get-ProcPID {
    param (
        $ProcName = $1
    )
    Get-CimInstance -Class Win32_Service -Filter "Name LIKE '$ProcName'" | Select-Object -ExpandProperty ProcessId
}

function Get-ProcExe {
    param (
        $ProcPid = $1
    )
    # Get proc info
    (Get-Process -Id $ProcPid).Name    
}


function Start-ProcDump {
    <#
    .Description
    Takes a single procdump of a named service
    #>
    param (
        [string]$ServiceName,
        [string]$ServicePID,
        [string]$ServiceExec,
        [string]$TargetStatus = "StopPending"
    )

    # Try and take the dump
    try {
        write-host ("Taking Procdump for [{0}:{1}]." -f $ServiceName , $ServicePID)
        .\procdump.exe -s 5 -n 3 -ma $ServicePID -accepteula ("{0}-{1}_{2}.dmp" -f "$ServiceName", "$ServiceExec", (Get-Date -Format "yyyyMMdd_HHmmss"))
    }
    catch {
        Write-Error ("Running procdump for [{0}:{1}] failed with the following reason: {2}" -f $ServiceName , $ServicePID, $_)
        return $false
    }
    finally {
        Write-Host ("Procdump for [{0}:{1}] done." -f $ServiceName , $ServicePID)
        $true
    }
}

function Stop-Procs {
    <#
    .Description
    Kill processes by PID
    #>
    param (
        $ServiceName,
        $ServicePID        
    )
    try {
        write-host ("Killing process [{0}:{1}]." -f $ServiceName , $ServicePID )
        taskkill /PID $ServicePID  /t /f
    }
    catch {
        Write-Host ("Killing process [{0}:{1}] failed for the following reason: {2}." -f $ServiceName , $ServicePID , $_)
    }
    
}

function Clear-House {
    <#
    .Description
    Properly off-boards the script in the event of an early return.
    #>
    param (
        $LocalDir=$1,
        $EnableLogging=$2       
    )
    # revert back a dir when done - if not local .exe
    if (!$LocalDir) {
        Set-Location ..
    }
    # Disable logging
    if ($EnableLogging) {
        Stop-Transcript
    }
    exit
}