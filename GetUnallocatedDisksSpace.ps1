$serv = Import-Csv "" 
$Final = @()

foreach( $s in $serv.name){ 
    if(Test-Connection -Cn $s -BufferSize 16 -Count 1 -ea 0 -quiet)
    {
        try { 
            $disks = gwmi win32_diskdrive -ComputerName $s -ea Stop
            $partitions = gwmi win32_diskpartition -ComputerName $s -ea Stop
            $unpartitioned = 0
            $i = 0
            $partitionCount = 0
            $obj = $null
                foreach($disk in $disks) {
                    foreach($partition in $partitions) {
                        if($partition.DiskIndex -eq $disk.index) {
                            $partitionCount++
                            $i += $partition.size
                        }
                    }
                    $obj = New-Object -TypeName PSObject
                    $obj | Add-Member -MemberType NoteProperty -Name ServerName -Value $s
                    $obj | Add-Member -MemberType NoteProperty -Name DiskIndex -Value $disk.index
                    $obj | Add-Member -MemberType NoteProperty -Name TotalSpace -Value $disk.size 
                    $obj | Add-Member -MemberType NoteProperty -Name PartitionCount -Value $partitionCount
                    $obj | Add-Member -MemberType NoteProperty -Name UnallocatedSpace -Value $(($disk.size - $i))

                    $Final += $obj
                    $obj = $null
                    $i=0
                    $partitionCount=0
                }
        }
        Catch { "Server $s not accessible" | Out-File -Append C:\temp\isajev\noacc2.txt }
    }
    }
$Final | Export-Csv C:\temp\isajev\unalocated.csv