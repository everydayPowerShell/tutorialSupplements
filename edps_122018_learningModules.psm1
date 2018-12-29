FUNCTION Get-PipeByPart {
    <#
        .SYNOPSIS
        The intention of this script is merely to show the breakdown of a piped command as PowerShell processes it.
        
        .DESCRIPTION
        A piped command can be passed to the function, as a string, parsed into separate commands, and each segment then
        showing its results before being passed on to the next command.
        
        .EXAMPLE
        Get-PipeByPart -PipedCommand "Get-WMIObject Win32_BIOS -ComputerName 127.0.0.1, 192.168.2.60 -Property SMBIOSBIOSVersion, Manufacturer, Version  | SELECT-Object SMBIOSBIOSVersion, Manufacturer | SORT SMBIOSBIOSVersion -Descending"
        
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

        .PARAMETER PipedCommand
        PipedCommand is looking for the... piped command... you're looking to examine.  Use the examples to see how to deal with quotes you want to include in your commands as outer-double-quotes will need to wrap this parameter.

        .PARAMETER returnResults
        returnResults will, instead of presenting the breakdown on the screen, return an array with columns for each command ($myResult.Command) and then the result ($myResult.Result).

        .LINK
        http://blog.everydaypowershell.com/2018/11/get-pipedparts-understanding-order-of.html

        .NOTES
        Mark Smith
        everydayPowerShell.com
        Twitter: @edPowerShell
        Blog For This Function: http://blog.everydaypowershell.com/2018/11/get-pipedparts-understanding-order-of.html
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
Export-ModuleMember -Function Get-PipeByPart
FUNCTION Confirm-TargetSystem {
    <#
        .SYNOPSIS
        Attempt to verify that a system is the intended target system and, optionally, is intended logged on user.

        .DESCRIPTION
        Attempt to verify that a system is the intended target system and, optionally, is intended logged on user.  Will use Get-WMIObject to reach out to target system and attempt to match the computer name or IP address and, if provided, the username as well.

        .EXAMPLE
        Confirm-TargetSystem -sysID PSCenter

        Expected results of a confirmed system:

        sysID            : PSCenter
        sysName          : PSCENTER
        sysIP            : 192.168.2.60
        usrID            : NA
        usrLoggedOn      : NA
        isIntendedSystem : True
        isIntendedUser   : False
        failureNotes     : NA

        .EXAMPLE
        Confirm-TargetSystem -sysID PSCenters

        Expected results of a failed confirmation where the system could not be viably reached.

        sysID            : PSCenters
        sysName          : 
        sysIP            : 
        usrID            : NA
        usrLoggedOn      : NA
        isIntendedSystem : 
        isIntendedUser   : 
        failureNotes     : The system is unavailable to communicate with the system PSCenters.
                           Error:
                           The RPC server is unavailable. (Exception from HRESULT: 0x800706BA)

        .EXAMPLE
        Confirm-TargetSystem -sysID PSCenter -usrID PSAdmin

        If all results confirmed, feedback would appear as:

        sysID            : PSCenter
        sysName          : PSCENTER
        sysIP            : 192.168.2.60
        usrID            : PSAdmin
        usrLoggedOn      : PSCENTER\PSAdmin
        isIntendedSystem : True
        isIntendedUser   : True
        failureNotes     : NA

        .EXAMPLE
        Confirm-TargetSystem -sysID 192.168.1.21 -tCred BettyBoop

        Expected results if your credentials are invalid on the remote system.

        sysID            : 192.168.1.21
        sysName          : 
        sysIP            : 
        usrID            : NA
        usrLoggedOn      : NA
        isIntendedSystem : 
        isIntendedUser   : 
        failureNotes     : You do not have access to this system with your current credentials.  Perhaps try other credentials using the -tCred option if you haven't already?
                           Error:
                           Access is denied. (Exception from HRESULT: 0x80070005 (E_ACCESSDENIED))

        .EXAMPLE
        IF(Confirm-TargetSystem -sysID PSCenter -usrID PSAdmin | SELECT -ExpandProperty isIntendedSystem){Write-Host "Hello"}

        To use in another script to confirm whether or not to proceed with an intended action/configuration, above will return true and act if confirmation of the system is clear.

        .PARAMETER sysID
        sysID is looking for either a computer name or IP address.  Whatever normal way you communicate with computers in your environment and can ping systems, that can be plugged in here.

        .PARAMETER usrID
        usrID is looking to match the user's login ID.  For example, if I login with PSCenter\PSAdmin, using -usrID PSAdmin will count as a match if PSCenter\PSAdmin is what's returned when checking the remote system.  

        .PARAMETER tCred
        tCred is aiming to collect alternate creds if you need to connect with the remote system with another account.  If I'm in my computer as MSmith but need to reach out with my tech cred PSAdmin, I would include -tCred PSAdmin.  When I do, I'll be prompted for my current password and then PSAdmin will be the account to reach out to the remote system.

        .LINK
        http://blog.everydaypowershell.com/2018/12/is-that-really-my-target-system.html

        .NOTES
        Mark Smith
        everydayPowerShell.com
        Twitter: @edPowerShell
        Blog For This Function: http://blog.everydaypowershell.com/2018/12/is-that-really-my-target-system.html
    #>
    [cmdletbinding()]
    param (
        $sysID,
        $usrID,
        [PSCredential]$tCred
    )
    Clear-Host
    Start-Sleep -Seconds 1
    #region Param Check & Variable Prep
        IF(!($sysID)){
            $closingMsg = "You have not entered identifying information for a system that needs to be confirmed.  Confirm-TargetSystem cannot run without this information.  "
            $closingMsg += "Please use `"Get-Help Confirm-TargetSystem -Examples`" for examples of how to use this function.  "
            $closingMsg += "Thank you.  Confirm-TargetSystem will now stop."
            Write-Error -Message $closingMsg -ErrorAction Stop
        }
        IF(!($usrID)){
            $warningMsg = "You have not entered identifying information for a user on the target system.  Confirm-TargetSystem will only attempt to verify the system, not the user at this time."
            Write-Warning -Message $warningMsg -WarningAction Continue
        }
        IF(!($tCred)){
            $infoMsg = "You have not entered specific creds to be used with this function.  PowerShell will use $($env:USERDOMAIN)\$($env:USERNAME) as the authority to reach out to the remote system."
            Write-Information -MessageData $infoMsg -InformationAction Continue
        }
        ELSE{
            $infoMsg = "You have chosen to use alternative creds for Confirm-TargetSystem.  PowerShell will use $($tCred.UserName) as the authority to reach out to the remote system."
            Write-Verbose -Message $infoMsg -Verbose
        }
        $result = "" | Select-Object sysID, sysName, sysIP, usrID, usrLoggedOn, isIntendedSystem, isIntendedUser, failureNotes
        $result.sysID = $sysID
        IF($usrID){
            $result.usrID = $usrID
        }
        ELSE{
            $result.usrID = "NA"
            $result.usrLoggedon = "NA"
        }
    #endregion
    #region Verify System
        Write-Verbose -Message "Attempting To Verify System $sysID now." -Verbose
        TRY{
            IF($tCred){
                Write-Verbose "Attempting verification using $($tCred.UserName)."
                $result.sysName = Get-CimInstance -ClassName CIM_ComputerSystem -CimSession (New-CimSession -Credential $tCred -ComputerName $sysID -SkipTestConnection) -ErrorAction Stop -WarningAction Stop | Select-Object -ExpandProperty Name
                #$result.sysName = Get-WmiObject -Class Win32_ComputerSystem -Credential $tCred -ComputerName $sysID -ErrorAction Stop -WarningAction Stop | Select-Object -ExpandProperty Name
            }
            ELSE{
                Write-Verbose "Attempting verification with $($env:USERDOMAIN)\$($env:USERNAME)."
                $result.sysName = Get-CimInstance -ClassName CIM_ComputerSystem -ComputerName $sysID -ErrorAction Stop -WarningAction Stop | Select-Object -ExpandProperty Name
            }
            $result.sysIP = (Test-Connection $sysID -Count 1 -ErrorAction Stop -WarningAction Stop | Select-Object -ExpandProperty IPV4Address).IPAddressToString
        }
        CATCH [Microsoft.Management.Infrastructure.CimException] {
            IF(($_.Exception.Message) -like "*WinRM cannot complete the operation*"){
                $result.failureNotes = "The system is unavailable to communicate with the system $sysID.`nError:`n$($_.Exception.Message)"
                return $result
            }
            ELSEIF(($_.Exception.Message) -like "*Access is denied*"){
                $closingMsg = "You do not have access to this system with your current credentials.  "
                $closingMsg += "Perhaps try other credentials using the -tCred option if you haven't already?`n"
                $closingMsg += "Error:`n$($_.Exception.Message)"
                $result.failureNotes = $closingMsg
                return $result
            }
            ELSE{
                [string]$closingMsg = "$($_.Exception.GetType().FullName)`n"
                $closingMsg += "$($_.Exception.Message)"
                $result.failureNotes = $closingMsg
                return $result
            }
        }
        CATCH{
            [string]$closingMsg = "$($_.Exception.GetType().FullName)`n"
            $closingMsg += "$($_.Exception.Message)"
            $result.failureNotes = $closingMsg
            return $result
        }
    #endregion
    #region Verify User
        IF($usrID){
            Write-Verbose -Message "Attempting To Verify User $usrID Is On $sysID now." -Verbose
            TRY{
                IF($tCred){
                    Write-Verbose "Attempting verification using $($tCred.UserName)."
                    $result.usrLoggedOn = Get-CimInstance -ClassName CIM_ComputerSystem -CimSession (New-CimSession -Credential $tCred -ComputerName $sysID -SkipTestConnection) -ErrorAction Stop -WarningAction Stop | Select-Object -ExpandProperty UserName
                }
                ELSE{
                    Write-Verbose "Attempting verification with $($env:USERDOMAIN)\$($env:USERNAME)."
                    $result.usrLoggedOn = Get-CimInstance -ClassName CIM_ComputerSystem -ErrorAction Stop -WarningAction Stop | Select-Object -ExpandProperty UserName
                }
            }
            CATCH{
                [string]$closingMsg = "$($_.Exception.GetType().FullName)`n"
                $closingMsg += "$($_.Exception.Message)"
                $result.failureNotes = $closingMsg
                return $result
            }
        }
    #endregion
    #region Closure
        IF($sysID -eq ($result.sysName)){
            $result.isIntendedSystem = "True"
        }
        ELSEIF($sysID -eq ($result.sysIP)){
            $result.isIntendedSystem = "Unverified"
        }
        ELSEIF($sysID -ne ($result.sysName) -and $sysID -ne ($result.sysIP)){
            $result.isIntendedSystem = "False"
        }
        IF($usrID -eq ($result.usrLoggedon) -or ($result.usrLoggedOn) -like "*\$usrID"){
            $result.isIntendedUser = "True"
        }
        ELSE{
            $result.isIntendedUser = "False"
        }
        $result.failureNotes = "NA"
        return $result
    #endregion
}
Export-ModuleMember -Function Confirm-TargetSystem
