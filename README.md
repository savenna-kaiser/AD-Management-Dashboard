# AD-Manager Modular

**AD-Manager Modular** ist ein PowerShell-basiertes Tool zur Verwaltung von Active Directory (AD).  
Es bietet Funktionen wie Benutzer- und Computer-Suche, Aktivieren/Deaktivieren, Verschieben zwischen OUs, Passwort-Reset und Gruppenverwaltung – alles über eine übersichtliche grafische Oberfläche (WPF/XAML).

---

## Features

- **Benutzer- und Computersuche** in AD-OUs  
- **Aktivieren & Deaktivieren** von Benutzern und Computern  
- **Verschieben** von Objekten zwischen Active Directory OUs  
- **Passwort-Reset** inklusive Optionen für „Change at next logon“ und „Cannot change password“  
- **Gruppenverwaltung**: Benutzer Gruppen hinzufügen oder entfernen  
- **Logging**: Alle Aktionen werden in einer UTF-8 Logdatei protokolliert  

---

## Voraussetzungen

- Windows PowerShell (>= 5.1 empfohlen)  
- ActiveDirectory Modul (`RSAT-AD-PowerShell`)  
- Zugriff auf die entsprechenden AD OUs  
- GUI-Datei (`GUI.xaml`) muss im Projektordner vorhanden sein  

---

## Installation / Nutzung

1. Repository klonen:

   ```bash
   git clone https://github.com/yourusername/AD-Manager-modular.git
   cd AD-Manager-modular-

