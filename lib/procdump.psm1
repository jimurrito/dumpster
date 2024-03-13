# Functions for running bulk procdumps

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



function Start-ProcDump {
    <#
    .Description
    Takes a single procdump of a named service
    #>
    param (
        [string]$ServiceName,
        [string]$ServicePID,
        [string]$ServiceExec,
        [string]$TargetStatus = "StopPending",
        [string]$OutputDir
    )

    # Try and take the dump
    try {
        write-host ("Taking Procdump for [{0}:{1}]." -f $ServiceName , $ServicePID)
        .\procdump.exe -s 5 -n 3 -ma $ServicePID -accepteula ("$OutputDir/{0}-{1}_{2}.dmp" -f "$ServiceName", "$ServiceExec", (Get-Date -Format "yyyyMMdd_HHmmss"))
    }
    catch {
        throw ("Running procdump for [{0}:{1}] failed with the following reason: {2}" -f $ServiceName , $ServicePID, $_)
    }
    finally {
        Write-Host ("Procdump for [{0}:{1}] done." -f $ServiceName , $ServicePID)
    }
}