Function Add-OutputBoxLine # Simple function to add info for user on GUI
{
    Param ($Message)
    $OutputBox.AppendText("`r`n$Message")
    $OutputBox.Refresh()
    $OutputBox.ScrollToCaret()
}
Function AddAcl # For adding access to many with exclusion
{
    param($exc = 1, $mas = 1, $user, $foldersforADDACL, $needacces, $exclusionOnServ1, $exclusionOnServ2, $exclusionOnServ3, $exclusionOnServ4)

    $StringBuilder = New-Object System.Text.StringBuilder
    $projectshare = ""
    $projectshare2 = ""
    $projectshare3 = ""

    If($mas -gt 2)
    {
        $foldersstate = Get-ChildItem $foldersforADDACL -Recurse -Directory
        $foldersforADDACLF = $foldersstate.fullname
    }
    else{$foldersforADDACLF = $foldersforADDACL}

    foreach ($path in $foldersforADDACLF)
    {   
        if(($path -like $projectshare) -or ($path -like $projectshare2) -or ($path -like $projectshare3))
        {
            $null = $StringBuilder.AppendLine( "$( Get-Date -UFormat '%d.%m.%Y %H:%M:%S') $path is exclusion and project")
            continue
        }

        if($exc -gt 2) 
        {
            if($($path.Contains($projectshare2)) -or $($path.Contains($exclusionOnServ1) -and ![string]::IsNullOrWhiteSpace($exclusionOnServ1)) -or $($path.Contains($exclusionOnServ2) -and ![string]::IsNullOrWhiteSpace($exclusionOnServ2)) -or $($path.Contains($exclusionOnServ3) -and ![string]::IsNullOrWhiteSpace($exclusionOnServ3)) -or $($path.Contains($exclusionOnServ4) -and ![string]::IsNullOrWhiteSpace($exclusionOnServ4)))
            {                    
                $null = $StringBuilder.AppendLine( "$( Get-Date -UFormat '%d.%m.%Y %H:%M:%S') $path is exclusion")
                continue
            }
        }         
           
        $permex = (Get-Acl $path).Access | ?{$_.IdentityReference -match $($user.Split("\"))[1] -and $_.FileSystemRights -match $needacces} | Select IdentityReference,FileSystemRights
        if ($permex){$null = $StringBuilder.AppendLine( "$( Get-Date -UFormat '%d.%m.%Y %H:%M:%S') $user already have $($permex.filesystemRights) to folder - $path")}
        else
        {
            try
            {
                $acl = (Get-Item $path).GetAccessControl("Access")
                $permission = "$user","$needacces","ContainerInherit,ObjectInherit","None","Allow"
                $accessrule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
                $acl.SetAccessRule($accessrule)
                $acl | Set-Acl -Path $path -ErrorAction Stop 
                $null = $StringBuilder.AppendLine( "$( Get-Date -UFormat '%d.%m.%Y %H:%M:%S') For $user was provided $needacces access to $path")
            }
            catch{$null = $StringBuilder.AppendLine( "You got this error - $_")}
        }
    }
    $result = $StringBuilder.ToString()
    return $result
} 
Function Getfolder # find share on server 
{
    param($mainpath)

    $link = $mainpath
    $linkTMP = $link
    $i = 0

    while ([string]::IsNullOrEmpty(($resultshare = Get-DfsnFolderTarget -Path $link | ?{$_.State -eq "Online"} | select TargetPath)))
    {
        $i++
        $link = $link.Substring(0,$link.Length-1)
    }

    $pbrTest.Value = 25
    $resultshare = $resultshare.TargetPath
    $server = $($resultshare.split("\"))[2]
    $sharename = $($resultshare.split("\"))[3]
    try
    {
        $servertest = Test-Connection -Cn $server -BufferSize 16 -Count 1 -ea 0 -quiet
    }
    catch
    {  
        Add-OutputBoxLine -Message "You got this error - $_ it seems that server not found, start providing remotely" 
    }
    $SharePath = Get-WmiObject -Class Win32_Share -ComputerName $server | ?{$_.Name -eq $sharename} | select Path
    $needtoadd = "\$($linkTMP.Substring($linkTMP.Length-$i))"
    $folderonserver = "$($SharePath.path)$needtoadd"

    return $folderonserver, $server, $servertest
}
Function DeleteACL #Removing from ACL
{
    param($user, $mainpath)

    $foldersstate = Get-ChildItem $mainpath -Recurse -Directory
    $foldersforDel = $foldersstate.fullname
    $foldersonserver = ,"$mainpath" + $foldersforDel

    $StringBuilder = $null
    $StringBuilder = New-Object System.Text.StringBuilder

    foreach ($path in $foldersonserver)
    {
        $permex = (Get-Acl $path).Access | ?{$_.IdentityReference -match $($user.Split("\"))[1] -and $_.FileSystemRights -match $needacces} | Select IdentityReference,FileSystemRights
        if ($permex)
        {
            $acl = Get-Acl $path
            $access = $acl.Access

            foreach ($a in $access)
            {
                $ids = $a.IdentityReference.Value
                foreach ($id in $ids)
                {
                    if ($($id.split("\"))[1] -eq $user) 
                    {
                        $Account = new-object system.security.principal.ntaccount($user)
                        $f = Convert-Path $acl.PSPath
                        $ACL.PurgeAccessRules($Account)
                        Set-Acl -path $f -aclObject $acl | Out-Null
                        $null = $StringBuilder.AppendLine( "$( Get-Date -UFormat '%d.%m.%Y %H:%M:%S') $path access removed for $user" )
                    }
                }
            }
        }
    }
    $results = $StringBuilder.ToString()
    return $results
} 
Function Main # Main logic
{
    param($user, $mainpath, $needacces, $checkbox, $checkbox2, $exclusion1, $exclusion2, $exclusion3, $exclusion4)

    Add-OutputBoxLine -Message "Account: $who_run_script" # Append to identify who to do changes

    $watchwork.restart()
    $results = @()
    $projectshare = ""
    $projectshare2 = ""
    $projectshare3 = ""
    $JupiterShare = ""

    #[1]Converts access from GUI to real and create a marks for group find//////
    If($needacces -eq "Read")
    {
        $needacces = "ReadAndExecute"; 
        $pbrTest.Value = 5
    }
    elseif ($needacces -eq "read&write")
    {
        $needacces = "DeleteSubdirectoriesAndFiles, Modify"; 
        $pbrTest.Value = 5
    }
    else
    {
        Add-OutputBoxLine -Message "$needacces is incorrect"
        $pbrTest.Value = 0
        $watchwork.stop()
        return
    }
    Add-OutputBoxLine -Message "Access needeed - $needacces"

    #[2]Get user samaccountname and check it///////////////////////////////////////
    try
    {
        $userOnly = $user
        $checkuser = get-aduser $user
        if($checkuser){Add-OutputBoxLine -Message "$user found"; $user = "PUT YOUR DOMAIN HERE \$user"} 
        $pbrTest.Value = 10   
    }
    catch
    {
        Add-OutputBoxLine -Message "$user NOT found"

        $pbrTest.Value = 0
        $watchwork.stop()
        Add-OutputBoxLine -Message $watch.Elapsed
        return
    }

    #[3]Get path from the GUI and check it, also check if is project shared folder///////////////////////////////
    $testpath = Test-Path $mainpath
    if($testpath -eq "True")
    {
        Add-OutputBoxLine -Message "$mainpath exist"
        $pbrTest.Value = 15

        #take groups
        $Allgroups = @()
        $objectsACL = (Get-Acl $mainpath).Access | Select IdentityReference
        Foreach ($obj in $objectsACL.IdentityReference) 
        {
            $ObjForG = $($obj.value).Split("\")[1]
            If ($($obj.value).Split("\")[0] -eq <#Domain name here#>)
            {
                $checkGroup = Get-ADObject -Filter {(SamAccountName -eq $ObjForG)} -Properties *  | Select ObjectClass, Description, SamAccountName
                IF ($checkGroup.ObjectClass -eq "group") {$Allgroups += $checkGroup}
            }
        }
        
        if(($mainpath -like $projectshare) -or ($mainpath -like $projectshare2) -or ($mainpath -like $projectshare3) )
        {
            Add-OutputBoxLine -Message "$mainpath is project related share, programm wont work with $projectshare shares"
            $pbrTest.Value = 0
            $watchwork.stop()
            return
        }
        elseif($mainpath -like $JupiterShare)
        {
            # Create window for Jupiter

            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -AssemblyName System.Drawing

            $formGroups = New-Object System.Windows.Forms.Form
            $formGroups.Text = 'For JUPITER shares only acces thru AD group'
            $formGroups.Size = New-Object System.Drawing.Size(300,200)
            $formGroups.StartPosition = 'CenterScreen'
            $formGroups.AutoSize = $true

            $Labeltext = New-Object System.Windows.Forms.Label
            $Labeltext.Text = "WARNING! All Jupiter shares, have the AD groups for access. If not, go ot AD and create it! If any questions, go to tier 3 engineers."
            $Labeltext.Location  = New-Object System.Drawing.Point(0,10)
            $Labeltext.AutoSize = $true
            $formGroups.Controls.Add($Labeltext)

            $OKButtonGroups = New-Object System.Windows.Forms.Button
            $OKButtonGroups.Location = New-Object System.Drawing.Point(0,35)
            $OKButtonGroups.Size = New-Object System.Drawing.Size(75,23)
            $OKButtonGroups.Text = 'OK'
            $OKButtonGroups.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $formGroups.AcceptButton = $OKButtonGroups
            $formGroups.Controls.Add($OKButtonGroups)

            $labelGroups = New-Object System.Windows.Forms.Label
            $labelGroups.Location = New-Object System.Drawing.Point(75,40)
            $labelGroups.AutoSize = $true
            $labelGroups.Text = 'Please select a group if one of them suits you.'
            $formGroups.Controls.Add($labelGroups)

            $listBoxGroups = New-Object System.Windows.Forms.ListBox
            $listBoxGroups.Location = New-Object System.Drawing.Point(0,60)
            $listBoxGroups.AutoSize = $true
            $listBoxGroups.Height = 80

            Foreach($groupAD in $Allgroups) 
            {
                [void] $listBoxGroups.Items.Add($($groupAD | select SamAccountName, Description))
            }

            $formGroups.Controls.Add($listBoxGroups)

            $formGroups.Topmost = $true
            $result = $formGroups.ShowDialog()

            # Calculate result - add groups
            if ($result -eq [System.Windows.Forms.DialogResult]::OK)
            {
                $SelectedGroup = $listBoxGroups.SelectedItem
                if ($SelectedGroup )
                {
                    try 
                    { 
                        Add-ADGroupMember -Identity $SelectedGroup.SamAccountName -Member $userOnly 
                    }
                    catch 
                    {
                        $testca = ($_.Exception.Message).ToString()
                        Add-OutputBoxLine -Message "Something going wrong - $testca"
                    }
                    Add-OutputBoxLine -Message "$user added to $($SelectedGroup.SamAccountName)" 
                    return 
                }
            }
            else 
            {
                Add-OutputBoxLine -Message "User is NOT added to the group"
                $pbrTest.Value = 0 
                return
            }
        }
    }
    else
    {
        Add-OutputBoxLine -Message "$mainpath DOESNT exist or you dont have access to it"
        $pbrTest.Value = 0 
        return
    }


    # Create window
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $formGroups = New-Object System.Windows.Forms.Form
    $formGroups.Text = 'ADD USER IN GROUP'
    $formGroups.Size = New-Object System.Drawing.Size(300,200)
    $formGroups.StartPosition = 'CenterScreen'
    $formGroups.AutoSize = $true

    $OKButtonGroups = New-Object System.Windows.Forms.Button
    $OKButtonGroups.Location = New-Object System.Drawing.Point(10,10)
    $OKButtonGroups.Size = New-Object System.Drawing.Size(75,23)
    $OKButtonGroups.Text = 'OK'
    $OKButtonGroups.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $formGroups.AcceptButton = $OKButtonGroups
    $formGroups.Controls.Add($OKButtonGroups)

    $CancelButtonGroups = New-Object System.Windows.Forms.Button
    $CancelButtonGroups.Location = New-Object System.Drawing.Point(85,10)
    $CancelButtonGroups.AutoSize = $true
    $CancelButtonGroups.Text = 'Proceed without adding in group'
    $CancelButtonGroups.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $formGroups.CancelButton = $CancelButtonGroups
    $formGroups.Controls.Add($CancelButtonGroups)

    $labelGroups = New-Object System.Windows.Forms.Label
    $labelGroups.Location = New-Object System.Drawing.Point(10,20)
    $labelGroups.AutoSize = $true
    $labelGroups.Text = 'Please select a group if one of them suits you.'
    $formGroups.Controls.Add($labelGroups)

    $listBoxGroups = New-Object System.Windows.Forms.ListBox
    $listBoxGroups.Location = New-Object System.Drawing.Point(10,40)
    $listBoxGroups.AutoSize = $true
    $listBoxGroups.Height = 80

    Foreach($groupAD in $Allgroups) 
    {
        [void] $listBoxGroups.Items.Add($($groupAD | select SamAccountName, Description))
    }

    $formGroups.Controls.Add($listBoxGroups)

    $formGroups.Topmost = $true
    $result = $formGroups.ShowDialog()

    # Calculate result - add groups
    if ($result -eq [System.Windows.Forms.DialogResult]::OK)
    {
        $SelectedGroup = $listBoxGroups.SelectedItem
        if ($SelectedGroup )
        {
            try 
            { 
                Add-ADGroupMember -Identity $SelectedGroup.SamAccountName -Member $userOnly 
            }
            catch 
            {
                $testca = ($_.Exception.Message).ToString()
                Add-OutputBoxLine -Message "Something going wrong - $testca"
            }
            Add-OutputBoxLine -Message "$user added to $($SelectedGroup.SamAccountName)" 
            return 
        }
    }
    else {Add-OutputBoxLine -Message "No group for user, continue with standard procedure"}


    $pbrTest.Value = 20

    #[5]Get the share location to do work there////////////////////////////////////////////
    if($($mainpath.split("\")).count -gt 5){$tempa = $true}
    elseif($($mainpath.split("\"))[2] -eq <#Domain Name Here#> -and !($($mainpath.split("\")).count -gt 5))
        {
            Add-OutputBoxLine -Message "Too short path, check path!"
            $pbrTest.Value = 0 
            return
        }

    $mainfolderonserverinfo = Getfolder $mainpath
    $folderonserverMain = $mainfolderonserverinfo[0]
    $serverMain = $mainfolderonserverinfo[1]
    $servertestMain = $mainfolderonserverinfo[2]
    
    
    if($checkbox2 -eq $true) 
    { 
        if(![string]::IsNullOrWhiteSpace($exclusion1))
        {
            $exc1info = Getfolder $exclusion1
            $exclusionOnServ1 = $exc1info[0]
            Add-OutputBoxLine -Message "Received exclusion - $exclusionOnServ1"
        }
        if(![string]::IsNullOrWhiteSpace($exclusion2))
        {
            $exc2info = Getfolder $exclusion2
            $exclusionOnServ2 = $exc2info[0]
            Add-OutputBoxLine -Message "Received exclusion - $exclusionOnServ2"
        }
        if(![string]::IsNullOrWhiteSpace($exclusion3))
        {
            $exc3info = Getfolder $exclusion3
            $exclusionOnServ3 = $exc3info[0]
            Add-OutputBoxLine -Message "Received exclusion - $exclusionOnServ3"
        }
        if(![string]::IsNullOrWhiteSpace($exclusion3))
        {
            $exc4info = Getfolder $exclusion4
            $exclusionOnServ4 = $exc4info[0]
            Add-OutputBoxLine -Message "Received exclusion - $exclusionOnServ4"
        }
    }

    If($serverMain -and $folderonserverMain){ Add-OutputBoxLine -Message "founded that this share located on $serverMain and it is $folderonserverMain "}

    ########

    #[6]Provide acces to main folder 
    $pbrTest.Value = 30

    if($servertestMain -and $tempa)
    {
       $exc = 1
       $mas = 1
       Add-OutputBoxLine -Message "Connecting to the server $serverMain"
       Add-OutputBoxLine -Message "Providing access to $folderonserverMain"
       $Mainstate = Invoke-Command -ComputerName $serverMain -ScriptBlock ${function:AddAcl} -ArgumentList $exc, $mas, $user, $folderonserverMain, $needacces
       Add-OutputBoxLine -Message "$Mainstate"
    }
    Else
    {
        $exc = 1
        $mas = 1
        $Mainstate = AddAcl $exc $mas $user $mainpath $needacces
        Add-OutputBoxLine -Message "$Mainstate" 
    }

    $pbrTest.Value = 40

    #[7]If the checkbox "all folders and subfolders" filled - provide recurse
    If ($checkbox -eq $true)
    {
        Add-OutputBoxLine -Message "Try to get all subfolders"

        #[7.1] on local
        If($servertestMain -and $tempa)
        {
            Add-OutputBoxLine -Message "Go to $ServerMain"

            if($checkbox2 -eq $true)
            {
                Add-OutputBoxLine -Message "Start with exclusion"
                $exc = 3
                $mas = 3
                $Mainstate = Invoke-Command -ComputerName $serverMain -ScriptBlock ${function:AddAcl} -ArgumentList $exc, $mas, $user, $folderonserverMain, $needacces, $exclusionOnServ1, $exclusionOnServ2, $exclusionOnServ3, $exclusionOnServ4
            }
            Else 
            {
                Add-OutputBoxLine -Message "Start without exclusion"
                $exc = 0
                $mas = 3
                $Mainstate = Invoke-Command -ComputerName $serverMain -ScriptBlock ${function:AddAcl} -ArgumentList $exc, $mas, $user, $folderonserverMain, $needacces
            }
            $results += $Mainstate
            Add-OutputBoxLine -Message "Access provided on local server for all folders"
        }
        Else
        {
            #[7.2] remotely
            Add-OutputBoxLine -Message "Trying to provide access remotely, using jos, please wait"
            # Add all paths to the array
            $folders = Get-ChildItem $mainpath -Recurse -Directory

            $pbrTest.Value = 60

            # Remove any old jobs
            Get-Job | Remove-Job -Force 

            # paths per one job
            if($folders.FullName.Count -lt 15 -and $checkbox2 -eq $true) 
            {
                $exc = 3
                $mas = 3
                $Mainstate = AddAcl $exc $mas $user $mainpath $needacces $exclusion1 $exclusion2 $exclusion3 $exclusion4 
                $results += $Mainstate
            }
            Elseif($folders.FullName.Count -lt 15)
            {
                $exc = 1
                $mas = 3
                $Mainstate = AddAcl $exc $mas $user $mainpath $needacces
                $results += $Mainstate
            }
            else
            {
                $pathperbatch = $folders.FullName.Count /5
                $i = 0
                $j = $pathperbatch - 1
                $batch = 1 

                Add-OutputBoxLine -Message "Starting jobs, please wait... when will be finished it promts message"
                $pbrTest.Value = 75

                #[7.2.1] Create a N count of jobs, and provide access to the folders from path array.
                While ($i -lt $folders.FullName.count)
                {
                    $pathperbatch = $folders.FullName[$i..$j]
                    $jobname = "Bath$batch"

                    if($checkbox2 -eq $true)
                    {
                        $exc = 3
                        $mas = 1
                        $state = Start-job -name $jobname -Scriptblock ${function:AddAcl} -ArgumentList $exc, $mas, $user, $pathperbatch, $needacces, $exclusion1, $exclusion2, $exclusion3, $exclusion4 | Wait-Job | Receive-Job
                    }
                    else
                    {
                        $exc = 1
                        $mas = 1
                        $state = Start-job -name $jobname -Scriptblock ${function:AddAcl} -ArgumentList $exc, $mas, $user, $pathperbatch, $needacces | Wait-Job | Receive-Job
                    }
                    $results += $state

                    $batch += 1
                    $i = $j + 1
                    $j += $pathperbatch.count

                    if($i -gt $folders.FullName.Count) {$i = $folders.FullName.Count}
                    if($j -gt $folders.FullName.Count) {$j = $folders.FullName.Count}
                }
            Get-job | Wait-Job
            }
        }
    }
    $results += $outputBox.Text
    $results | Out-File -Append "G:\Scripts\FJ-Wintel\General\Prod\ACL\log_$(get-date -f yyyy_MM_dd-HH-mm).txt" . #Change to your path for logs
    $pbrTest.Value = 100
    Add-OutputBoxLine -Message "All Jobs completed, its all, log is located in log.txt"
    $watchwork.stop()
}
Function Delete # Delete menu
{
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $formDelete = New-Object System.Windows.Forms.Form
    $formDelete.Text = 'Delete user from share'
    $formDelete.Size = New-Object System.Drawing.Size(250,140)
    $formDelete.StartPosition = 'CenterScreen'
    $formDelete.AutoSize = $true

    $LabelDelete = New-Object System.Windows.Forms.Label
    $LabelDelete.Text = "Add user Samaccountname"
    $LabelDelete.Location  = New-Object System.Drawing.Point(0,10)
    $LabelDelete.AutoSize = $true
    $formDelete.Controls.Add($LabelDelete)

    $TextBoxDelete = New-Object System.Windows.Forms.TextBox
    $TextBoxDelete.Location  = New-Object System.Drawing.Point(0,30)
    $TextBoxDelete.Text = 'SamAccountName'
    $TextBoxDelete.width = 240
    $formDelete.Controls.Add($TextBoxDelete)

    $Label2Delete = New-Object System.Windows.Forms.Label
    $Label2Delete.Text = "Put share path"
    $Label2Delete.Location  = New-Object System.Drawing.Point(0,60)
    $Label2Delete.AutoSize = $true
    $formDelete.Controls.Add($Label2Delete)

    $TextBox2Delete = New-Object System.Windows.Forms.TextBox
    $TextBox2Delete.Location  = New-Object System.Drawing.Point(0,80)
    $TextBox2Delete.Text = 'Folder Path'
    $TextBox2Delete.width = 240
    $formDelete.Controls.Add($TextBox2Delete)

    $OKButtonDelete = New-Object System.Windows.Forms.Button
    $OKButtonDelete.Location = New-Object System.Drawing.Point(10,110)
    $OKButtonDelete.Size = New-Object System.Drawing.Size(75,23)
    $OKButtonDelete.Text = 'OK'
    $OKButtonDelete.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $formDelete.AcceptButton = $OKButtonDelete
    $formDelete.Controls.Add($OKButtonDelete)

    $CancelButtonDelete = New-Object System.Windows.Forms.Button
    $CancelButtonDelete.Location = New-Object System.Drawing.Point(85,110)
    $CancelButtonDelete.AutoSize = $true
    $CancelButtonDelete.Text = 'Cancel'
    $CancelButtonDelete.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $formDelete.CancelButton = $CancelButtonDelete
    $formDelete.Controls.Add($CancelButtonDelete)

    $result = $formDelete.ShowDialog()

    $results = @()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK)
    {
        $user = $TextBoxDelete.Text
        $onserverdata = GetFolder $TextBox2Delete.Text
        $folderonserver = $onserverdata[0]
        $server = $onserverdata[1]
        $servertest = $onserverdata[2]

        If($servertest)
        {
            $mainpath =  $folderonserver
            
            Add-OutputBoxLine -Message "Connecting to $server and folder - $folderonserver"
            Add-OutputBoxLine -Message "Starting"
            $Mainstate = Invoke-Command -ComputerName $server -ScriptBlock ${function:DeleteAcl} -ArgumentList $user, $mainpath
            $results += $Mainstate
            Add-OutputBoxLine -Message "User removed from all paths, see log file G:\Scripts\FJ-Wintel\General\Prod\ACL"
            $results += $outputBox.Text
            $results | Out-File -Append "G:\Scripts\FJ-Wintel\General\Prod\ACL\logDelete_$(get-date -f yyyy_MM_dd-HH-mm).txt" .  #change to your log path

            $pbrTest.Value = 0
            $watchwork.stop()
            return
        }
        else 
        {
            $mainpath = $TextBox2Delete.Text
            Add-OutputBoxLine -Message "Server or folder on it cant be found, start do remotely"
            $Mainstate = DeleteAcl $user $mainpath
            
            $results += $Mainstate
            $results += $outputBox.Text
            $results | Out-File -Append "G:\Scripts\FJ-Wintel\General\Prod\ACL\logDelete_$(get-date -f yyyy_MM_dd-HH-mm).txt" #change to your log path
            Add-OutputBoxLine -Message "User removed from all paths, see log file G:\Scripts\FJ-Wintel\General\Prod\ACL"
            $pbrTest.Value = 0
            $watchwork.stop()
            return
        }
    }
    Else 
    {
        $pbrTest.Value = 0
        $watchwork.stop()
        return
    }
} 

$who_run_script = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

Set-Alias GCI2 Main

# Add max access level for account (launch admin console)
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{   
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Break
}

# Hide PowerShell Console
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'
$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0)

# Paint GUI
Add-Type -assembly System.Windows.Forms

$main_form = New-Object System.Windows.Forms.Form
$main_form.Text ='Add permissions to the share'
$main_form.Width = 900
$main_form.Height = 200
$main_form.AutoSize = $true

$Label = New-Object System.Windows.Forms.Label
$Label.Text = "Please fill all information and press start button"
$Label.Location  = New-Object System.Drawing.Point(0,10)
$Label.AutoSize = $true
$main_form.Controls.Add($Label)

$button = New-Object System.Windows.Forms.Button
$button.Text = 'Start'
$button.Location = New-Object System.Drawing.Point(0,30)
$button.Add_Click({ Main $TextBox.Text $TextBox2.Text $ComboBox.SelectedItem $checkbox.checked $checkbox2.checked $TextBoxexclusion1.Text $TextBoxexclusion2.Text $TextBoxexclusion3.Text $TextBoxexclusion4.Text})  # send to main, all logic there
$main_form.AcceptButton = $button
$main_form.Controls.Add($button)

$button2 = New-Object System.Windows.Forms.Button
$button2.Text = 'Delete'
$button2.Location = New-Object System.Drawing.Point(140,30)
$button2.Add_Click({ Delete })  # send to delete
$main_form.AcceptButton = $button2
$main_form.Controls.Add($button2)

$Label2 = New-Object System.Windows.Forms.Label
$Label2.Text = "Put user Samaccountname"
$Label2.Location  = New-Object System.Drawing.Point(0,60)
$Label2.AutoSize = $true
$main_form.Controls.Add($Label2)

$TextBox = New-Object System.Windows.Forms.TextBox
$TextBox.Location  = New-Object System.Drawing.Point(0,80)
$TextBox.Text = 'SamAccountName'
$TextBox.width = 240
$main_form.Controls.Add($TextBox)

$Label3 = New-Object System.Windows.Forms.Label
$Label3.Text = "Put share path"
$Label3.Location  = New-Object System.Drawing.Point(0,110)
$Label3.AutoSize = $true
$main_form.Controls.Add($Label3)

$TextBox2 = New-Object System.Windows.Forms.TextBox
$TextBox2.Location  = New-Object System.Drawing.Point(0,130)
$TextBox2.Text = 'Folder Path'
$TextBox2.width = 240
$main_form.Controls.Add($TextBox2)

$Label4 = New-Object System.Windows.Forms.Label
$Label4.Text = "Please choose needed access"
$Label4.Location  = New-Object System.Drawing.Point(0,160)
$Label4.AutoSize = $true
$main_form.Controls.Add($Label4)

$ComboBox = New-Object System.Windows.Forms.ComboBox
$ComboBox.DataSource = @('Read','Read&Write')
$ComboBox.Location  = New-Object System.Drawing.Point(0,180)
$main_form.Controls.Add($ComboBox)

$Label5 = New-Object System.Windows.Forms.Label
$Label5.Text = "Please chose needeed options"
$Label5.Location  = New-Object System.Drawing.Point(0,210)
$Label5.AutoSize = $true
$main_form.Controls.Add($Label5)

$checkbox = New-Object System.Windows.Forms.Checkbox 
$checkbox.Location = New-Object System.Drawing.Size(4,230) 
$checkbox.Size = New-Object System.Drawing.Size(200,20)
$checkbox.Text = "For all subfolders"
$main_form.Controls.Add($checkbox)

$checkbox2 = New-Object System.Windows.Forms.Checkbox 
$checkbox2.Location = New-Object System.Drawing.Size(4,250) 
$checkbox2.Size = New-Object System.Drawing.Size(200,20)
$checkbox2.Text = "Enable exclusion paths"
$main_form.Controls.Add($checkbox2)

$Labelexclusion1 = New-Object System.Windows.Forms.Label
$Labelexclusion1.Text = "Put exclusion path"
$Labelexclusion1.Location  = New-Object System.Drawing.Point(0,270)
$Labelexclusion1.AutoSize = $true
$main_form.Controls.Add($Labelexclusion1)

$TextBoxexclusion1 = New-Object System.Windows.Forms.TextBox
$TextBoxexclusion1.Location  = New-Object System.Drawing.Point(0,290)
$TextBoxexclusion1.Text = ''
$TextBoxexclusion1.width = 240
$main_form.Controls.Add($TextBoxexclusion1)

$Labelexclusion2 = New-Object System.Windows.Forms.Label
$Labelexclusion2.Text = "Put exclusion path"
$Labelexclusion2.Location  = New-Object System.Drawing.Point(0,320)
$Labelexclusion2.AutoSize = $true
$main_form.Controls.Add($Labelexclusion2)

$TextBoxexclusion2 = New-Object System.Windows.Forms.TextBox
$TextBoxexclusion2.Location  = New-Object System.Drawing.Point(0,340)
$TextBoxexclusion2.width = 240
$main_form.Controls.Add($TextBoxexclusion2)

$Labelexclusion3 = New-Object System.Windows.Forms.Label
$Labelexclusion3.Text = "Put exclusion path"
$Labelexclusion3.Location  = New-Object System.Drawing.Point(0,370)
$Labelexclusion3.AutoSize = $true
$main_form.Controls.Add($Labelexclusion3)

$TextBoxexclusion3 = New-Object System.Windows.Forms.TextBox
$TextBoxexclusion3.Location  = New-Object System.Drawing.Point(0,390)
$TextBoxexclusion3.width = 240
$main_form.Controls.Add($TextBoxexclusion3)

$Labelexclusion4 = New-Object System.Windows.Forms.Label
$Labelexclusion4.Text = "Put exclusion path"
$Labelexclusion4.Location  = New-Object System.Drawing.Point(0,420)
$Labelexclusion4.AutoSize = $true
$main_form.Controls.Add($Labelexclusion4)

$TextBoxexclusion4 = New-Object System.Windows.Forms.TextBox
$TextBoxexclusion4.Location  = New-Object System.Drawing.Point(0,440)
$TextBoxexclusion4.width = 240
$main_form.Controls.Add($TextBoxexclusion4)

$outputBox = New-Object System.Windows.Forms.TextBox 
$outputBox.Location = New-Object System.Drawing.Size(250,0) 
$outputBox.Size = New-Object System.Drawing.Size(700,440) 
$outputBox.MultiLine = $True 
$outputBox.ScrollBars = "Vertical"
$main_form.Controls.Add($outputBox)

# Init ProgressBar
$pbrTest = New-Object System.Windows.Forms.ProgressBar
$pbrTest.Maximum = 100
$pbrTest.Minimum = 0
$pbrTest.Location = new-object System.Drawing.Size(0,470)
$pbrTest.size = new-object System.Drawing.Size(950,30)
$main_form.Controls.Add($pbrTest)

$watchtotal = [diagnostics.stopwatch]::StartNew()
$watchwork = [diagnostics.stopwatch]::StartNew()
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({$Label6.Text = $("Total $($watchtotal.Elapsed.Minutes)m $($watchtotal.Elapsed.Seconds)s Work $($watchwork.Elapsed.Minutes)m $($watchwork.Elapsed.Seconds)s ")})
$timer.Enabled = $True
$Label6 = New-Object System.Windows.Forms.Label
$Label6.Text = "Time when working"
$Label6.Location  = New-Object System.Drawing.Point(0,500)
$Label6.AutoSize = $True
$main_form.Controls.Add($Label6)

$main_form.ShowDialog()