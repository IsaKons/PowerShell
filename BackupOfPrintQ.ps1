# Variables
#---------------------------------
$ServersPrintList = <#File with a list of print servers#>
$PathPrint = <#Path to save#>
$Now = Get-Date
$Now2 = Get-Date -Format dd.MM.yyyy
$Days = "35"
#---------------------------------
#Delete old backups
#---------------------------------
$LastWrite = $Now.AddDays(-$Days)
$Files = Get-Childitem $PathPrint -Recurse | Where{$_.LastWriteTime -le "$LastWrite"}
foreach ($File in $Files)
{
    if ($File -ne $NULL)
    {
        write-host "Deleting File $File" -ForegroundColor "DarkRed"
        Remove-Item $File.FullName | out-null
    }
        else
        {
            Write-Host "No more files to delete!" -foregroundcolor "Green"
        }
    }
#---------------------------------
# Execute the code of backup for each server in the list 
#---------------------------------
Get-Content $ServersPrintList | ForEach-Object {
    $ServerName = $_
    $Item = $PathPrint + $ServerName + "_" + $Now2 + ".printerExport"
            if (Test-Path($Item)) { Remove-Item $Item }
            $Command  = "C:\Windows\System32\spool\tools\PrintBrm.exe -s \\$ServerName -b -f $Item"
    
    Invoke-Expression $Command
}
#---------------------------------
