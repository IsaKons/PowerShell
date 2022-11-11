$FileFolder = ''
$share = Get-ChildItem -Path $FileFolder -recurse
$Final = @()
foreach ($sharka in $share) {
    $property = [ordered] @{
        Filename = $sharka.name      
        Creadted_Date = $sharka.creationtime
        Date_Modify = $sharka.LastWriteTime
        Owner = (Get-Acl $sharka.FullName).Owner
        Last_Access = $sharka.lastAccessTime
        File_Size = "{0:N2}" -f ($sharka.length / 1MB) + " MB"
        }
    $obj = New-Object –TypeName PSObject –Property $property
    $Final += $obj
}
$final | Format-Table


PARAM (
  $Path = 'Z:\',
  $report = ''
)

New-PSDrive –Name “Z” –PSProvider FileSystem –Root “” –Persist

$Owner = @{
  Name = 'File Owner'
  Expression = { (Get-Acl $_.FullName).Owner }
}

$length = @{
   Name = 'Length'
   Expression = { "{0:N2}" -f ($_.length / 1MB) + " MB"}
}
Get-ChildItem -Recurse -Path $Path | select attributes, name, creationtime, LastWriteTime, $Length, lastAccessTime, $Owner, Directory | Export-Csv -NoTypeInformation $Report
