# Some of this code is for Datto RMM, such code is documented below
# The functions are all Datto-specific

$EXIT_SUCCESS = 0
$EXIT_FAILURE = 1

#Generic function to gracefully exit dRMM PowerShell script
#@param exitcode: mandatory, code to exit with; 0=success, 1=failure
#@param results: string or integer to pass back to dRMM for results of script
#@param diagnostics: additional information to pass back to dRMM for results of script
function Exit-dRMMScript {
    [cmdletbinding()]
    Param([Parameter(Mandatory=$true)]$exitcode, $results, $diagnostics)

    #Output results
    Write-Output "<-Start Result->"
    Write-Output "Result=$results"
    Write-Output "<-End Result->"

    #Output diagnostics, if they exist
    if (!($null -eq $diagnostics)) {
        Write-Output "<-Start Diagnostics->"
        Write-Output "Result=$diagnostics"
        Write-Output "<-End Result->"
    }

    exit $exitcode

} #End function

#Generic function to set dRMM UDF
#@param udf_number: mandatory, UDF number to set
#@param udf_value: mandatory, value to set UDF to
function Set-dRMM-UDF {
    Param([Parameter(Mandatory=$true)]$udf_number, $udf_value)
    REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v "Custom$udf_number" /t REG_SZ /d "$udf_value" /f
}

#Dump all the environmental variables to stdout, usually only for debugging
if ($env:drmm_dump_env_vars -eq "true") {
    Get-ChildItem variable:$env | ForEach-Object {
        Write-Output $_
    }
}

########################################
##### Begin custom script section ######
########################################

if ($env:test -eq $true) {
    $udf_to_set = 8
}

# First thing, set the UDF to un-mitigated, if all succeeds we will change this.
# If you are not using Datto RMM use your own RMM's process to set a custom device variable
Set-dRMM-UDF -udf_number $udf_to_set -udf_value "UN-Mitigated"

try {
    # Check to see what UDF number to set, exit with failure if none is found
    $udf_to_set = $env:UdfNumber
}
catch {
    # This is Datto RMM specific code to exit a script, if you are not using Datto RMM use your RMM's process
    # to exit with failure here, this repeats below.
    $exitcode = $EXIT_FAILURE
    Exit-dRMMScript -exitcode $exitcode -results "Failed to get UDF!"
}

if($udf_to_set -eq "") {
    # Check to see what UDF number to set, exit with failure if none is found
    $exitcode = $EXIT_FAILURE
    Exit-dRMMScript -exitcode $exitcode -results "Missing a valid UDF to set"
}

try {
    # Attemp to correct permissions
    write-output "Correcting permissions."
    icacls $env:windir\system32\config\*.* /inheritance:e
}
catch {
    $exitcode = $EXIT_FAILURE
    write-output "Unable to correct permissions."
    Exit-dRMMScript -exitcode $exitcode -results "Failure!" -diagnostics "Unable to correct permissions"    
}

# Make sure that a shadow copy exists for the system drive, otherwise we'll end up with a false failure below
$cShadows = & vssadmin list shadows /for=$env:systemdrive
if ($cShadows -match "No items found that satisfy the query") {
        
    Write-Output "No shadow copies found for the system drive, we're done."
        # Set the UDF to mitigated so we know not to target this device again.
        Set-dRMM-UDF -udf_number $udf_to_set -udf_value "Mitigated"

        $exitcode = $EXIT_SUCCESS
        # This is Datto RMM specific code to exit a script, if you are not using Datto RMM use your RMM's process
        # to exit with SUCCESS here, this repeats below.
        Exit-dRMMScript -exitcode $exitcode -results "Success!" -diagnostics "Vuln is mitigated"    
        
}
else {
    try {
        # Attempt to delete all shadow copies for system drive
        write-output "Deleting shadow copies for system drive"
        vssadmin delete shadows /for=$env:systemdrive /Quiet
    
        $exitcode = $EXIT_SUCCESS
    
        # Set the UDF to mitigated so we know not to target this device again.
        Set-dRMM-UDF -udf_number $udf_to_set -udf_value "Mitigated"
    
        # This is Datto RMM specific code to exit a script, if you are not using Datto RMM use your RMM's process
        # to exit with SUCCESS here, this repeats below.
        Exit-dRMMScript -exitcode $exitcode -results "Success!" -diagnostics "Vuln is mitigated"    
    }
    catch {
        write-output "Unable to delete system Shadow Copies."
        Exit-dRMMScript -exitcode $exitcode -results "Failure!" -diagnostics "Unable to delete system Shadow Copies."
    }
}


$exitcode = $EXIT_FAILURE
write-output "It should be impossible to get here. If so, then something probably went wrong."
Exit-dRMMScript -exitcode $exitcode -results "Failure!" -diagnostics "It should be impossible to get here. If so, then something probably went wrong."