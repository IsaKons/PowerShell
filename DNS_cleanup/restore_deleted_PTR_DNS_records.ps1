#This script will recreate DNS PTR records from "create_report_and_clear_old_DNS_records" PTR log

$path = Read-Host -Prompt "Enter the full path of PTR record deletion log file without quotation marks"
$list = Import-Csv -Path $path -Delimiter ';'
$DNSServer = "" #DNS server

foreach ($line in $list)
{
$Status = $line.Status
$PTRRecordName = $line.IP_PTR
$PTRDomainName = $line.Name
$ReverseZoneName = $line.Name_zone

    if ($Status -like "Delete")
        {
            Add-DnsServerResourceRecordPtr -ComputerName $DNSServer -Name $PTRRecordName -PtrDomainName $PTRDomainName -ZoneName $ReverseZoneName -AllowUpdateAny -TimeToLive 01:00:00 -AgeRecord
            Write-Host $PTRDomainName -For Green
        }        
    else
        {
            Write-Host $PTRDomainName -For Red
        }
}