@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # Interactive console tool: coloured Write-Host output is the UI
        'PSAvoidUsingWriteHost'
        # Say-Ok / Say-Info / ... and the tests' Check are short UI helpers, not exported cmdlets
        'PSUseApprovedVerbs'
        # New-RestorePoint is only called after the user confirmed the install
        'PSUseShouldProcessForStateChangingFunctions'
        # Find-WUDrivers returns a list on purpose
        'PSUseSingularNouns'
    )
}
