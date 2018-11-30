New-Module edpsTutorials001 {
    FUNCTION Get-PipeParts {
        <#
            .SYNOPSIS

            The intention of this script is merely to show the breakdown of a piped command as PowerShell processes it.

            .DESCRIPTION

            A piped command can be passed to the function, as a string, parsed into separate commands, and each segment then
            showing its results before being passed on to the next command.

            .EXAMPLE
            Get-PipeParts -PipedCommand "Get-WMIObject Win32_BIOS -ComputerName 127.0.0.1, 192.168.2.60 -Property SMBIOSBIOSVersion, Manufacturer, Version  | SELECT SMBIOSBIOSVersion, Manufacturer | SORT SMBIOSBIOSVersion -Descending"

            The above command will first gather BIOS info from two computers.  Next, it will select only 2 attributes or properties, the SN and Manufacturer.
            Finally, it will sort the results by SN.

            Notice, the piped commands need to be within overall quotes in order to be passed to Get-PipeParts as a single parameter.

            .NOTES
            Mark Smith
            everydayPowerShell.com
            Twitter: @edPowerShell
            https://github.com/everydayPowerShell
            https://github.com/everydayPowerShell/tutorialSupplements
        #>

        #region Param + Checks
            param(
                [string]$PipedCommand
            )
            $failure=$currentState=$null
            IF(!($PipedCommand)){
                $failure = "No piped command was provided.  Please use `"Get-Help Get-PipeParts -Examples`" for an example of how to use this function."
                Write-Error $failure
                return
            }
            ELSEIF($PipedCommand -notlike "*`|*"){
                $failure = "You've included no actual piped (`"`|`") commands.  Please use `"Get-Help Get-PipeParts -Examples`" for an example of how to use this function."
                Write-Error $failure
                return
            }
        #endregion

        #region Parse And Prep
            [Array]$PipedCommand = ($PipedCommand).Split("|")
            $PipedCommand = $PipedCommand.Trim()
            $commandCount = $PipedCommand.Count
            $nowCount = 0
        #endregion

        #region Present Commands
            ForEach($currentCommand in $PipedCommand){
                $nowCount++
                IF($nowCount -eq 1){
                    Write-Host -ForegroundColor Green $currentCommand
                    $currentState = Invoke-Command -ScriptBlock ([scriptblock]::Create($currentCommand))
                    $currentState
                    Read-Host -Prompt "Press Enter To Continue"
                }
                ELSEIF($nowCount -eq $commandCount){
                    Write-Host -ForegroundColor Green $currentCommand
                    $currentState = $currentState | Invoke-Command -ScriptBlock ([scriptblock]::Create($currentCommand))
                    $currentState
                }
                ELSE{
                    Write-Host -ForegroundColor Green $currentCommand
                    $currentState = $currentState | Invoke-Command -ScriptBlock ([scriptblock]::Create($currentCommand))
                    $currentState
                    Read-Host -Prompt "Press Enter To Continue"
                }
            }
        #endregion
    }
}
