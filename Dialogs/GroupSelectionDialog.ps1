function Show-GroupSelectionDialog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object[]]$Groups  # Objekt-Array erzwingen
    )

    # Sicherstellen, dass $Groups immer ein Array ist, selbst bei nur einem Objekt
    $Groups = @($Groups)

    # ------------------------
    # XAML für Dialog
    # ------------------------
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Gruppe auswählen" Height="500" Width="450" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Suchfeld -->
        <StackPanel Grid.Row="0" Margin="0,0,0,5">
            <TextBlock Text="Gruppe suchen:" Margin="0,0,0,3" />
            <TextBox x:Name="txtSearchGroup" Height="25"/>
        </StackPanel>

        <!-- ListBox -->
        <ListBox x:Name="lstGroupSelect" Grid.Row="1" Margin="0,0,0,10"
                 DisplayMemberPath="Name" SelectedValuePath="DistinguishedName"/>

        <!-- Buttons -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="btnOk" Content="OK" Width="80" Margin="0,0,10,0"/>
            <Button x:Name="btnCancel" Content="Abbrechen" Width="80"/>
        </StackPanel>
    </Grid>
</Window>
"@

    # ------------------------
    # XAML laden
    # ------------------------
    $reader = (New-Object System.Xml.XmlNodeReader ([xml]$xaml))
    $window = [Windows.Markup.XamlReader]::Load($reader)

    # Controls referenzieren
    $txtSearchGroup = $window.FindName("txtSearchGroup")
    $lstGroupSelect = $window.FindName("lstGroupSelect")
    $btnOk          = $window.FindName("btnOk")
    $btnCancel      = $window.FindName("btnCancel")

    # ItemsSource initial setzen – garantiert IEnumerable
    $lstGroupSelect.ItemsSource = $Groups

# ------------------------
# Suche filtern
# ------------------------
$txtSearchGroup.Add_TextChanged({
    $text = $txtSearchGroup.Text
    if ([string]::IsNullOrWhiteSpace($text)) {
        $lstGroupSelect.ItemsSource = @($Groups)  # <-- immer Array erzwingen
    } else {
        $filtered = $Groups | Where-Object {
            $_ -and $_.Name -and $_.Name.ToLower().Contains($text.ToLower())
        }
        $lstGroupSelect.ItemsSource = @($filtered)  # <-- immer Array erzwingen
    }
})

    # ------------------------
    # OK Button
    # ------------------------
    $btnOk.Add_Click({
        if ($lstGroupSelect.SelectedItem) {
            $window.Tag = $lstGroupSelect.SelectedItem
            $window.Close()
        } else {
            [System.Windows.MessageBox]::Show("Bitte zuerst eine Gruppe auswählen.")
        }
    })

    # ------------------------
    # Abbrechen Button
    # ------------------------
    $btnCancel.Add_Click({
        $window.Tag = $null
        $window.Close()
    })

    # ------------------------
    # Doppelklick auf ListBox
    # ------------------------
    $lstGroupSelect.Add_MouseDoubleClick({
        if ($lstGroupSelect.SelectedItem) {
            $window.Tag = $lstGroupSelect.SelectedItem
            $window.Close()
        }
    })

    # ------------------------
    # Dialog anzeigen
    # ------------------------
    $window.ShowDialog() | Out-Null
    return $window.Tag
}



