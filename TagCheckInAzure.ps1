Connect-AzAccount

$allsubs = Get-AzSubscription
$report = [System.Collections.ArrayList]::new()
$tags = [System.Collections.ArrayList]::new()
foreach ($allsub in $allsubs) {
    "$($allsub.name) is being checked"
    $allsub | Select-AzSubscription
    $rsgroups = $null
    $rsgroups = Get-AzResourceGroup
    foreach ($rsgroup in $rsgroups) {     
        $tg = (Get-AzTag -ResourceId $rsgroup.ResourceId).Properties.TagsProperty
        $tg = $tg.keys | % { $_ }
        for ($in = 0; $in -le $tg.Count - 1; $in ++) {
            $objecttag = New-Object psobject
            $objecttag | Add-Member -MemberType NoteProperty -Name "tags" -Value $tg[$in]
            $tags.Add($objecttag)
        }
    }
}
$uniquetags = $tags.tags | select -Unique 
foreach ($allsub in $allsubs) {
    "$($allsub.name) is being checked"
    $rsgroups = Get-AzResourceGroup
    $object = New-Object psobject
    $object | Add-Member -MemberType NoteProperty -Name "Sub" -Value $allsub.name
    foreach ($rsgroup in $rsgroups) {
        $object | Add-Member -MemberType NoteProperty -Name "RSGroup" -Value $rsgroup.ResourceGroupName  
        $tgrp = (Get-AzTag -ResourceId $rsgroup.ResourceId).Properties.TagsProperty 
        for ($in = 0; $in -le $uniquetags.Count - 1; $in ++) {
            $intag = $uniquetags[$in]
            if ($tgrp.$($intag) -ne $null) { $object | Add-Member -MemberType NoteProperty -Name "$intag" -Value $($tgrp.$($intag)) }
            else { $object | Add-Member -MemberType NoteProperty -Name "$intag" -Value "not set" }  
            $report.Add($object)           
        }
    }
}