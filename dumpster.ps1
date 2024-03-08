# BULK PROCDUMP
# 
# Writen by jamesimmer@microsoft.com
#
# Input Parameters
param (
    # Target status for a service
    [string]$TargetStatus = "StopPending",
    # Skip downloading procdump
    [switch]$SkipDownload,
    # Output path for dump + Transcript log
    [string]$OutputDir = $PWD.Path,
    # enable transcript logging
    [switch]$EnableLogging,
    # Skip killing processes once the dump is taken.
    [switch]$SkipProcKill

)

# Enable logging if requested
if ($EnableLogging) {
    Start-Transcript -Path ("{0}\bulk_procdump_{1}.log" -f $OutputDir, (Get-Date -Format "yyyyMMdd_HHmmss"))
}

#
# Check if status provided is valid:
# TO BE ADDED
#

#
# Check if procdump is in local dir/accessible
# TO BE ADDED
#

# If SkipDownload is false (default), download procdump, extact, and move to dir.
if (!$SkipDownload) {
    
    Write-Host ("Downloading Procdump to system directory: {0}" -f $OutputDir)

    try {
        invoke-webrequest http://download.sysinternals.com/files/Procdump.zip -Outfile Procdump.zip -ErrorAction Stop
        expand-archive Procdump.zip -ErrorAction Stop -Force
        cd Procdump
    }
    catch {
        Write-Host ("An error occurred while downloading Procdump: {0}" -f $_)
        break
    }
    finally {
        Write-Host ("Download and extraction of Procdump was successful.")
    }

}

# Get all services with the requested status (STOP_PENDING by default)
$srvcs_name = (Get-Service | Where-Object { $_.Status -eq $TargetStatus }).ServiceName

# Catch for no services matching the provided tag + verbose output
if ($srvcs_name.count -eq 0) {
    Write-Host ("No {0} services found. No Procdump(s) will be taken. Exiting Script..." -f $TargetStatus)
    break
}
else {
    Write-Host ("[{0}] Services are in {1} state." -f $srvcs_name.count, $TargetStatus)
}


# Take bulk procdump
foreach ($srvc_name in $srvcs_name) {
    $srvc_pid = Get-CimInstance -Class Win32_Service -Filter "Name LIKE '$srvc_name'" |
    Select-Object -ExpandProperty ProcessId

    $srvc_path = (Get-Process -Id $srvc_pid).Path
    $srvc_path = Split-Path -Path $srvc_path -Leaf


    # if PID = 0, then the process is stopped -> skip to next foreach iter.
    if ($srvc_pid -eq 0 ) { continue }

    
    # Try and take the dump
    try {
        write-host ("Taking Procdump for [{0}:{1}]." -f $srvc_name , $srvc_pid)
        .\procdump.exe -s 5 -n 3 -ma $srvc_pid -accepteula ("{0}-{1}_{2}.dmp" -f "$srvc_name", "$srvc_path", (Get-Date -Format "yyyyMMdd_HHmmss"))
    }
    catch {
        Write-Host ("Running procdump for [{0}:{1}] failed with the following reason: {2}" -f $srvc_name , $srvc_pid, $_)
    }

}

# Bulk proc kill.
if (!$SkipProcKill) {
    foreach ($srvc_name in $srvcs_name) {
        try {
            write-host ("Killing process [{0}:{1}]." -f $srvc_name , $srvc_pid)
            taskkill /PID $srvc_pid /t /f
        }
        catch {
            Write-Host ("Killing process [{0}:{1}] failed for the following reason: {2}." -f $srvc_name , $srvc_pid, $_)
        }
    }
}

write-host "Script Done."

# Disable logging
if ($EnableLogging) {
    Stop-Transcript
}