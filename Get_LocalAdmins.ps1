param (
    [parameter(ValuefromPipeline=$true, Mandatory=$false, HelpMessage="ComputerName")]
    [string] $ComputerName,
	[parameter(Mandatory=$false, HelpMessage="File with computernames")]
    [string] $File,
    [parameter(Mandatory=$false, HelpMessage="Group name to get members of it")]
    [string] $GroupName = "Administrators",
    [parameter(Mandatory=$false, HelpMessage="Genarating report")]
    [switch] $All
	)

#$LDAPDomain=""

#--------------------------
#Main Variables
#--------------------------
$Domain=[ADSI]""
$DomainName = [string]$Domain.name
$DomainName = $DomainName.ToUpper()
$nCurrDepth = 0
$nMaxDepth = 10
$ReportPath

#--------------------------
#Functions
#--------------------------
function Get_ScriptDirectory {
	$Invocation = (Get-Variable MyInvocation -Scope 1).Value
	Split-Path $Invocation.MyCommand.Path
}

function Get_ActitiveDomainServers {
	try {
	    Import-Module ActiveDirectory -ErrorAction Stop
		$PasswordLastSetDate = (Get-Date).AddDays(-45)
        $ServersAD = Get-ADComputer -properties DNSHostName -filter {(OperatingSystem -like "Windows Server*") -and (PasswordLastSet -gt $PasswordLastSetDate)} | ? {$_.PrimaryGroup -ne <#Domain Admin group#>}
        $Servers = $ServersAD.DNSHostName | Sort
    }
    catch {
        #$_
        #Write-Host "Unable load ActiveDirectory module"
    }
	Return $Servers
}

function Get_LocalGroups([string]$ComputerName) {
	$Computer = [ADSI]"WinNT://$ComputerName"
    try {
        $Groups = $Computer.psbase.children | where { $_.psbase.schemaClassName -eq �group�} -ErrorAction Stop
        foreach ($Group in $Groups) {
            $GpPath =[ADSI]$group.psbase.Path
            $Members = $GpPath.psbase.Invoke("Members")
	        $Count = 0
	        $Members | ForEach-Object {$Count++}
	        if($Count -ne 0) {
		        $LocalGroups += $Group.Name
	        }
        }
    }
    catch {
        $LocalGroups = $null
    }
	Return $LocalGroups
}

function Get_FindDomainGroup([string]$GroupName) {
	$arStr = $GroupName.split("\")
	$sGroup = $arStr[1]
	$sDomain = $arStr[0]
	$searcher=new-object DirectoryServices.DirectorySearcher([ADSI]"")
	$filter="(&(objectCategory=group)(samAccountName=$sGroup))"
	$searcher.filter=$filter
	$Results = $searcher.findall()
	
	$GroupLdapPath = ""
	
	if ([int32]$Results.Count -gt [int32]0){

		$Result = $Results[0]
		$GroupLdapPath=$result.properties['adspath']
	}
	Return $GroupLdapPath	
}

function Get_LocalGroupMembers([string]$GroupPath) {
	
	$MemberNames = @()
	$GroupName = $GroupPath.Replace("\","/")
	$Group= [ADSI]"WinNT://$GroupName,group"
    $Count = 0

    $Members = @($Group.psbase.Invoke("Members"))
    $Members | ForEach-Object { $Count++ }
    if ($Count -eq 0) {
        $Count
        $DisplayString = New-Object System.Object
        $DisplayString | Add-Member -MemberType NoteProperty -Value "EmptyGroup" -Name Type
        $MemberNames += $DisplayString
    }
    else {
	    $Members = @($Group.psbase.Invoke("Members"))
	    $Members | ForEach-Object {
		    $Type = $_.GetType().InvokeMember("Class", 'GetProperty', $null, $_, $null)
            $Member = $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)
            $ADSIName = $_.GetType().InvokeMember("AdsPath", 'GetProperty', $null, $_, $null)
            if ($ADSIName -match "[^/]/[^/]") {
				$str = [String]::Join("\", $ADSIName.Split("/")[-2..-1])
            } # End if
			else {
				$str = $ADSIName.Split("/")[-1]
			}
			$GroupNameT = $GroupName.Replace("/","\")
		    $DisplayString = New-Object System.Object
            $DisplayString | Add-Member -MemberType NoteProperty -Value $Type -Name Type
            $DisplayString | Add-Member -MemberType NoteProperty -Value $str -Name SamAccountName		
            $DisplayString | Add-Member -MemberType NoteProperty -Value $GroupNameT"\"$Member -Name Member
            $DisplayString | Add-Member -MemberType NoteProperty -Value "" -Name Comment
		    if ($Type -eq "group") {
			
		    }
		    elseif ($Type -eq "user") {
			    $DisplayString | Add-Member -MemberType NoteProperty -Value $_.GetType().InvokeMember("AccountDisabled", 'GetProperty', $null, $_, $null) -Name Disabled
		    }
		    $MemberNames += $DisplayString
	    }
    }    
	Return $MemberNames
}

function Check_IfLocalGroup([string]$GroupName) {
	$blIsLocalGroup = "false"
	$hostname = hostname
	$arStr = $GroupName.split("\")
	$sGroup = $arStr[1]	
	$sDomain = $arStr[0]
	
	#Write-Host $sGroup.ToUpper() -ForegroundColor DarkMagenta
	#Write-Host $sDomain.ToUpper() -ForegroundColor Yellow
	
	if ($hostname.ToUpper() -eq $sGroup.ToUpper()) {
		$blisLocalGroup ="true"	
		#Write-Host $sGroup.ToUpper() + " localgroup" -ForegroundColor DarkMagenta
	}
	elseif ($sDomain.ToUpper() -eq  $DomainName.ToUpper())	{
		$blisLocalGroup ="false"
	}
	else {
		$searchresult = Get_FindDomainGroup($sGroup)
		if ($searchresult.length -gt 0) {
			$blisLocalGroup ="false"
		}
		else {
			$blisLocalGroup ="true"
		}
	}
	return $blIsLocalGroup
}

function Get_LDAPGroupMembers([string]$GroupLdap) {
	$MemberNames = @()
	$ADGroup=[ADSI]"$GroupLdap"
	$GroupSam = $ADGroup.samAccountName
	#Get group members
    $Count = 0
    $Members = @($ADGroup.psbase.Invoke("Members"))
    $Members | ForEach-Object { $Count++ }
    if ($Count -eq 0) {
        $Count
        $DisplayString = New-Object System.Object
        $DisplayString | Add-Member -MemberType NoteProperty -Value "EmptyGroup" -Name Type
        $MemberNames += $DisplayString
    }
    else {
	    $Members = @($ADGroup.psbase.Invoke("Members"))
	    $Members | ForEach-Object {
		    $Type = $_.GetType().InvokeMember("Class", 'GetProperty', $null, $_, $null)
            $Member = $_.GetType().InvokeMember("samAccountName", 'GetProperty', $null, $_, $null)
		    $DisplayString = New-Object System.Object
            $DisplayString | Add-Member -MemberType NoteProperty -Value $Type -Name Type
            $DisplayString | Add-Member -MemberType NoteProperty -Value $DomainName"\"$Member -Name SamAccountName		
            $DisplayString | Add-Member -MemberType NoteProperty -Value $Member -Name Member
            $DisplayString | Add-Member -MemberType NoteProperty -Value "" -Name Comment
		    if ($Type -eq "group") {
			
		    }
		    elseif ($Type -eq "user") {
			    $DisplayString | Add-Member -MemberType NoteProperty -Value $_.GetType().InvokeMember("AccountDisabled", 'GetProperty', $null, $_, $null) -Name Disabled
		    }
			$MemberNames += $DisplayString
	    }
    }
	Return $MemberNames
}

function Get_GroupMembers([string]$GroupName, [string]$isLocalGroup, [string]$AdsPath, [string]$FullPath) {
	$MemberNames = @()
	if ($isLocalGroup -eq "true") {
		$MemberNames = Get_LocalGroupMembers($GroupName)
	}
	else {
		if ($ADSPath.Contains("LDAP")) {	
			$MemberNames = Get_LDAPGroupMembers($ADSPath)
            foreach($MemberN in $MemberNames){
                if($nCurrDepth -eq 2){                    
                    $MemberN.Member = $GroupName+"\"+$MemberN.Member
                }
                elseif($nCurrDepth -gt 2){
                    $MemberN.Member = $FullPath+"\"+$MemberN.Member
                }
            }
		}
		else {
			if (!$GroupName.Contains($DomainName + "\")){
				$MemberNames = Get_LocalGroupMembers($GroupName)                
			}
		}
	}
	return $MemberNames
}

#--------------------------
#Main
#--------------------------

function Main([string]$Groupname) {
	$sGrouplist = $GroupName + "|"
	$nCurrDepth = 1
	for ($nCurrDepth = 1; $nCurrDepth -le $nMaxDepth; $nCurrDepth++) {
		if ($sGroupList.Length -gt 0) {			
			$arGroupList = $sGroupList.split("|")
			$Count = [int32]$arGroupList.Count
            #$sGroupList
			$sGroupList = ""
			for ($a = 0; $a -lt $Count - 1; $a++){
				#on the first pass only, check if the group is a local group
				if ($nCurrDepth -eq 1) {
                    $Groupname = $arGroupList[$a]
					$blLocalGroup = Check_IfLocalGroup($Groupname)
					#if the group is not a local group, lookup the ADS path
					$ADSPath = ""
					if ($blLocalGroup -eq "false") {
						$ADSPath = Get_FindDomainGroup($Groupname)
					}
                    #$ADSPath
					$MemberNames = Get_GroupMembers "$Groupname" $blLocalGroup "$ADSPath"
				}
				else {
					#Check if ADSPath is already resolved, if not, search for it
					#$GroupString= $arGroupList[$a]
                    #
                    $GroupnameTmp = $arGroupList[$a]
                    $GroupnameTmp = $GroupnameTmp.Split(":")
                    $Groupname = $GroupnameTmp[0]
                    $FullPath = $GroupnameTmp[1]
                    <#>
					if ($GroupString.Contains(";")){
					  $arTemp = $GroupString.Split(";")
					  $GroupName = $arTemp[0]
                      Write-Host  $GroupName -ForegroundColor Red
					  $ADSPath = $arTemp[0]
					}
					else {
                        Write-Host $GroupString -ForegroundColor Red
					   $Groupname = $GroupString
					   $ADSPath = ""
					}
                    #>
					if (!$ADSPath.Contains("LDAP")) {
						$ADSPath = Get_FindDomainGroup($Groupname)
					}
                    $ADSPath = Get_FindDomainGroup($Groupname)
                    #Write-Host $ADSPath -ForegroundColor Green
                    #Write-Host $Groupname -ForegroundColor Red
					$MemberNames = Get_GroupMembers "$Groupname" "false" "$ADSPath" $FullPath
				}
				ForEach($member in $MemberNames) {
					if ($member.length -gt 0) {
                        $member | Add-Member -MemberType NoteProperty -Value $Srv -Name ComputerName
						$member | Add-Member -MemberType NoteProperty -Value $Group -Name LocalGroupName
						#write-host $DisplayString
                        $member | Export-Csv $OutFileCSV -Delimiter "," -NoTypeInformation -Append -Force
						#$member
						#$DisplayString  | out-file  -append $OutFile
						if ($member.Type.ToLower() -eq "group") {
							$sGroup = $member.SamAccountName
                            $FullPath = $member.Member
                            #Write-Host $sGroup -ForegroundColor Green
                            #$sGroup
							$sGrouplist = $sGrouplist + $sGroup + ":" + $FullPath +"|"	
						}
					}
				}
				$MemberNames = ""
			}
		}
	}
}

#Start Processing

$OutPath = Get_ScriptDirectory
$OutCSVName = "\LocalAdmins_" + (get-date -Format yyyy.MM.dd_HH.mm.ss) + ".csv"
$OutFileCSV = "$OutPath\$OutCSVName"
$LogFile = $OutPath + "\LocalGroups_.log"
#(get-date -Format yyyy.MM.dd_HH.mm.ss) + ";scritp has been started" | Out-File $LogFile -Append

if ($File) {
    $Servers = Get-Content $File
}
elseif ($ComputerName -ne "") {
	$Servers = $ComputerName
}
else {
    #(get-date -Format yyyy.MM.dd_HH.mm.ss) + ";getting list of servers from AD" | Out-File $LogFile -Append
	$Servers = Get_ActitiveDomainServers
    #(get-date -Format yyyy.MM.dd_HH.mm.ss) + ";" + $Servers.count + " active servers" | Out-File $LogFile -Append
}



if ($Servers) {
	foreach ($Srv in $Servers) {
        #(get-date -Format yyyy.MM.dd_HH.mm.ss) + ";checking $Srv" | Out-File $LogFile -Append
		if (Test-Connection -ComputerName $Srv -Count 2 -quiet) {
		    if (!$GroupName) {
			    $Groups = Get_LocalGroups $Srv
		    }
		    else {
			    $Groups = $GroupName
		    }
            if ($Groups) {
		        foreach ($Group in $Groups) {
				        $nCurrDepth=0				
				        #$nMaxDepth=$args[1]
				        #"Recursion Depth: " + $nMaxDepth | out-file $OutFile -append
				        $ComputerName = $Srv + "\" + $Group
				        Main($ComputerName)
						#$11 #| ft
		        }
            }
            else {
                $tSrv = New-Object System.Object
                $tSrv | Add-Member -MemberType NoteProperty -Value $Srv -Name ComputerName
                $tSrv | Add-Member -MemberType NoteProperty -Value "Unable to get list of local groups" -Name Comment
                $tSrv | Export-Csv $OutFileCSV -Delimiter ";" -NoTypeInformation -Append -Force
            }
        }
        else {
            $tSrv = New-Object System.Object
            $tSrv | Add-Member -MemberType NoteProperty -Value $Srv -Name ComputerName
            $tSrv | Add-Member -MemberType NoteProperty -Value "Unavailable" -Name Comment
            $tSrv | Add-Member -MemberType NoteProperty -Value "" -Name SamAccountName
            $tSrv | Add-Member -MemberType NoteProperty -Value "" -Name Type
            #$tSrv | Add-Member -MemberType NoteProperty -Value "" -Name Path
            $tSrv | Add-Member -MemberType NoteProperty -Value "" -Name Member
            $tSrv | Add-Member -MemberType NoteProperty -Value "" -Name Disabled
			$tSrv | Add-Member -MemberType NoteProperty -Value "" -Name LocalGroupName
            $tSrv | Export-Csv $OutFileCSV -Delimiter ";" -NoTypeInformation -Append -Force
        }		
        #(get-date -Format yyyy.MM.dd_HH.mm.ss) + ";$Srv was checked" | Out-File $LogFile -Append
		#$tSrv
	}
}
if($OutFileCSV) {
	try {
		Copy-Item $OutFileCSV -Destination ".\$OutCSVName" -ErrorAction Stop
		Remove-Item $OutFileCSV
	}
	catch {}
}
#(get-date -Format yyyy.MM.dd_HH.mm.ss) + ";Finished" | Out-File $LogFile -Append