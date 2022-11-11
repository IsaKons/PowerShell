$Servers = Import-csv C:\Temp\ServersSH.csv
$pingable = @()
$notpingable = @()
#Test servers for ping
ForEach($server in $Servers) {
        if (test-Connection -ComputerName $Server.server -Count 2 -Quiet ) {  
            write-Host "$Server is alive and Pinging " -ForegroundColor Green 
            $pingable += $server.server
                    } 
                    else 
                    { 
                    Write-Warning "$Server seems dead not pinging" 
                    $notpingable += $server.server
                    }     
} 
$notpingable | Export-Csv 'C:\Temp\notpingable.csv'

#get fileshares from pingable servers
$shareslist =@()
ForEach($pingserv in $pingable) {
    try
    {
     $share = Get-WmiObject -Credential <#CREDS#> -ComputerName <#NAME#> -Class Win32_Share -ErrorAction Stop
     $share | Select-Object -Property PSComputerName,Name,Path,Description | write-host
     $shareslist += $share
    }
    catch
    {
     write-error "Failed with $pingserv"
    }
 }
$shareslist | Select-Object -Property PSComputerName,Name,Path,Description | Export-Csv -Path 'C:\Temp\Shareslist.csv' -NoTypeInformation