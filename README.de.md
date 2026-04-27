# AD Management Dashboard

**AD Management Dashboard** ist ein modulares, PowerShell-basiertes Tool zur grafischen Verwaltung von Active Directory – entwickelt für den praktischen Einsatz im IT-Alltag.

Die Anwendung entstand als Eigenprojekt mit dem Ziel, wiederkehrende Administrative Aufgaben im AD-Umfeld zu bündeln und über eine übersichtliche WPF-Oberfläche schnell und sicher durchführen zu können – ohne direkt auf die ADUC-Konsole angewiesen zu sein.

---

## Features

### Benutzerverwaltung
- **Suche** nach Benutzern über SamAccountName oder Anzeigename (LDAP-Filter)
- **Aktivieren & Deaktivieren** von Benutzerkonten inkl. automatischem Verschieben in Inaktiv-OUs
- **Entsperren** gesperrter Konten
- **Passwort-Reset** mit Optionen für „Änderung bei nächster Anmeldung" und „Benutzer darf Passwort nicht ändern"
- **Benutzerinformationen anpassen**: Vorname, Nachname, Anzeigename, Kontoablaufdatum

### Computerverwaltung
- **Suche** nach Computerobjekten im AD
- **Aktivieren & Deaktivieren** von Computerkonten inkl. OU-Verschiebung

### Gruppenverwaltung
- Benutzer **Gruppen hinzufügen oder entfernen**
- Unterstützt Drucker-, Standard- und Exchange-Verteilergruppen
- Filterbare Gruppenauswahl per Suchdialog

### Citrix-Integration
- Anzeige aktiver **Citrix-Sessions** (aus CSV-Quelle)
- **Session-Abmeldung** mit Benutzerbenachrichtigung (60-Sekunden-Vorlauf) über Delivery Controller

### TeamViewer-Integration
- Direktstart von **TeamViewer** für den ausgewählten Computer

### Logging
- Alle Aktionen werden in einer **UTF-8 Logdatei** protokolliert (`%TEMP%\AD-Tool.log`)

---

## Technologien

| Technologie | Verwendung |
|---|---|
| PowerShell 5.1 | Kernlogik, AD-Abfragen, Citrix-Steuerung |
| WPF / XAML | Grafische Benutzeroberfläche |
| Active Directory Module (RSAT) | AD-Operationen (Get/Set/Move/Enable/Disable) |
| Citrix Broker SDK | Session-Management über Delivery Controller |

---

## Projektstruktur

```
AD-Management-Dashboard/
├── Main.ps1                          # Einstiegspunkt, Login, GUI-Initialisierung
├── Main.cmd                          # Starter (bypasses ExecutionPolicy)
├── GUI.xaml                          # WPF-Oberfläche
├── Modules/
│   ├── Tab1.AD-Management.ps1        # Kern-Modul: Suche, Buttons, Gruppen, Sessions
│   ├── Tab1.Feature_TeamViewer.ps1   # TeamViewer-Integration
│   ├── Tab1.Feature_CitrixLogoff.ps1 # Citrix Session-Abmeldung
│   └── Tab1.Feature_EditUser.ps1     # Benutzerinformationen bearbeiten (Popup)
└── Dialogs/
    └── GroupSelectionDialog.ps1      # Filterbarer Gruppenauswahl-Dialog
```

---

## Voraussetzungen

- Windows PowerShell >= 5.1
- RSAT-AD-PowerShell (`ActiveDirectory`-Modul)
- Netzwerkzugang zum Domain Controller
- Für Citrix-Features: Citrix Broker PowerShell SDK auf dem Delivery Controller

---

## Installation & Start

```bash
git clone https://github.com/yourusername/AD-Management-Dashboard.git
cd AD-Management-Dashboard
```

Anschließend entweder per Doppelklick auf `Main.cmd` starten, oder direkt in PowerShell:

```powershell
powershell.exe -ExecutionPolicy Bypass -File ".\Main.ps1"
```

---

## Hinweis

Dieses Repository ist eine anonymisierte Version eines produktiv eingesetzten Tools. Domänenspezifische Werte (Server, OUs, Domänenname) wurden durch generische Platzhalter ersetzt und müssen vor dem Einsatz an die eigene Umgebung angepasst werden.
