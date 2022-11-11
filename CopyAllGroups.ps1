Get-ADUser -Identity XXXX -Properties memberof |
Select-Object -ExpandProperty memberof |
Add-ADGroupMember -Members YYYY -PassThru | 
Select-Object -Property SamAccountName