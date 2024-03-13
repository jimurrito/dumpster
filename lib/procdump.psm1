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
