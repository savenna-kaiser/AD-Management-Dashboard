# =========================================
# Tab1.Feature_TeamViewer.ps1
# TeamViewer-Integration (lokal starten)
# =========================================

function Initialize-TeamviewerButton {
    param(
        [Parameter(Mandatory=$true)] [System.Windows.Controls.Button] $Btn,
        [Parameter(Mandatory=$true)] [System.Windows.Controls.ListBox] $ComputerListBox,
        [pscredential] $Credential = $null
    )

    # Event: Button-Klick
    $Btn.Add_Click({
        # Ausgewählten Computer ermitteln
        $selectedComputer = $ComputerListBox.SelectedItem
        if (-not $selectedComputer) {
            [System.Windows.MessageBox]::Show("Bitte zuerst einen Computer ausw\u00E4hlen.")
            return
        }

        # Optionales Credential verwenden, falls gesetzt
        $cred = $Credential
        if (-not $cred) { $cred = $Global:AdminCredential }

        # Pfad zu TeamViewer (lokal, 32-Bit)
        $teamviewerPath = "C:\Program Files (x86)\TeamViewer\TeamViewer.exe"

        if (-not (Test-Path $teamviewerPath)) {
            [System.Windows.MessageBox]::Show("TeamViewer.exe wurde nicht gefunden: $teamviewerPath")
            return
        }

        try {
            # TeamViewer starten (nur lokal)
            Start-Process -FilePath $teamviewerPath
            [System.Windows.MessageBox]::Show("TeamViewer gestartet f$([char]0xFC)r $($selectedComputer.Name).")
        } catch {
            [System.Windows.MessageBox]::Show("Fehler beim Starten von TeamViewer:`n$($_.Exception.Message)")
        }
    })
}