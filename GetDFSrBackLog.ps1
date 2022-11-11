[Int32]$Backlog = 0
$BacklogThreshold = 30000
$arr = @()
(C:\Windows\system32\cmd.exe /c "C:\Windows\dfsradmin.exe rg list /csv" | ConvertFrom-Csv).rgname | % {
$RGName = $_
$RGName
$RGData = C:\Windows\system32\cmd.exe /c ("C:\Windows\dfsradmin.exe membership list /rgname:`"{0}`" /attr:all /csv" -f $_) | ConvertFrom-Csv | select @{N="RGName";E={$RGName}},localpath,rfname,memname

$Master = $RGdata.memname | select -unique | ? {$_ -notlike "*UKHQ*" }
$Members = $RGdata.memname | select -unique | ? {$_ -notlike "*$Master*"}
$RGData.rfname | select -unique | % {
$RFName = $_

$members | % { 
$Code = "C:\Windows\system32\cmd.exe /c C:\Windows\system32\dfsrdiag.exe backlog /rgname:`"{0}`" /rfname:`"{1}`" /smem:$Master /rmem:$_" -f $RGName,$RFName
$Code
$dfsrdiag=0 #to clean value

    #$dfsrdiag = C:\Windows\system32\dfsrdiag backlog /rgname:$RGName /rfname:$RFName /smem:$Master /rmem:$_ | sls "Backlog File Count"
    $dfsrdiag = (Get-DfsrBacklog -GroupName $RGName -FolderName $RFName -SourceComputerName $Master -DestinationComputerName $RMem -Verbose 4>&1).Message.Split(':')[2]

if ($dfsrdiag) {
    #$dfsrdiag = $dfsrdiag.Tostring()
    #$Backlog = $dfsrdiag.Substring($dfsrdiag.indexOf("Backlog File Count")+20, ($dfsrdiag.length - $dfsrdiag.indexOf("Backlog File Count")-20))

    $Backlog = $dfsrdiag
}
else{
    $backlog = 0
    }
    $Report = New-object PSObject
    $Report | Add-Member -Name RGName -Value $RGName -Membertype NoteProperty
    $Report | Add-Member -Name RFName -Value $RFName -Membertype NoteProperty
    $Report | Add-Member -Name "Sending Member" -Value $Master -Membertype NoteProperty
    $Report | Add-Member -Name "Receiving Member" -Value $_ -Membertype NoteProperty
    $Report | Add-Member -Name "Backlog" -Value $Backlog -Membertype NoteProperty
    $ReportString = ($Report | Out-String).Trim()
        If ($Backlog -ge $BacklogThreshold) {
        Write-EventLog –LogName DFSRBacklog –Source “DFSRBacklog” –EntryType Error –EventID 5723 –Message “DFSR Backlog exceeded value of $BacklogThreshold`n$ReportString”
        }
    $arr+=$Report
}
}
}

$result = ($arr | Out-String).Trim()
Write-EventLog –LogName DFSRBacklog –Source “DFSRBacklog” –EntryType Information –EventID 5722 –Message "DFSR Backlog results`n$result"