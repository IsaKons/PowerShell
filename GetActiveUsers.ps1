$arrayOU = (
            "")
$AllUsers = @()

foreach ($OU in $arrayOU)
    {
        $DNOU = Get-ADOrganizationalUnit -LDAPFilter "(name=*)" -Properties * -SearchScope Subtree -SearchBase "" | `
                Where {$_.CanonicalName -Match $OU} | `
                Select-Object distinguishedName
                
        $users = Get-ADUser -LDAPFilter "(&(objectCategory=person)(objectClass=user))" `
                            -Properties distinguishedName, displayName, SamAccountName, Enabled `
                            -SearchScope Subtree `
                            -SearchBase $DNOU.distinguishedName
        
        $AllUsers += $users
}

$AllUsers | Select-Object distinguishedName, displayName, SamAccountName, Enabled | Export-Csv users.csv 