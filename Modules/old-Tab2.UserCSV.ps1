function Initialize-Tab2 {
    param($Grid)

    $inactiveUsersGrid = $mainWindow.FindName("InactiveUsersGrid")
    $btnDisableUsers = $mainWindow.FindName("BtnDisableUsers")

    function Load-UserCSV {
        try {
            $csvPath = "\\epn1fs2.eppingen.bw-online.de\home\800236\Downloads\inactive_users_*.csv"
            $file = Get-ChildItem -Path $csvPath | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($file) {
                $users = Import-Csv $file.FullName
                $inactiveUsersGrid.ItemsSource = $users
            }
        } catch {
            $statusText.Text = "Fehler beim Laden der CSV: $_"
        }
    }

    Load-UserCSV

    $btnDisableUsers.Add_Click({
        $selectedItems = $inactiveUsersGrid.SelectedItems
        Invoke-ADAction -Action {
            foreach ($item in $selectedItems) {
                $sam = $item.SamAccountName
                Disable-ADAccount -Identity $sam -Credential $global:ADCredential
                Move-ADObject -Identity (Get-ADUser -Identity $sam -Credential $global:ADCredential).DistinguishedName `
                              -TargetPath "OU=Users,OU=_Inactive,DC=epn1dc1,DC=eppingen,DC=bw-online,DC=de" `
                              -Credential $global:ADCredential
            }
        } -SuccessMessage "Benutzer deaktiviert & verschoben" -ErrorMessage "Fehler beim Deaktivieren"
        Load-UserCSV
    })
}

Initialize-Tab2 -Grid $mainWindow.FindName("Tab2Grid")
