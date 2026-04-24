# =========================================
# Main.ps1 AD Manager (stabil, schlank, TeamViewer)
# =========================================

Add-Type -AssemblyName PresentationFramework
Import-Module ActiveDirectory -ErrorAction Stop

# ----------------- Module laden -----------------
. "$PSScriptRoot\Modules\Tab1.Feature_TeamViewer.ps1"
. "$PSScriptRoot\Dialogs\GroupSelectionDialog.ps1"
. "$PSScriptRoot\Modules\Tab1.AD-Management.ps1"

# ----------------- GUI laden -----------------
$xamlText = Get-Content "$PSScriptRoot\GUI.xaml" -Raw -Encoding UTF8
$reader = New-Object System.IO.StringReader $xamlText
$xmlReader = [System.Xml.XmlReader]::Create($reader)
$mainWindow = [Windows.Markup.XamlReader]::Load($xmlReader)

# ----------------- Globale Variablen -----------------
$Global:AdminCredential = $null
$dc = "CORP1DC1.contoso.local"
$OUList = Get-OUList  # Hole OU-Liste aus Tab1.AD-Management.ps1

# ----------------- Status-Funktion -----------------
function Show-Status { param([string]$Text) $mainWindow.FindName("StatusText").Text = $Text }

# ========================
# Login-Button
# ========================
$btnLogin = $mainWindow.FindName("btnLogin")
$txtUser  = $mainWindow.FindName("txtUser")
$txtPass  = $mainWindow.FindName("txtPass")
$LoginPanel = $mainWindow.FindName("LoginPanel")
$MainGrid   = $mainWindow.FindName("MainGrid")

$btnLogin.Add_Click({
    if ([string]::IsNullOrWhiteSpace($txtUser.Text) -or [string]::IsNullOrWhiteSpace($txtPass.Password)) {
        [System.Windows.MessageBox]::Show("Bitte Benutzername und Passwort eingeben.")
        return
    }
    try {
        $userInput = $txtUser.Text
        if ($userInput -notmatch "^[^\\]+\\[^\\]+$") { $userInput = "CONTOSO\$userInput" }

        $Global:AdminCredential = New-Object PSCredential (
            $userInput,
            (ConvertTo-SecureString $txtPass.Password -AsPlainText -Force)
        )

        # Test-Login
        Get-ADDomain -Server $dc -Credential $Global:AdminCredential -ErrorAction Stop | Out-Null

        $LoginPanel.Visibility = "Collapsed"
        $MainGrid.Visibility  = "Visible"
        Show-Status "Angemeldet als $userInput"

        # Tab1 initialisieren (alle Controls, Events & AD-Funktionen werden vom Modul gesetzt)
        Initialize-Tab1 -Window $mainWindow -Credential $Global:AdminCredential
	LoadAllGroups

    } catch {
        [System.Windows.MessageBox]::Show("Login fehlgeschlagen:`n$($_.Exception.Message)")
        $Global:AdminCredential = $null
    }
})

# ----------------- ENTER-Taste Login -----------------
foreach ($txt in @($txtUser,$txtPass)) {
    $txt.Add_KeyDown({
        if ($_.Key -eq "Enter") {
            $btnLogin.RaiseEvent(
                [System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)
            )
        }
    })
}

# ----------------- Fenster anzeigen -----------------
$mainWindow.ShowDialog() | Out-Null