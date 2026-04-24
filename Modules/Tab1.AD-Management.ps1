# ========================= 
# AD-Manager Tab1 – FINAL + Gruppenverwaltung (Optimiert)
# =========================

Add-Type -AssemblyName PresentationFramework
Import-Module ActiveDirectory -ErrorAction Stop

# ------------------------
# Logging (UTF8 ohne BOM)
# ------------------------
$global:LogFile = Join-Path $env:TEMP "AD-Tool.log"

function Log-Write {
    param([string]$Text)
    $sw = [System.IO.StreamWriter]::new($global:LogFile, $true, [System.Text.Encoding]::UTF8)
    $sw.WriteLine("$((Get-Date -Format 's')) `t $Text")
    $sw.Close()
}

Remove-Item $global:LogFile -ErrorAction SilentlyContinue
Log-Write "AD Manager Dashboard gestartet"

# ------------------------
# XAML laden
# ------------------------
$ScriptPath = Split-Path -Parent $PSCommandPath
$xamlPath   = Join-Path $ScriptPath "..\GUI.xaml"
if (-not (Test-Path $xamlPath)) { throw "GUI.xaml fehlt" }

[xml]$xamlXML = Get-Content $xamlPath -Raw -Encoding UTF8
$reader = New-Object System.Xml.XmlNodeReader $xamlXML
$window = [Windows.Markup.XamlReader]::Load($reader)

# ------------------------
# Globale Variablen
# ------------------------
$Global:AdminCredential = $null
$Global:SessionCache   = $null
$Global:OriginalOUCache = @{}
$dc = "CORP1DC1.contoso.local"

$sessionsCSVPath = "\\CORP1FS1.contoso.local\Tsdata\Sessions.csv"
$tempSessionFile = Join-Path $env:TEMP "Sessions-local.csv"

function Get-OUList {
    return @(
    "OU=CORP-AD,DC=contoso,DC=local",
    "OU=CORP-BUE,DC=contoso,DC=local",
    "OU=CORP-EL,DC=contoso,DC=local",
    "OU=CORP-KL,DC=contoso,DC=local",
    "OU=CORP-MU,DC=contoso,DC=local",
    "OU=CORP-RI,DC=contoso,DC=local",
    "OU=CORP-RO,DC=contoso,DC=local",
    "OU=CORP-RT,DC=contoso,DC=local",
    "OU=COMPUTER,DC=contoso,DC=local",
    "OU=Users,OU=_Inactive,DC=contoso,DC=local",
    "OU=Computers,OU=_Inactive,DC=contoso,DC=local"
)
}
$OUList = Get-OUList

