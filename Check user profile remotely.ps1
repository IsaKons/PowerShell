#List of Navision`s servers
$servers = Get-ADComputer -LDAPFilter "" -SearchBase "" | select "Name"

$users = ''
foreach($user in $users){
    $sid=(Get-ADUser $User).SID.Value #get SID of user
    Write-output $user $sid
    foreach($serverx in $servers){
        $server=$serverx.Name 
        $server
        $qusers= quser /server:$server #retrieving Remote Desktop sessions
        foreach($quser in $qusers){
            if(  $quser.Contains($user.ToLower())) {
                            $quser.Substring(46,6) +� session�
            }
        }
        try{
            #Get user`s profile
            $profile=Get-WmiObject -ComputerName $server -Class win32_userprofile -Filter "SID='$sid'" 
            Write-Output "Finded" 
        }
        catch{
            Write-Output "Not finded"
        }

    }

}
