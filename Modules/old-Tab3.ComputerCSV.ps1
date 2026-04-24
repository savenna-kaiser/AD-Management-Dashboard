function Initialize-Tab3 {
    param($Grid)

    $inactiveComputersGrid = $mainWindow.FindName("InactiveComputersGrid")
    $btnDisableComputers = $mainWindow.FindName("BtnDisableComputers")

    function Load-CompCSV {
        try {
            $csvPath = "\\epn1fs2.eppingen.bw-online.de\home\800236\Downloads\inactive_computers_*.csv"
            $file = Get-ChildItem -Path $csvPath | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($file) {
                $computers = Import-Csv $file.FullName
                $inactiveComputersGrid.ItemsSource = $computers
            }
        } catch {
            $statusText.Text = "Fehler beim Laden der CSV: $_"
        }
    }

    Load-CompCSV

    $btnDisableComputers.Add_Click({
        $selectedItems = $inactiveComputersGrid.SelectedItems
        Invoke-ADAction -Action {
            foreach ($item in $selectedItems) {
                $sam = $item.SamAccountName
                Disable-ADAccount -Identity $sam -Credential $global:ADCredential
                Move-ADObject -Identity (Get-ADComputer -Identity $sam -Credential $global:ADCredential).DistinguishedName `
                              -TargetPath "OU=Computers,OU=_Inactive,DC=epn1dc1,DC=eppingen,DC=bw-online,DC=de" `
                              -Credential $global:ADCredential
            }
        } -SuccessMessage "Computer deaktiviert & verschoben" -ErrorMessage "Fehler beim Deaktivieren"
        Load-CompCSV
    })
}

Initialize-Tab3 -Grid $mainWindow.FindName("Tab3Grid")
