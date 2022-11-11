$path = $MyInvocation.MyCommand.Path | Split-Path -Parent   #Folder 
$currentdate = (Get-Date -Format 'yyyy-MM-dd')
$ErrorFile = "$path\Error.txt"

$compare = $true # set false for gathering data in first step, and set true to compare after migration

$CIFS_Folders = @('')

foreach ($CIFS_Folder in $CIFS_Folders)
    {
        $dir_name = $CIFS_Folder.Split('\')[-1]
        if (!$compare) {$OutFile = "$path\ACL_main_$dir_name.csv"; if (Test-Path "$path\ACL_main_$dir_name.csv") {Del "$path\ACL_main_$dir_name.csv"}}
        else { $OutFile = "$path\ACL_$dir_name $currentdate.csv"; if (Test-Path "$path\ACL_$dir_name $currentdate.csv") {Del "$path\ACL_$dir_name $currentdate.csv"}}

        $Header = "Folder Path,IdentityReference,AccessControlType,IsInherited,InheritanceFlags,PropagationFlags"

        Add-Content -Value $Header -Path $OutFile

        $RootPath = $CIFS_Folder

        #$Folders = dir $RootPath -recurse | where {$_.psiscontainer -eq $true}
        $Folders = dir $RootPath  | where {$_.psiscontainer -eq $true}

        foreach ($Folder in $Folders)
            {
                try
                    {
                        $ACLs = get-acl $Folder.fullname | ForEach-Object { $_.Access  }
                        Foreach ($ACL in $ACLs)
                            {
                                $OutInfo = $Folder.Fullname + “,” + $ACL.IdentityReference  + “,” + $ACL.AccessControlType + “,” + $ACL.IsInherited + “,” + $ACL.InheritanceFlags + “,” + $ACL.PropagationFlags
                                Add-Content -Value $OutInfo -Path $OutFile
                            }
                    }
                catch
                    {
                        Add-Content -Value $Folder -Path $ErrorFile
                    }
            }

        if ($compare)
            {
               Compare-Object -ReferenceObject $(gc "$path\ACL_main_$dir_name.csv") -DifferenceObject $(gc "$path\ACL_$dir_name $currentdate.csv")
            }
    }