FUNCTION Set-RemoteDNS {
    <#
        .SYNOPSIS
        Update remote system static DNS settings for the chosen system.

        .DESCRIPTION
        The script will reach out and confirm that you're talking to the correct system.
        If confirmed, the script will reach out and update the DNS Server Search Order.
        The script will then reach out and confirm the change has been correctly made.
        Finally, the script will run, essentially, an ipconfig /registerdns command, PowerShell style.

        .EXAMPLE
        $newDNS = "192.168.1.1","192.168.1.2","8.8.8.8"
        Set-RemoteDNS -cNameIP Win10 -newDNSIPList $newDNS

        Notice how the DNS server list is declared into a variable using quotes and commas.
        Below are results reported to console as task proceeds:
        
        cNameIP    : Win10
        realIP     : 192.168.1.12
        realName   : WIN10
        activeUser : 

        If the above information is correct, please hit Y or y and Enter to continue.  Otherwise, please just hit Enter and the script will stop: Y
        VERBOSE: Win10: This machine's DNS records will be updated on the DNS server.
        This may affect the results of DNS queries for this machine.

        cNameIP         : Win10
        realIP          : 192.168.1.12
        realName        : WIN10
        activeUser      : 
        originalDNS     : {192.168.1.1, 192.168.2.1}
        confirmedNewDNS : {192.168.1.1, 192.168.2.1, 8.8.8.8}

        .EXAMPLE
        $newDNS = "192.168.1.1","192.168.1.2","8.8.8.8"
        Set-RemoteDNS -cNameIP Win10 -newDNSIPList $newDNS -tCred PSAdmin

        The exact same results as Example 1 occur when including -tCred for specified credentials.
        The experience changes only in that you're asked for a password to match the username.

        .EXAMPLE
        $newDNS = "192.168.1.1","192.168.1.2","8.8.8.8"
        Set-RemoteDNS -cNameIP Win10 -newDNSIPList $newDNS -tCred edps\PSAdmin

        The exact same results as Example 1 occur when including -tCred for specified domain credentials.
        The experience changes only in that you're asked for a password to match the username.

        .EXAMPLE
        $newDNS = "192.168.1.1","192.168.1.2","8.8.8.8"
        Set-RemoteDNS -cNameIP 192.168.2.60 -newDNSIPList $newDNS

        As the name indicates, IP addresses work fine for the cNameIP parameter as well.

        .EXAMPLE
        $newDNS = "192.168.1.1","192.168.1.2","8.8.8.8"
        Set-RemoteDNS -cNameIP Win10.edps.com -newDNSIPList $newDNS

        FQDN can also be used where needed.  This will not negatively impact the script.

        .LINK
        http://blog.everydaypowershell.com/2019/01/how-do-i-resolve-this.html

        .NOTES
        Mark Smith
        everydayPowerShell.com
        Twitter: @edPowerShell
        Blog For This Function: http://blog.everydaypowershell.com/2019/01/how-do-i-resolve-this.html
        PSGallery Module: edps_012019_learningModules.psm1
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        $cNameIP,
        $newDNSIPList,
        [PSCredential]$tCred
    )
    #region Param Check
        $errMsg = $null
        IF(!$cNameIP){
            $errMsg = -Join(
                "`n `nIt seems you did not include a computer to target. ",
                "If this was intentional, as you intend to use this ",
                "function on your local computer, you can use `" -cNameIP ",
                "127.0.0.1`" to target your local system.`n `n",
                "For more help on how to use this function, please run ",
                "`"Get-Help Set-RemoteDNS -Examples`" or `"Get-Help ",
                "Set-RemoteDNS -Full`".`n `nThank you.  This function will now ",
                " end.`n `n"
            )
            Write-Error -Message $errMsg -ErrorAction Stop
        }
        IF(!$newDNSIPList){
            $errMsg = -Join(
                "`n `nIt seems you forgot to include your list of new DNS servers ",
                "to point to.  Please make sure to include -newDNSIPList when ",
                "running this function.`n `n",
                "For more help on how to use this function, please run ",
                "`"Get-Help Set-RemoteDNS -Examples`" or `"Get-Help ",
                "Set-RemoteDNS -Full`".`n `nThank you.  This function will now ",
                " end.`n `n"
            )
            Write-Error -Message $errMsg -ErrorAction Stop
        }
    #endregion
    #region Correct System Check
        $currentInfo = "" | SELECT-Object cNameIP,realIP,realName,activeUser
        $currentInfo.cNameIP = $cNameIP
        TRY{
            IF($tCred){
                $myCimSession = (New-CimSession -ComputerName $cNameIP -Credential $tCred -Authentication Negotiate -WarningAction Stop -ErrorAction Stop)
            }
            ELSE{
                $myCimSession = (New-CimSession -ComputerName $cNameIP -WarningAction Stop -ErrorAction Stop)
            }
        }
        CATCH{
            $errMsg = "" | SELECT-Object Message, ErrMsg, ErrName
            $errMsg.Message = -Join(
                "An error occurred while trying to establish a connection with $cNameIP. ",
                "Below is the information available on the matter."
            )
            $errMsg.ErrMsg = $_.Exception.Message
            $errMsg.ErrName = $_.Exception.GetType().FullName
            return ($errMsg | Format-List)
        }
        TRY{
            $cimCS = Get-CimInstance -CimSession $myCimSession -ClassName CIM_ComputerSystem | SELECT-Object Name, UserName
        }
        CATCH{
            $errMsg = "" | SELECT-Object Message, ErrMsg, ErrName
            $errMsg.Message = -Join(
                "An error occurred while trying to confirm the name and user of $cNameIP. ",
                "Below is the information available on the matter."
            )
            $errMsg.ErrMsg = $_.Exception.Message
            $errMsg.ErrName = $_.Exception.GetType().FullName
            return ($errMsg | Format-List)
        }
        TRY{
            $currentInfo.realName = $cimCS.Name
            $currentInfo.activeUser = $cimCS.UserName
        }
        CATCH{
            $errMsg = "" | SELECT-Object Message, ErrMsg, ErrName
            $errMsg.Message = -Join(
                "An error occurred while trying to process the name and user of $cNameIP. ",
                "Below is the information available on the matter."
            )
            $errMsg.ErrMsg = $_.Exception.Message
            $errMsg.ErrName = $_.Exception.GetType().FullName
            return ($errMsg | Format-List)
        }
        TRY{
            $currentInfo.realIP = Get-CimInstance -CimSession $myCimSession -ClassName Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled} | SELECT-Object -ExpandProperty IPAddress
        }
        CATCH{
            $errMsg = "" | SELECT-Object Message, ErrMsg, ErrName
            $errMsg.Message = -Join(
                "An error occurred while trying to confirm the IP of $cNameIP. ",
                "Below is the information available on the matter."
            )
            $errMsg.ErrMsg = $_.Exception.Message
            $errMsg.ErrName = $_.Exception.GetType().FullName
            return ($errMsg | Format-List)
        }
    #endregion
    #region Verify Correct System
        Write-Output $currentInfo | Format-List
        $doContinue = $null
        $doContinue = Read-Host -Prompt "If the above information is correct, please hit Y or y and Enter to continue.  Otherwise, please just hit Enter and the script will stop"
        IF($doContinue -ne "Y"){
            Write-Verbose -Message "You have chosen to quit the script.  I hope you have a great day!" -Verbose
            return
        }
    #endregion
    #region Get Adapter
        $currentInfo = $currentInfo | SELECT-Object *,originalDNS,confirmedNewDNS
        TRY{
            $incorrectAdapter = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter 'IPEnabled="True"' -CimSession $myCimSession | WHERE-Object {$_.IPAddress -eq $currentInfo.realIP}
            $currentInfo.OriginalDNS = $incorrectAdapter.DNSServerSearchOrder
        }
        CATCH{
            $errMsg = "" | SELECT-Object Message, ErrMsg, ErrName
            $errMsg.Message = -Join(
                "An error occurred while trying to retrieve the DNS information. ",
                "Below is the information available on the matter."
            )
            $errMsg.ErrMsg = $_.Exception.Message
            $errMsg.ErrName = $_.Exception.GetType().FullName
            return ($errMsg | Format-List)
        }
    #endregion
    #region Fix Chosen Adapter
        TRY{
            Set-DnsClientServerAddress -CimSession $myCimSession -InterfaceIndex ($incorrectAdapter.InterfaceIndex) -ServerAddresses $newDNSIPList
        }
        CATCH{
            $errMsg = "" | SELECT-Object Message, ErrMsg, ErrName
            $errMsg.Message = -Join(
                "An error occurred while trying to set the new DNS information. ",
                "Below is the information available on the matter."
            )
            $errMsg.ErrMsg = $_.Exception.Message
            $errMsg.ErrName = $_.Exception.GetType().FullName
            return ($errMsg | Format-List)
        }
    #endregion
    #region Update Actions Taken
        TRY{
            $newAdapterInfo = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter 'IPEnabled="True"' -CimSession $myCimSession | WHERE-Object {$_.InterfaceIndex -eq $incorrectAdapter.InterfaceIndex}
            $currentInfo.confirmedNewDNS = $newAdapterInfo.DNSServerSearchOrder
        }
        CATCH{
            $errMsg = "" | SELECT-Object Message, ErrMsg, ErrName
            $errMsg.Message = -Join(
                "An error occurred while trying to verify the new DNS information. ",
                "Below is the information available on the matter."
            )
            $errMsg.ErrMsg = $_.Exception.Message
            $errMsg.ErrName = $_.Exception.GetType().FullName
            return ($errMsg | Format-List)
        }
    #endregion
    #region Register DNS
        TRY{
            Register-DnsClient -CimSession $myCimSession -Verbose
        }
        CATCH{
            $errMsg = "" | SELECT-Object Message, ErrMsg, ErrName
            $errMsg.Message = -Join(
                "An error occurred while trying to register DNS for $cNameIP. ",
                "Below is the information available on the matter."
            )
            $errMsg.ErrMsg = $_.Exception.Message
            $errMsg.ErrName = $_.Exception.GetType().FullName
            return ($errMsg | Format-List)
        }
    #endregion
    return $currentInfo
}
Export-ModuleMember -Function Set-RemoteDNS