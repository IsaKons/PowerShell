$VerbosePreference = 'Continue'
$folder = "PATH"
$users = Get-ChildItem $folder -directory
ForEach($user in $users) {
    Write-Verbose $user.FullName
    takeown /f $user.FullName /a /r /d y
}