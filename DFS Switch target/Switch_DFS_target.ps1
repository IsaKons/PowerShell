param (
    [Parameter(Mandatory=$false)]
        [string]$server = "" # from which server we must switch
    ,[Parameter(Mandatory=$false)]
        [string]$action = "0" # [0,1]:  value "1", if you need to switch to online mode, value "0" if you need to offline
    ,[Parameter(Mandatory=$false)]
        [string]$DFS_namespace = ""
)


#Function: swirch target offline
function set_offline{
  param (
    [Parameter(Mandatory=$true)]
        [string]$target_online 
    ,[Parameter(Mandatory=$true)]
        [string]$path
        )

$servername = $null

try
    {
        # Set target Offline
        Set-DfsnFolderTarget -Path $path -TargetPath $target_online -State Offline  

        # Set Everyone permission
        $servername = $target_online -split "\\" | Where {  $_ -ne ""  } | Select -first 1 #extract server name from path for connecting to this server and change share permissions

        $n = $servername.Length + 3
        $folder_name = $target_online.Substring($n ,$target_online.Length - $n) #extract share folder name from path

        if(Test-Connection -Cn $servername -BufferSize 16 -Count 1 -ea 0 -quiet) {$connect = $true}
        else {$connect = $false}

        if ($connect) 
            {
                try
                    {
                        $b = Invoke-Command -ComputerName $servername -ScriptBlock {
                                    param($name)
                                    Revoke-SmbShareAccess -Name $name -AccountName "Everyone" -Force} -ArgumentList $folder_name
                    }
                catch
                    {
                        Write-Host "Error to revoke smb permission on $online" -ForegroundColor Red
                    }
            }

        # Logging
        $Timestamp = (Get-Date -Format 'yyyy-MM-dd hh:mm:ss')
        $textout = $Timestamp + ",OK set offline," + $path + "," + $target_online 
        Write-Host $textout -ForegroundColor Green
        Add-Content $logfile $textout

    }
catch
    {
        $Timestamp = (Get-Date -Format 'yyyy-MM-dd hh:mm:ss')
        $textout = $Timestamp + ",Error set offline," + $path + "," + $target_online 
        Write-Host $textout -ForegroundColor Red
        Add-Content $logfile $textout
    }

}

#Function: swirch target online
function set_online{
  param (
    [Parameter(Mandatory=$true)]
        [string]$target_offline  
    ,[Parameter(Mandatory=$true)]
        [string]$path
        )

$servername = $null

try
    {
        # Set target Online
        Set-DfsnFolderTarget -Path $path -TargetPath $target_offline -State Online 


        # Set Everyone permission
        $servername = $target_offline -split "\\" | Where {  $_ -ne ""  } | Select -first 1 #extract server name from path for connecting to this server and change share permissions

        $n = $servername.Length + 3
        $folder_name = $target_offline.Substring($n ,$target_offline.Length - $n) #extract share folder name from path

        if(Test-Connection -Cn $servername -BufferSize 16 -Count 1 -ea 0 -quiet) {$connect = $true}
        else {$connect = $false}

        if ($connect) 
            {
                try
                    {
                        $b = Invoke-Command -ComputerName $servername -ScriptBlock {
                                param($name)
                                Grant-SmbShareAccess -Name $name -AccountName "Everyone" -AccessRight Full -Force} -ArgumentList $folder_name
                    }
                catch
                    {
                        Write-Host "Error to grant smb permission on $target_offline" -ForegroundColor Red
                    }
            }
         # Logging
         $Timestamp = (Get-Date -Format 'yyyy-MM-dd hh:mm:ss')
         $textout = $Timestamp + ",OK set online," + $path + "," + $target_offline 
         Write-Host $textout -ForegroundColor Green
         Add-Content $logfile $textout
    }
catch
    {
        $Timestamp = (Get-Date -Format 'yyyy-MM-dd hh:mm:ss')
        $textout = $Timestamp + ",Error set online," + $path + "," + $offline 
        Write-Host $textout -ForegroundColor Red
        Add-Content $logfile $textout

    }

}

################# MAIN BODY ############################################################################

$currentdate = (Get-Date -Format 'yyyy-MM-dd hh_mm_ss')

$path = $MyInvocation.MyCommand.Path | Split-Path -Parent   #Folder to export-import file, logs

$logfile = "$path\log_switch_$currentdate.csv"

$folders = Get-DfsnFolder -Path $DFS_namespace | select-object Path #get all DFS folders
Foreach ($folder in $folders)
    {
      ### Start: find online and offline target  and get their state
      $Paths = Get-DfsnFolderTarget -Path $folder.Path | Select-Object Path,TargetPath,State 

      $server_exist = $false
      foreach ($s in $Paths) 
        {
          $path = $s.Path
          if ($s.TargetPath -match $server) {$server_exist = $true}

        }
      if ($server_exist -and $Paths.count -gt 1)
        {
            foreach ($s in $Paths) 
                {
                  $path = $s.Path
                  $targetpath = $s.TargetPath
                  if ($targetpath -match $server) 
                    {
                        if ($action -eq 0)
                            {
                                set_offline -target_online $targetpath -path $path
                            }
                        elseif ($action -eq 1)
                            {
                                set_online -target_offline $targetpath -path $path
                            }

                    }
                  else
                    {
                        if ($action -eq 0)
                            {
                                set_online -target_offline $targetpath -path $path
                            }
                        elseif ($action -eq 1)
                            {
                                set_offline -target_online $targetpath -path $path    
                            }
                    }

                }

        }

    }