# ========================
# Initialize-Tab1 Funktion
# ========================
function Initialize-Tab1 {
    param(
        [Windows.Window]$Window,
        [pscredential]$Credential = $null
    )

    # ------------------------
    # Controls
    # ------------------------
    $Global:LoginPanel        = $Window.FindName("LoginPanel")
    $Global:MainGrid          = $Window.FindName("MainGrid")
    $Global:txtUser           = $Window.FindName("txtUser")
    $Global:txtPass           = $Window.FindName("txtPass")
    $Global:btnLogin          = $Window.FindName("btnLogin")
    $Global:UserSearchBox     = $Window.FindName("UserSearchBox")
    $Global:BtnUserSearch     = $Window.FindName("BtnUserSearch")
    $Global:UserListBox       = $Window.FindName("UserListBox")
    $Global:lstGroups         = $Window.FindName("GroupListBox")
    $Global:BtnAddGroup       = $Window.FindName("BtnAddGroup")
    $Global:BtnRemoveGroup    = $Window.FindName("BtnRemoveGroup")
    $Global:ComputerSearchBox = $Window.FindName("ComputerSearchBox")
    $Global:BtnComputerSearch = $Window.FindName("BtnComputerSearch")
    $Global:ComputerListBox   = $Window.FindName("ComputerListBox")
    $Global:BtnUnlock         = $Window.FindName("BtnUnlock")
    $Global:BtnEnable         = $Window.FindName("BtnEnable")
    $Global:BtnDisable        = $Window.FindName("BtnDisable")
    $Global:BtnResetPwd       = $Window.FindName("BtnResetPwd")
    $Global:dgSessions        = $Window.FindName("dgSessions")
    $Global:StatusText        = $Window.FindName("StatusText")

    # ------------------------
    # TeamViewer-Button holen + initialisieren
    # ------------------------
    $Global:BtnTeamviewer = $Window.FindName("BtnTeamviewer")

    if (-not $Global:BtnTeamviewer) {
    Write-Warning "TeamViewer-Button nicht gefunden!"
    }
    else {
    # Initialisieren, Credential optional
    # Wenn $Global:AdminCredential noch null ist, funktioniert der Button trotzdem für lokalen Start
    try {
        Initialize-TeamviewerButton `
            -Btn $Global:BtnTeamviewer `
            -ComputerListBox $Global:ComputerListBox `
            -Credential $Global:AdminCredential
    } catch {
        Write-Warning "TeamViewer-Button konnte nicht initialisiert werden: $_"
    	}
    }

    # ------------------------
    # Button: Benutzer anpassen (Popup)
    # ------------------------
    $Global:BtnEditUser = $Window.FindName("BtnEditUser")

    if (-not $Global:BtnEditUser) {
        Write-Warning "BtnEditUser nicht gefunden!"
    } else {

    # Button zunächst deaktivieren
    $Global:BtnEditUser.IsEnabled = $false

    # Aktivierung abhängig von der Auswahl im UserListBox
    $Global:UserListBox.Add_SelectionChanged({
        if ($Global:UserListBox.SelectedItem) {
            $Global:BtnEditUser.IsEnabled = $true
        } else {
            $Global:BtnEditUser.IsEnabled = $false
        }
    })

    # Klick-Event: Popup öffnen
    $Global:BtnEditUser.Add_Click({
        $selectedUser = $Global:UserListBox.SelectedItem

        if (-not $selectedUser) {
            [System.Windows.MessageBox]::Show("Bitte zuerst einen Benutzer auswählen.")
            return
        }

        # Popup-Skript laden & starten, ohne absoluten Pfad
        $popupPath = Join-Path $PSScriptRoot "Tab1.Feature_EditUser.ps1"
        & $popupPath -ParentWindow $Window -SelectedUser $selectedUser
    })
}

    # ------------------------
    # Citrix-Logoff Button
    # ------------------------
    $Global:BtnCitrixLogoff = $Window.FindName("BtnCitrixLogoff")

    if (-not $Global:BtnCitrixLogoff) {
        Write-Warning "BtnCitrixLogoff nicht gefunden!"
    } else {
        $Global:BtnCitrixLogoff.IsEnabled = $false

        $Global:dgSessions.Add_SelectionChanged({
            $Global:BtnCitrixLogoff.IsEnabled = ($Global:dgSessions.SelectedItem -ne $null)
        })

        $Global:BtnCitrixLogoff.Add_Click({
            $selectedSession = $Global:dgSessions.SelectedItem
            if (-not $selectedSession) {
                [System.Windows.MessageBox]::Show("Bitte zuerst eine Session auswählen.")
                return
            }
            $citrixPath = Join-Path $PSScriptRoot "Tab1.Feature_CitrixLogoff.ps1"
            . $citrixPath -SelectedSession $selectedSession -ParentWindow $Window -Credential $Global:AdminCredential
        })
    }

    # ------------------------
    # Null-Check Controls
    # ------------------------
    $essentialControls = @{
        LoginPanel        = $Global:LoginPanel
        MainGrid          = $Global:MainGrid
        txtUser           = $Global:txtUser
        txtPass           = $Global:txtPass
        btnLogin          = $Global:btnLogin
        UserListBox       = $Global:UserListBox
        lstGroups         = $Global:lstGroups
        BtnAddGroup       = $Global:BtnAddGroup
        BtnRemoveGroup    = $Global:BtnRemoveGroup
        BtnUnlock         = $Global:BtnUnlock
        BtnEnable         = $Global:BtnEnable
        BtnDisable        = $Global:BtnDisable
        BtnResetPwd       = $Global:BtnResetPwd
        UserSearchBox     = $Global:UserSearchBox
        BtnUserSearch     = $Global:BtnUserSearch
        ComputerSearchBox = $Global:ComputerSearchBox
        BtnComputerSearch = $Global:BtnComputerSearch
        ComputerListBox   = $Global:ComputerListBox
        dgSessions        = $Global:dgSessions
        StatusText        = $Global:StatusText
	BtnEditUser       = $Global:BtnEditUser
	BtnCitrixLogoff   = $Global:BtnCitrixLogoff

    }
    $missing = $essentialControls.GetEnumerator() | Where-Object { -not $_.Value }
    if ($missing.Count -gt 0) {
        $msg = "FEHLER: Folgende Controls nicht gefunden:`n" + ($missing | ForEach-Object { $_.Key }) -join "`n"
        [System.Windows.MessageBox]::Show($msg)
        return $false
    }

    # ------------------------
    # Listen initial leer setzen
    # ------------------------
    $Global:UserListBox.ItemsSource     = @()
    $Global:ComputerListBox.ItemsSource = @()
    $Global:lstGroups.ItemsSource       = @()
    $Global:dgSessions.ItemsSource      = @()

    # ------------------------
    # Buttons initial deaktivieren – nur die, die von Auswahl abhängen
    # ------------------------
foreach ($btn in @($Global:BtnUnlock, $Global:BtnEnable, $Global:BtnDisable, $Global:BtnResetPwd)) {
    if ($btn -and $btn -is [System.Windows.Controls.Button]) {
        $btn.IsEnabled = $false
    }
}

# Gruppen-Buttons standardmäßig aktiv lassen
$Global:BtnAddGroup.IsEnabled = $true
$Global:BtnRemoveGroup.IsEnabled = $true


    Show-Status "AD-Manager Dashboard bereit."
    Log-Write "Tab1 vollständig initialisiert."
}

# ------------------------
# Hilfsfunktionen
# ------------------------
function Show-Status { param([string]$Text) $StatusText.Text = $Text; Log-Write $Text }

function UpdateSessionDisplay {
    $dgSessions.ItemsSource = $null
    if (-not $Global:SessionCache) { return }

    if ($UserListBox.SelectedItem) {
        $sam = $UserListBox.SelectedItem.SamAccountName
        $sessions = @($Global:SessionCache | Where-Object { $_.UserFullName -eq $sam })
        $dgSessions.ItemsSource = $sessions
    }
    elseif ($ComputerListBox.SelectedItem) {
        $comp = $ComputerListBox.SelectedItem.Name
        $sessions = @($Global:SessionCache | Where-Object { $_.ClientName -eq $comp })
        $dgSessions.ItemsSource = $sessions
    }
}

function UpdateUserButtons {
    $user = $UserListBox.SelectedItem
    $comp = $ComputerListBox.SelectedItem

    # ----------------------
    # Standard: alle abhängig von Auswahl deaktivieren
    # ----------------------
    $BtnUnlock.IsEnabled   = $false
    $BtnEnable.IsEnabled   = $false
    $BtnDisable.IsEnabled  = $false
    $BtnResetPwd.IsEnabled = $false
    $Global:BtnTeamviewer.IsEnabled = $false  # TeamViewer standardmäßig deaktiviert

    # ----------------------
    # Buttons abhängig von Benutzer aktivieren
    # ----------------------
    if ($user) {
        $BtnUnlock.IsEnabled  = $true
        if ($user.Enabled) {
            $BtnDisable.IsEnabled  = $true
            $BtnResetPwd.IsEnabled = $true
        } else {
            $BtnEnable.IsEnabled   = $true
        }
    }

    # ----------------------
    # TeamViewer abhängig von Computer aktivieren
    # ----------------------
    if ($comp) {
        $Global:BtnTeamviewer.IsEnabled = $true

        # Optional: Enable/Disable Buttons für Computer
        if ($comp.Enabled) {
            $BtnDisable.IsEnabled = $true
        } else {
            $BtnEnable.IsEnabled  = $true
        }
    }
}

# ========================
# Initialisierung aufrufen
# ========================
Initialize-Tab1 -Window $window

# ------------------------
# Benutzer suchen
# ------------------------
function SearchUser {
    $UserListBox.ItemsSource = @()
    if (-not $UserSearchBox.Text) {
        Show-Status "Bitte Suchbegriff eingeben."
        return
    }

    $searchText = $UserSearchBox.Text
    $allUsers = @()

    foreach ($ou in $OUList) {
        try {
            # LDAP-Filter: sAMAccountName oder DisplayName enthält Suchtext
            $users = Get-ADUser -LDAPFilter "(|(sAMAccountName=*$searchText*)(displayName=*$searchText*))" `
                                 -SearchBase $ou -SearchScope Subtree `
                                 -Properties DisplayName, Enabled `
                                 -Server $dc -Credential $Global:AdminCredential

	foreach ($u in $users) {
    	# Sicherstellen, dass $u.Enabled nie $null ist
    	$status = if ($u.Enabled -eq $true) { "aktiv" } else { "deaktiviert" }

    $u | Add-Member -NotePropertyName DisplayText -NotePropertyValue "$($u.DisplayName) ($($u.SamAccountName)) ($status)" -Force
}


            $allUsers += $users
        } catch {
            Log-Write "Fehler Benutzer OU $ou : $_"
        }
    }

    $UserListBox.DisplayMemberPath = "DisplayText"
    $UserListBox.SelectedValuePath  = "SamAccountName"
    $UserListBox.ItemsSource = $allUsers
    Show-Status "$($allUsers.Count) Benutzer gefunden."
    UpdateUserButtons
}


