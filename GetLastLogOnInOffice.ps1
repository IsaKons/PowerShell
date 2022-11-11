$users = Get-ADUser -filter {office -like ""}
$Final = @()
foreach ($user in $users)
    {
        $MainUser = Get-ADUser $user.SamAccountName -properties DisplayName, LastLogonDate|select DisplayName, LastLogonDate
        $final += $MainUser
    }
$final