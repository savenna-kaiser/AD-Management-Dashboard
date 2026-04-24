param(
    [Parameter(Mandatory=$true)]
    [object]$SelectedUser,

    [Parameter(Mandatory=$true)]
    [Windows.Window]$ParentWindow
)

Add-Type -AssemblyName PresentationFramework
Import-Module ActiveDirectory -ErrorAction Stop

# ------------------------
# XAML für Popup mit Ablaufdatum
# ------------------------
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Benutzer$([char]0xE4)nderungen" Height="550" Width="600"
        WindowStartupLocation="CenterOwner" ResizeMode="NoResize">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Benutzerinformationen -->
        <StackPanel Grid.Row="0" Margin="0,0,0,10">
            <TextBlock Text="Benutzer:" FontWeight="Bold" Margin="0,0,0,10"/>
            
            <StackPanel Orientation="Horizontal" Margin="0,5,0,0">
                <TextBlock Text="Vorname:" Width="80"/>
                <TextBox x:Name="txtGivenName" Width="200"/>
            </StackPanel>
            
            <StackPanel Orientation="Horizontal" Margin="0,5,0,0">
                <TextBlock Text="Nachname:" Width="80"/>
                <TextBox x:Name="txtSurname" Width="200"/>
            </StackPanel>
            
            <StackPanel Orientation="Horizontal" Margin="0,5,0,0">
                <TextBlock Text="Anzeigename:" Width="80"/>
                <TextBox x:Name="txtDisplayName" Width="200"/>
            </StackPanel>

            <!-- Ablaufdatum -->
            <StackPanel Orientation="Horizontal" Margin="0,15,0,0" VerticalAlignment="Center">
                <TextBlock Text="Konto l$([char]0xE4)uft ab:" Width="100" Margin="0,0,10,0"/>
                <ComboBox x:Name="cbExpire" Width="140" SelectedIndex="0" Margin="0,0,10,0">
                    <ComboBoxItem Content="Nie"/>
                    <ComboBoxItem Content="Datum ausw$([char]0xE4)hlen"/>
                </ComboBox>
                <DatePicker x:Name="dpExpireDate" Width="140" IsEnabled="False"/>
            </StackPanel>
        </StackPanel>

        <!-- Fehler/Hinweise -->
        <GroupBox Grid.Row="1" Header="Fehler / Hinweise" Margin="0,10,0,0">
            <ListBox x:Name="lstErrors"/>
        </GroupBox>

        <!-- Buttons -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,15,0,0">
            <Button x:Name="btnUpdateAD" Content="AD speichern" Width="120" Margin="5"/>
            <Button x:Name="btnECP" Content="Mailbox (ECP)" Width="120" Margin="5"/>
            <Button x:Name="btnClose" Content="Schlie$([char]0xDF)en" Width="80" Margin="5"/>
        </StackPanel>
    </Grid>
</Window>
"@

# ------------------------
# XAML laden (UTF8 korrekt)
# ------------------------
$bytes = [System.Text.Encoding]::UTF8.GetBytes($xaml)
$ms = New-Object System.IO.MemoryStream(,$bytes)
$reader = New-Object System.Xml.XmlTextReader($ms)
$window = [Windows.Markup.XamlReader]::Load($reader)
$window.Owner = $ParentWindow

# Controls referenzieren
$txtGivenName 	= $window.FindName("txtGivenName")
$txtSurname   	= $window.FindName("txtSurname")
$txtDisplayName = $window.FindName("txtDisplayName")
$lstErrors    	= $window.FindName("lstErrors")
$btnUpdateAD  	= $window.FindName("btnUpdateAD")
$btnECP       	= $window.FindName("btnECP")
$btnClose     	= $window.FindName("btnClose")
$cbExpire     	= $window.FindName("cbExpire")
$dpExpireDate 	= $window.FindName("dpExpireDate")

foreach ($ctrl in @($txtGivenName,$txtSurname,$txtDisplayName,$lstErrors,$btnUpdateAD,$btnECP,$btnClose,$cbExpire,$dpExpireDate)) {
    if (-not $ctrl) { throw "Fehler: XAML-Control nicht gefunden!" }
}

# ------------------------
# Benutzerinformationen füllen
# ------------------------
try {
    $adUser = Get-ADUser -Identity $SelectedUser.SamAccountName `
                          -Properties GivenName,Surname,DisplayName,Mail,AccountExpirationDate `
                          -ErrorAction Stop
    $txtGivenName.Text   = $adUser.GivenName
    $txtSurname.Text     = $adUser.Surname
    $txtDisplayName.Text = $adUser.DisplayName

    if ($adUser.AccountExpirationDate) {
        $cbExpire.SelectedIndex = 1
        $dpExpireDate.SelectedDate = $adUser.AccountExpirationDate
        $dpExpireDate.IsEnabled = $true
    } else {
        $cbExpire.SelectedIndex = 0
        $dpExpireDate.IsEnabled = $false
    }

    # Fehlerliste prüfen
    $lstErrors.Items.Clear()
    if ($adUser.DisplayName -and $adUser.Mail) {
        if (-not ($adUser.Mail.ToLower().Contains($adUser.DisplayName.ToLower().Split(" ")[0]))) {
            $lstErrors.Items.Add("Bei Namens$([char]0xE4)nderung DisplayName $([char]0xFC)berpr$([char]0xFC)fen.")
        }
    }
} catch {
    [System.Windows.MessageBox]::Show("Fehler beim Laden des Benutzers:`n$($_.Exception.Message)")
}

# ------------------------
# Ablaufdatum Logik
# ------------------------
$cbExpire.Add_SelectionChanged({
    if ($cbExpire.SelectedIndex -eq 1) {
        $dpExpireDate.IsEnabled = $true
    } else {
        $dpExpireDate.IsEnabled = $false
    }
})

# ------------------------
# Buttons Events
# ------------------------
$btnUpdateAD.Add_Click({
    try {
        $params = @{
            Identity = $adUser.SamAccountName
            GivenName = $txtGivenName.Text
            Surname   = $txtSurname.Text
            DisplayName = $txtDisplayName.Text
            Server = $adUser.DNSHostName
        }

        if ($cbExpire.SelectedIndex -eq 0) {
            $params['AccountExpirationDate'] = $null
        } elseif ($cbExpire.SelectedIndex -eq 1 -and $dpExpireDate.SelectedDate) {
            $params['AccountExpirationDate'] = $dpExpireDate.SelectedDate.Value.Date
        }

        Set-ADUser @params
        [System.Windows.MessageBox]::Show("Benutzerinformationen gespeichert.")
    } catch {
        [System.Windows.MessageBox]::Show("Fehler beim Speichern:`n$($_.Exception.Message)")
    }
})

$btnECP.Add_Click({
    $mailboxUrl = "https://CORP1EXCHG1/ecp/?r=$($adUser.SamAccountName)"
    Start-Process $mailboxUrl
})

$btnClose.Add_Click({ $window.Close() })

# ------------------------
# Fenster anzeigen
# ------------------------
$window.ShowDialog() | Out-Null