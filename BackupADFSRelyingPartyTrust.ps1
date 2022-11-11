Get-AdfsRelyingPartyTrust | Out-File “C:\temp\backup\RelyingPartyTrust_All.txt"
$All = Get-AdfsRelyingPartyTrust 

foreach ($name in $all.name)
{

    $temp = Get-AdfsRelyingPartyTrust -name $name 
    $temp | Out-File C:\temp\backup\"$name"_RelyingPartyTrust.txt
    if ($temp.EncryptionCertificate)
    {
        $decimalcertencryption = ($temp.EncryptionCertificate.GetRawCertData())
        [Convert]::ToBase64String($decimalcertencryption) | Out-File C:\temp\backup\"$name"_Encryption_Certificate.cer
    }
    if ($temp.RequestSigningCertificate)
    {
        $decimalcertsigning = ($temp.RequestSigningCertificate.GetRawCertData())
        [Convert]::ToBase64String($decimalcertsigning) | Out-File C:\temp\backup\"$name"_Signing_Certificate.cer
    }

}
$date = Get-Date -UFormat "%m-%d-%Y"
Compress-Archive -Path C:\temp\backup\* -DestinationPath C:\temp\backup\"$date".zip

$source = "C:\temp\backup\$date.zip"
$Destination = " "

New-Item -ItemType directory -Path $Destination -Force
Copy-Item -Path $Source -Destination $Destination -Force

Start-Sleep -s 15

Remove-Item –path C:\temp\backup\*