# ------------------------
# Computer suchen
# ------------------------
function SearchComputer {
    $ComputerListBox.ItemsSource = @()
    if (-not $ComputerSearchBox.Text) { Show-Status "Bitte Suchbegriff eingeben."; return }

    $searchText = $ComputerSearchBox.Text
    $allComputers = @()

    foreach ($ou in $OUList) {
        try {
            # AD-Filter: Computer mit Name enthält Suchtext, unabhängig vom Enabled-Status
            $computers = Get-ADComputer -LDAPFilter "(name=*$searchText*)" `
                         -SearchBase $ou -SearchScope Subtree `
                         -Properties Enabled `
                         -Server $dc -Credential $Global:AdminCredential
            foreach ($c in $computers) {
                $status = if ($c.Enabled) { "aktiv" } else { "deaktiviert" }
                $c | Add-Member -NotePropertyName DisplayText -NotePropertyValue "$($c.Name) ($status)" -Force
            }
            $allComputers += $computers
        } catch { Log-Write "Fehler Computer OU $ou : $_" }
    }

    $ComputerListBox.DisplayMemberPath = "DisplayText"
    $ComputerListBox.SelectedValuePath  = "Name"
    $ComputerListBox.ItemsSource = $allComputers
    Show-Status "$($allComputers.Count) Computer gefunden."
    UpdateUserButtons
}

# ------------------------
# Session laden – nur einmal
# ------------------------
if (Test-Path $sessionsCSVPath) {
    Copy-Item $sessionsCSVPath $tempSessionFile -Force
    $Global:SessionCache = Import-Csv $tempSessionFile -Delimiter "`t" -Encoding UTF8
} else { $Global:SessionCache = @() }

# ------------------------
# Deaktivieren & Verschieben
# ------------------------
$BtnDisable.Add_Click({
    try {
        # ===== Auswahl prüfen =====
        $selectedUser = $UserListBox.SelectedItem
        $selectedComputer = $ComputerListBox.SelectedItem

        if (-not $selectedUser -and -not $selectedComputer) {
            [System.Windows.MessageBox]::Show("Bitte zuerst einen Benutzer oder Computer auswählen.")
            return
        }

# ===== Benutzer =====
if ($selectedUser) {
    # Frisch aus AD holen
    $u = Get-ADUser -Identity $selectedUser.SamAccountName `
         -Properties DistinguishedName,Enabled `
         -Server $dc -Credential $Global:AdminCredential -ErrorAction Stop

    if (-not $u) { throw "Benutzer '$($selectedUser.SamAccountName)' nicht gefunden." }

    # Schutz aufheben
    Set-ADObject -Identity $u.DistinguishedName -ProtectedFromAccidentalDeletion $false `
                 -Server $dc -Credential $Global:AdminCredential -ErrorAction Stop

    # Benutzer deaktivieren **vor der Verschiebung**
    if ($u.Enabled) { Disable-ADAccount -Identity $u -Server $dc -Credential $Global:AdminCredential -ErrorAction Stop }

    # Ursprüngliche OU speichern (für späteres Reaktivieren)
    $Global:OriginalOUCache[$u.SamAccountName] = $u.DistinguishedName -replace '^CN=[^,]+,', ''

    # Ziel-OU definieren
    $targetOU = "OU=Users,OU=_Inactive,DC=contoso,DC=local"

    # Objekt verschieben
    Move-ADObject -Identity $u.DistinguishedName -TargetPath $targetOU `
                  -Server $dc -Credential $Global:AdminCredential -ErrorAction Stop

    # UI aktualisieren
    $selectedUser.Enabled = $false
    Show-Status "Benutzer '$($u.SamAccountName)' deaktiviert & verschoben."
    Log-Write "User disabled & moved: $($u.SamAccountName) -> $targetOU"
}

# ===== Computer =====
if ($selectedComputer) {
    $c = Get-ADComputer -Identity $selectedComputer.Name `
         -Properties DistinguishedName,Enabled `
         -Server $dc -Credential $Global:AdminCredential -ErrorAction Stop

    if (-not $c) { throw "Computer '$($selectedComputer.Name)' nicht gefunden." }

    Set-ADObject -Identity $c.DistinguishedName -ProtectedFromAccidentalDeletion $false `
                 -Server $dc -Credential $Global:AdminCredential -ErrorAction Stop

    if ($c.Enabled) { Disable-ADAccount -Identity $c -Server $dc -Credential $Global:AdminCredential -ErrorAction Stop }

    # Ursprüngliche OU speichern (für späteres Reaktivieren)
    $Global:OriginalOUCache[$c.Name] = $c.DistinguishedName -replace '^CN=[^,]+,', ''

    $targetOU = "OU=Computers,OU=_Inactive,DC=contoso,DC=local"

    Move-ADObject -Identity $c.DistinguishedName -TargetPath $targetOU `
                  -Server $dc -Credential $Global:AdminCredential -ErrorAction Stop

    $selectedComputer.Enabled = $false
    Show-Status "Computer '$($c.Name)' deaktiviert & verschoben."
    Log-Write "Computer disabled & moved: $($c.Name) -> $targetOU"
}


        # Buttons aktualisieren
        UpdateUserButtons
    }
    catch {
        [System.Windows.MessageBox]::Show(
            "Fehler beim Deaktivieren & Verschieben:`n$($_.Exception.Message)",
            "AD-Manager Fehler",
            "OK",
            "Error"
        )
        Log-Write "Disable & Move error: $($_.Exception.Message)"
    }
})

# ------------------------
# Aktivieren & Zurückverschieben
# ------------------------
$BtnEnable.Add_Click({
    try {
        if ($UserListBox.SelectedItem) {
            $u = Get-ADUser -Identity $UserListBox.SelectedItem.SamAccountName `
                 -Properties DistinguishedName `
                 -Server $dc -Credential $Global:AdminCredential -ErrorAction Stop
            Enable-ADAccount $u -Server $dc -Credential $Global:AdminCredential
            $targetOU = $Global:OriginalOUCache[$UserListBox.SelectedItem.SamAccountName]
            if (-not $targetOU) { $targetOU = "OU=CORP-RT,DC=contoso,DC=local" }
            Move-ADObject $u.DistinguishedName -TargetPath $targetOU -Server $dc -Credential $Global:AdminCredential
            Show-Status "User aktiviert und verschoben nach $targetOU"
        }
        elseif ($ComputerListBox.SelectedItem) {
            $c = Get-ADComputer -Identity $ComputerListBox.SelectedItem.Name `
                 -Properties DistinguishedName `
                 -Server $dc -Credential $Global:AdminCredential -ErrorAction Stop
            Enable-ADAccount $c -Server $dc -Credential $Global:AdminCredential
            $targetOU = $Global:OriginalOUCache[$ComputerListBox.SelectedItem.Name]
            if (-not $targetOU) { $targetOU = "OU=Windows_10_CORP,OU=COMPUTER,DC=contoso,DC=local" }
            Move-ADObject $c.DistinguishedName -TargetPath $targetOU -Server $dc -Credential $Global:AdminCredential
            Show-Status "Computer aktiviert und verschoben nach $targetOU"
        }
    }
    catch { [System.Windows.MessageBox]::Show($_.Exception.Message) }
})

# ------------------------
# Passwort zurücksetzen
# ------------------------
$BtnResetPwd.Add_Click({
    $user = $UserListBox.SelectedItem
    if (-not $user) { return }

    $pwdWindow = New-Object System.Windows.Window
    $pwdWindow.Title = "Kennwort zur\u00E4cksetzen"
    $pwdWindow.SizeToContent = "WidthAndHeight"
    $pwdWindow.WindowStartupLocation = "CenterOwner"
    $pwdWindow.Owner = $window

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Margin = "10"

    $lblPwd = New-Object System.Windows.Controls.TextBlock
    $lblPwd.Text = "Neues Passwort (Klartext):"
    $stack.Children.Add($lblPwd)

    $txtPwd = New-Object System.Windows.Controls.TextBox
    $txtPwd.Width = 220
    $stack.Children.Add($txtPwd)

    $chkMustChange = New-Object System.Windows.Controls.CheckBox
    $chkMustChange.Content = "Passwort bei n$([char]0xE4)chster Anmeldung $([char]0xE4)ndern"
    $chkMustChange.Margin = "0,10,0,0"
    $stack.Children.Add($chkMustChange)

    $chkCannotChange = New-Object System.Windows.Controls.CheckBox
    $chkCannotChange.Content = "Benutzer darf Passwort nicht $([char]0xE4)ndern"
    $stack.Children.Add($chkCannotChange)

    $btnOK = New-Object System.Windows.Controls.Button
    $btnOK.Content = "OK"
    $btnOK.Width = 80
    $btnOK.Margin = "0,10,0,0"

    $btnOK.Add_Click({
        if (-not $txtPwd.Text) {
            [System.Windows.MessageBox]::Show("Bitte Passwort eingeben.")
            return
        }
        try {
            $sam = $user.SamAccountName
            Set-ADAccountPassword -Identity $sam -Reset -NewPassword (ConvertTo-SecureString $txtPwd.Text -AsPlainText -Force) -Server $dc -Credential $Global:AdminCredential -ErrorAction Stop
            Set-ADUser -Identity $sam -ChangePasswordAtLogon $chkMustChange.IsChecked -CannotChangePassword $chkCannotChange.IsChecked -Server $dc -Credential $Global:AdminCredential
            [System.Windows.MessageBox]::Show("Kennwort erfolgreich zur$([char]0xFC)ckgesetzt.")
            Log-Write "Password reset for $sam"
            $pwdWindow.Close()
        } catch {
            [System.Windows.MessageBox]::Show("Fehler beim Passwort-Reset:`n$($_.Exception.Message)")
            Log-Write "Password reset error: $($_.Exception.Message)"
        }
    })

    $stack.Children.Add($btnOK)
    $pwdWindow.Content = $stack
    $pwdWindow.ShowDialog() | Out-Null
})

# ------------------------
# Gruppenverwaltung (Optimiert)
# ------------------------
$PrinterOU = "OU=Druckergruppen,DC=contoso,DC=local"
$GroupOU   = "OU=GROUP,DC=contoso,DC=local"
$ExchangeOU = "OU=Verteiler,OU=Exchange,DC=contoso,DC=local"
$global:AllGroups = @()

function LoadAllGroups {
    try {
        $printerGroups = Get-ADGroup -Filter * -SearchBase $PrinterOU -Credential $Global:AdminCredential -Server $dc | Select-Object Name,SamAccountName,DistinguishedName
        $normalGroups  = Get-ADGroup -Filter * -SearchBase $GroupOU   -Credential $Global:AdminCredential -Server $dc | Select-Object Name,SamAccountName,DistinguishedName
        $exchangeGroups = Get-ADGroup -Filter * -SearchBase $ExchangeOU -Credential $Global:AdminCredential -Server $dc | Select-Object Name,SamAccountName,DistinguishedName
	$global:AllGroups = ($printerGroups + $normalGroups + $exchangeGroups) | Sort-Object Name -Unique
    } catch { Log-Write "Fehler beim Laden aller Gruppen: $_"; $global:AllGroups = @() }
}

function LoadUserGroups {
    $user = $UserListBox.SelectedItem
    if (-not $user) { $lstGroups.ItemsSource = @(); return }
    try {
        # Optimiert: nur einmal Get-ADUser, kein mehrfaches Get-ADGroup
        $userObj = Get-ADUser -Identity $user.SamAccountName -Properties memberOf -Credential $Global:AdminCredential -Server $dc
        $groups = @()
        if ($userObj.memberOf) {
            # Alle Gruppenobjekte im Cache suchen
            $groups = $global:AllGroups | Where-Object { $userObj.memberOf -contains $_.DistinguishedName }
        }
        $lstGroups.ItemsSource = $groups | Sort-Object Name
    } catch { $lstGroups.ItemsSource = @(); Log-Write "LoadUserGroups error: $_" }
}

# AddGroup / RemoveGroup
$BtnAddGroup.Add_Click({
    $user = $UserListBox.SelectedItem
    if (-not $user) { [System.Windows.MessageBox]::Show("Bitte Benutzer auswählen."); return }
    if (-not $global:AllGroups) { LoadAllGroups }

    # Exchange-Gruppen optional kennzeichnen
    $global:AllGroups | ForEach-Object {
        if ($_.DistinguishedName -like "*,OU=Verteiler,OU=Exchange,*") {
            $_ | Add-Member -NotePropertyName DisplayText -NotePropertyValue "$($_.Name) (Exchange)" -Force
        } else {
            $_ | Add-Member -NotePropertyName DisplayText -NotePropertyValue $_.Name -Force
        }
    }

    $selectedGroup = Show-GroupSelectionDialog -Groups $global:AllGroups
    if (-not $selectedGroup) { return }
    try {
        Add-ADGroupMember -Identity $selectedGroup.DistinguishedName -Members $user.SamAccountName -Credential $Global:AdminCredential -Server $dc -ErrorAction Stop
        [System.Windows.MessageBox]::Show("Benutzer erfolgreich der Gruppe $groupName hinzugefuegt.")
        Log-Write "AddGroup: $($user.SamAccountName) -> $($selectedGroup.SamAccountName)"
        LoadUserGroups
    } catch { [System.Windows.MessageBox]::Show("Fehler: $_"); Log-Write "AddGroup error: $_" }
})

$BtnRemoveGroup.Add_Click({
    $user = $UserListBox.SelectedItem
    $group = $lstGroups.SelectedItem
    if (-not $user -or -not $group) { [System.Windows.MessageBox]::Show("Bitte Benutzer und Gruppe auswählen."); return }
    try {
        Remove-ADGroupMember -Identity $group.DistinguishedName -Members $user.SamAccountName -Confirm:$false -Credential $Global:AdminCredential -Server $dc -ErrorAction Stop
        [System.Windows.MessageBox]::Show("Benutzer aus der Gruppe $groupName erfolgreich entfernt.")
        Log-Write "RemoveGroup: $($user.SamAccountName) <- $($group.SamAccountName)"
        LoadUserGroups
    } catch { [System.Windows.MessageBox]::Show("Fehler: $_"); Log-Write "RemoveGroup error: $_" }
})

# Event: Benutzer Auswahl -> Gruppen anzeigen
$UserListBox.Add_SelectionChanged({ LoadUserGroups; UpdateSessionDisplay; UpdateUserButtons })

# ------------------------
# Button: Benutzerkonto entsperren
# ------------------------
$BtnUnlock.Add_Click({
    $user = $UserListBox.SelectedItem
    if (-not $user) { return }
    try {
        Unlock-ADAccount -Identity $user.SamAccountName -Server $dc -Credential $Global:AdminCredential -ErrorAction Stop
        [System.Windows.MessageBox]::Show("Benutzer '$($user.SamAccountName)' wurde entsperrt.")
        Log-Write "User unlocked: $($user.SamAccountName)"
    } catch {
        [System.Windows.MessageBox]::Show("Fehler beim Entsperren:`n$($_.Exception.Message)")
        Log-Write "Unlock error: $($_.Exception.Message)"
    }
})


# ------------------------
# Login-Button
# ------------------------
$btnLogin.Add_Click({
    $Global:AdminCredential = New-Object PSCredential(
        $txtUser.Text,
        (ConvertTo-SecureString $txtPass.Password -AsPlainText -Force)
    )
    $LoginPanel.Visibility = "Collapsed"
    $MainGrid.Visibility  = "Visible"
    LoadAllGroups  # Gruppen einmal beim Login laden, Cache für Performance
})

# ------------------------
# Enter-Taste für Suche & Login
# ------------------------
$UserSearchBox.Add_KeyDown({ if ($_.Key -eq "Enter") { SearchUser } })
$ComputerSearchBox.Add_KeyDown({ if ($_.Key -eq "Enter") { SearchComputer } })
$txtUser.Add_KeyDown({ if ($_.Key -eq "Enter") { $btnLogin.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)) } })
$txtPass.Add_KeyDown({ if ($_.Key -eq "Enter") { $btnLogin.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)) } })

$BtnUserSearch.Add_Click({ SearchUser })
$BtnComputerSearch.Add_Click({ SearchComputer })

$UserListBox.Add_SelectionChanged({ UpdateSessionDisplay; UpdateUserButtons })
$ComputerListBox.Add_SelectionChanged({ UpdateSessionDisplay; UpdateUserButtons })

# ------------------------
# Fenster anzeigen
# ------------------------
$window.ShowDialog() | Out-Null