FUNCTION Get-PipeByPart {
    <#
        .SYNOPSIS
        The intention of this script is merely to show the breakdown of a piped command as PowerShell processes it.
        
        .DESCRIPTION
        A piped command can be passed to the function, as a string, parsed into separate commands, and each segment then
        showing its results before being passed on to the next command.
        
        .EXAMPLE
        Get-PipeByPart -PipedCommand "Get-WMIObject Win32_BIOS -ComputerName 127.0.0.1, 192.168.2.60 -Property SMBIOSBIOSVersion, Manufacturer, Version  | SELECT-ObjectSMBIOSBIOSVersion, Manufacturer | SORT SMBIOSBIOSVersion -Descending"
        
        The above command will first gather BIOS info from two computers.  Next, it will SELECT-Objectonly 2 attributes or properties, the SN and Manufacturer.
        Finally, it will sort the results by SN.

        Notice, the piped commands need to be within overall quotes in order to be passed to Get-PipeByPart as a single parameter.
        
        .EXAMPLE
        Get-PipeByPart -PipedCommand "Get-Disk -Number '1' | FL"

        If you need to use quotes within the piped commands you're passing, you can use single quotes to include them inside your overall quotes.
        
        .EXAMPLE
        Get-PipeByPart -PipedCommand "Get-Disk -Number `"1`" | FL"

        If you need to use quotes within the piped commands you're passing, you can use tickmark double quotes (`") to include them inside your overall quotes.

        .EXAMPLE
        $myResult = Get-PipeByPart -PipedCommand "Get-Disk -Number `"1`" | FL" -returnResults

        Finally, if you need to save the individual results of the piping process, you can have them returned as show above, using the -returnResults switch.

        .NOTES
        Mark Smith
        everydayPowerShell.com
        Twitter: @edPowerShell
    #>

    #region Param + Checks
        [cmdletbinding(SupportsShouldProcess=$True)]
        param(
            [string]$PipedCommand,
            [switch]$returnResults
        )
        $failure=$currentState=$null
        IF(!($PipedCommand)){
            $failure = "No piped command was provided.  Please use `"Get-Help Get-PipeByPart -Examples`" for examples of how to use this function."
            Write-Error $failure
            return
        }
        ELSEIF($PipedCommand -notlike "*`|*"){
            $failure = "You've included no actual piped (`"`|`") commands.  Please use `"Get-Help Get-PipeByPart -Examples`" for examples of how to use this function."
            Write-Error $failure
            return
        }
    #endregion

    #region Parse And Prep
        [Array]$PipedCommand = ($PipedCommand).Split("|")
        $PipedCommand = $PipedCommand.Trim()
        $commandCount = $PipedCommand.Count
        $pipedCommandResults = @()
        Clear-Host
        Start-Sleep -Seconds 1
        $nowCount = 0
    #endregion

    #region Present Commands
        ForEach($currentCommand in $PipedCommand){
            $nowCount++
            $newRow = "" | SELECT-Object Command,Result
            $newRow.Command = [string]$currentCommand
            $newRow.Result = $null
            IF($nowCount -eq 1){
                $currentState = [PSObject](Invoke-Command -ScriptBlock ([scriptblock]::Create($currentCommand)))
                $newRow.Result = $currentState
            }
            ELSEIF($nowCount -eq $commandCount){
                $currentState = $currentState | Invoke-Command -ScriptBlock ([scriptblock]::Create($currentCommand))
                $newRow.Result = $currentState
            }
            ELSE{
                $currentState = $currentState | Invoke-Command -ScriptBlock ([scriptblock]::Create($currentCommand))
                $newRow.Result = $currentState
            }
            $pipedCommandResults += $newRow
        }
    #endregion
    IF($returnResults){
        return $pipedCommandResults
    }
    ELSE{
        $PipedCommandResults | ForEach-Object {
            Write-Verbose $_.Command -Verbose
            Write-Output $_.Result
        }
    }
}
