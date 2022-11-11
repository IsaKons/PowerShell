$search = New-Object DirectoryServices.DirectorySearcher([ADSI]"")
$search.filter = "(servicePrincipalName=*)"
$results = $search.Findall()
$Final = @()

foreach($result in $results)
{
       $userEntry = $result.GetDirectoryEntry()

       Write-host "Object Name = " $userEntry.name -backgroundcolor "yellow" -foregroundcolor "black"
       Write-host "DN      =      "  $userEntry.distinguishedName
       Write-host "Object Cat. = "  $userEntry.objectCategory
       Write-host "servicePrincipalNames"
 
       $i=1

       [string]$Object_Name = $userEntry.name
       [string]$DN = $userEntry.distinguishedName
       [string]$ObjectCat = $userEntry.objectCategory

       foreach($SPN in $userEntry.servicePrincipalName)
       {
       $obj = New-Object -TypeName PSObject
                    $obj | Add-Member -MemberType NoteProperty -Name Object_Name -Value $Object_Name
                    $obj | Add-Member -MemberType NoteProperty -Name DN -Value $DN
                    $obj | Add-Member -MemberType NoteProperty -Name ObjectCat -Value $ObjectCat
                    $obj | Add-Member -MemberType NoteProperty -Name NumberOnS -Value $i
                    $obj | Add-Member -MemberType NoteProperty -Name servicePrincipalName -Value $SPN

         $Final += $obj
         $obj = $null

           Write-host "SPN(" $i ")   =      " $SPN       
           $i+=1
       }
       Write-host ""
}
$Final | Export-Csv C:\temp\isajev\SPN.csv