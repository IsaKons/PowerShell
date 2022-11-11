Get-ADUser <#MANAGERNAME#> -Properties directReports|select -ExpandProperty directReports | Get-ADUser -prop CN | Select Samaccountname |
Export-Csv '' -NoTypeInformation
$usr=Import-CSV -Path ''
$usr|%{
$cur = get-aduser $_.Samaccountname -property Memberof |Select -ExpandProperty memberOf
$uc=(get-aduser $_.Samaccountname).Name
$Cur|%{"$uc\$_">><#PATHHERE#>}
}