$CDP = ""
$ServerIP
$TempFile = "./tempfile.crl"

$Now = (Get-Date).ToLocalTime()

# Build our Custom Status Object to Return
$Result = "" | Select-Object "CDP","HoursTilExpiry","Issuer","AKI","ServerIP","DownloadOK","ValidFrom","ValidTo","NextCRLPublish","CurrentDate","BaseCRL","HashAlgorithm","CRLNumber"	
$Result.CDP = $CDP
	 
# Grab the CDP Host Header from the CDP Variable
$HostHeader = ([System.Uri]$CDP).Host
    
# If we recieved a ServerIP Address, Extract the Host header and update the CDP Path. This will override DNS lookup so we can query load balanced web servers. Log how we are performing the server lookup
If($ServerIP)
{
    $CDP = $CDP -Replace ($HostHeader,$ServerIP)
    $Result.ServerIP = $ServerIP
}
Else 
{
    $Result.ServerIP = "Via DNS Lookup"
}
   	
# Attempt to download the file from the server
Try { Invoke-WebRequest $CDP -Headers @{Host = $HostHeader} -OutFile $TempFile}	
Catch { 
	$Result.Status = "NoDownload"
	$Result.Description = "NoDownload - Failed to download CRL"
	$Result.DownloadOK = $False
	}
If ($Result.Status -ne "NoDownload"){

	$Result.DownloadOK = $True

	# Open the CRL as A Byte file and then convert to Base64
	$CRLContents = [System.Convert]::ToBase64String((Get-Content $TempFile -Encoding Byte))
			
	# Create a X509 CRL Object and Intiliaze all of the CRL data into It
	$CRL = New-Object -ComObject "X509Enrollment.CX509CertificateRevocationList"
	$CRL.InitializeDecode($CRLContents,1) 									# 1 = XCN_CRYPT_STRING_BASE64
			
	# Grab the current ValidFrom/ValidTo Extensions
	$ThisUpdate = ($CRL.ThisUpdate).ToLocalTime()
	$NextUpdate = ($CRL.NextUpdate).ToLocalTime()

	# Attempt to grab the Next CRL Publish Date Extension
	Try {
		$NextPublishExtension = ($CRL.X509Extensions | Where-Object {$_.ObjectID.Value -eq '1.3.6.1.4.1.311.21.4'})
		$NextPublishData = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($NextPublishExtension.RawData("1")))
		$NextPublishData  = $NextPublishData.Remove(0,2) 					# Strip the first 2 bytes (type and length)
		$NextCRLPublish = [DateTime]::ParseExact($NextPublishData,"yyMMddHHmmss\Z",$null)
		$NextCRLPublish = $NextCRLPublish.ToLocalTime()
		}
	Catch { $NextCRLPublish = "Not Available"}
			
	# Attempt to grab the CRL Number Extension
	Try {
		$CRLNumberExtension = ($CRL.X509Extensions | Where-Object {$_.ObjectID.Value -eq '2.5.29.20'})
		$CRLNumberExtensionData = $CRLNumberExtension.RawData("4")
		$CRLNumberExtensionData = $CRLNumberExtensionData -Replace(" ","")
		$CRLNumber = $CRLNumberExtensionData.Remove(0,4) 					# Strip the first 2 bytes (type and length)
		}
	Catch { $CRLNumber = "Not Available"}

	# Attempt to grab the AKI Extension
	Try {
		$AKIExtension = ($CRL.X509Extensions | Where-Object {$_.ObjectID.Value -eq '2.5.29.35'})
		$AKIExtensionData = $AKIExtension.RawData("4")
		$AKIExtensionData = $AKIExtensionData -Replace(" ","")
		$AKIExtensionData = $AKIExtensionData -Replace("`n","")
		$AKI = $AKIExtensionData.Remove(0,8) 					# Strip the first 4 bytes
		}
	Catch {$AKI = "Not Available"}

	# Compare against Next CRL Publish if it's present or generic 3/2/1 days unless WarningHours Override specified.
	$HoursTilExpiry = [Decimal]::Round((New-TimeSpan $Now $NextUpdate).TotalHours)
			
		# Populate the Return Object with more details
		$Result.HoursTilExpiry = $HoursTilExpiry
		$Result.ValidFrom = $ThisUpdate
		$Result.ValidTo = $NextUpdate
		$Result.NextCRLPublish = $NextCRLPublish
		$Result.CurrentDate = $Now
		$Result.Issuer = (($CRL.Issuer.Name).Split(",")[0]).Remove(0,3)
		$Result.BaseCRL = $CRL.BaseCRL
		$Result.HashAlgorithm = ($CRL.HashAlgorithm.FriendlyName).ToUpper()
		$Result.CRLNumber = $CRLNumber
		$Result.AKI = $AKI
		
	} # End of CRL Download If

# Return the Results
$Result

If($Result.HoursTilExpiry -le 720)
{
    New-EventLog -LogName CRLMonitor_Log -Source CRLMonitor
    Write-EventLog -LogName CRLMonitor_Log -Source CRLMonitor -EventID 2222 -EntryType Error -Message "Root CRL should be updated"
}
