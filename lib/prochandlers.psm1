function Get-TargetProcState {
    <#
    .Description
    Valid Process status(s).
    #>
    return ("Stopped", "StartPending", "StopPending", "Running", "ContinuePending", "PausePending", "Paused")
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
    Get-TargetProcState -contains $State
}



function Get-ProcPID {
    <#
    .Description
    Resolves a Process ID from a Service Name.
    #>
    param (
        $ProcName = $1
    )
    Get-CimInstance -Class Win32_Service -Filter "Name LIKE '$ProcName'" | Select-Object -ExpandProperty ProcessId
}


function Get-ProcExe {
    <#
    .Description
    Finds the executable that was used to run a given PID.
    #>
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
        throw ("Running procdump for [{0}:{1}] failed with the following reason: {2}" -f $ServiceName , $ServicePID, $_)
    }
    finally {
        Write-Host ("Procdump for [{0}:{1}] done." -f $ServiceName , $ServicePID)
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
        $LocalDir = $1,
        $EnableLogging = $2       
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