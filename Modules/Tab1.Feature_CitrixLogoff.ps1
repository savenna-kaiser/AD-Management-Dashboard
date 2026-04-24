# =========================================
# Tab1.Feature_CitrixLogoff.ps1
# Citrix-Session per Delivery Controller abmelden
# =========================================
param(
    [Parameter(Mandatory=$true)] [object] $SelectedSession,
    [Parameter(Mandatory=$true)] [System.Windows.Window] $ParentWindow,
    [pscredential] $Credential = $null
)
Add-Type -AssemblyName PresentationFramework

# ------------------------
# Credential prüfen
# ------------------------
$cred = if ($Credential) { $Credential } else { $Global:AdminCredential }

# ------------------------
# Delivery Controller (Failover)
# ------------------------
$controllers = @(
    "CORP1CTXCDC1.contoso.local",
    "CORP1CTXCDC2.contoso.local",
    "CORP1CTXCDC3.contoso.local"
)

$controller = $null
foreach ($ctrl in $controllers) {
    if (Test-Connection -ComputerName $ctrl -Count 1 -Quiet -ErrorAction SilentlyContinue) {
        $controller = $ctrl
        break
    }
}

if (-not $controller) {
    [System.Windows.MessageBox]::Show("Kein erreichbarer Delivery Controller gefunden.", "Fehler", "OK", "Error")
    return
}

# ------------------------
# Bestätigungsdialog
# ------------------------
$userName   = $SelectedSession.UserFullName
$sessionUid = $SelectedSession.Uid

$confirm = [System.Windows.MessageBox]::Show(
    "Benutzer '$userName' wird in 60 Sekunden abgemeldet.`nJetzt Nachricht senden und abmelden?",
    "Citrix Session beenden",
    "YesNo",
    "Warning"
)
if ($confirm -ne "Yes") { return }

# ------------------------
# Nachricht senden
# ------------------------
try {
    Invoke-Command -ComputerName $controller -Credential $cred -ScriptBlock {
        param($uid, $msg)
        Add-PSSnapin Citrix.* -ErrorAction SilentlyContinue
        $s = Get-BrokerSession -Uid $uid -ErrorAction SilentlyContinue
        if ($s) {
            Send-BrokerSessionMessage -InputObject $s -MessageStyle Information -Title "IT-Hinweis" -Text $msg
        }
    } -ArgumentList $sessionUid, "Ihre Sitzung wird in 60 Sekunden beendet. Bitte speichern Sie Ihre Arbeit." -ErrorAction Stop

    Log-Write "Citrix: Nachricht gesendet an $userName (Uid: $sessionUid) via $controller"

    # ------------------------
    # 60 Sekunden warten ohne UI zu blockieren
    # ------------------------
    $Global:ctxController = $controller
    $Global:ctxUid        = $sessionUid
    $Global:ctxUserName   = $userName
    $Global:ctxCred       = $cred

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(60)
    $timer.Add_Tick({
        $timer.Stop()
        try {
            Invoke-Command -ComputerName $Global:ctxController -Credential $Global:ctxCred -ScriptBlock {
                param($uid)
                Add-PSSnapin Citrix.* -ErrorAction SilentlyContinue
                $s = Get-BrokerSession -Uid $uid -ErrorAction SilentlyContinue
                if ($s) {
                    $s | Stop-BrokerSession
                }
                # Keine Session mehr = Benutzer hat sich selbst abgemeldet, kein Fehler
            } -ArgumentList $Global:ctxUid -ErrorAction Stop
            Log-Write "Citrix: Session beendet fuer $($Global:ctxUserName) (Uid: $($Global:ctxUid))"
        } catch {
            [System.Windows.MessageBox]::Show("Fehler beim Abmelden:`n$($_.Exception.Message)", "Fehler", "OK", "Error")
            Log-Write "Citrix Logoff error: $($_.Exception.Message)"
        }
    })
    $timer.Start()

} catch {
    [System.Windows.MessageBox]::Show("Fehler beim Senden der Nachricht:`n$($_.Exception.Message)", "Fehler", "OK", "Error")
    Log-Write "Citrix Send-Message error: $($_.Exception.Message)"
}