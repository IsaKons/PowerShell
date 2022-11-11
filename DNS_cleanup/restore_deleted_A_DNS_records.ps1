#This script will recreate DNS A records from "create_report_and_clear_old_DNS_records" log

$path = Read-Host -Prompt "Enter the full path of A record deletion log file without quotation marks"
$list = Import-Csv -Path $path -Delimiter ';'
$DNSServer = "" #DNS server

foreach ($line in $list)
{
$Status = $line.Status
$Hostname = $line.Hostname
$IPAddress = $line.IP

    if ($Status -like "Delete")
        {
            Add-DNSServerResourceRecordA -ComputerName $DNSServer -Name $Hostname.Trim() -IPv4Address $IPAddress -ZoneName "" -AllowUpdateAny
            Write-Host $Hostname -For Green
        }        
    else
        {
            Write-Host $Hostname -For Red
        }
}