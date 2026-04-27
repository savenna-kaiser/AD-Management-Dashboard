🇩🇪 [Deutsche Version](README.de.md)

# AD Management Dashboard

**AD Management Dashboard** is a modular, PowerShell-based tool for managing Active Directory through a graphical interface — built for practical, day-to-day IT operations.

The application was developed as a personal project to consolidate recurring AD administration tasks into a single, easy-to-use WPF interface, removing the need to work directly in the ADUC console.

---

## Features

### User Management
- **Search** for users by SamAccountName or display name (LDAP filter)
- **Enable & disable** user accounts including automatic relocation to inactive OUs
- **Unlock** locked accounts
- **Password reset** with options for "Change at next logon" and "User cannot change password"
- **Edit user attributes**: first name, last name, display name, account expiry date

### Computer Management
- **Search** for computer objects in AD
- **Enable & disable** computer accounts including OU relocation

### Group Management
- **Add or remove** users from groups
- Supports printer groups, standard groups and Exchange distribution groups
- Filterable group selection via search dialog

### Citrix Integration
- Display active **Citrix sessions** (from CSV source)
- **Session logoff** with user notification (60-second grace period) via Delivery Controller

### TeamViewer Integration
- Direct **TeamViewer** launch for the selected computer

### Logging
- All actions are logged to a **UTF-8 log file** (`%TEMP%\AD-Tool.log`)

---

## Tech Stack

| Technology | Usage |
|---|---|
| PowerShell 5.1 | Core logic, AD queries, Citrix control |
| WPF / XAML | Graphical user interface |
| Active Directory Module (RSAT) | AD operations (Get/Set/Move/Enable/Disable) |
| Citrix Broker SDK | Session management via Delivery Controller |

---

## Project Structure

```
AD-Management-Dashboard/
├── Main.ps1                          # Entry point, login, GUI initialization
├── Main.cmd                          # Launcher (bypasses ExecutionPolicy)
├── GUI.xaml                          # WPF interface
├── Modules/
│   ├── Tab1.AD-Management.ps1        # Core module: search, buttons, groups, sessions
│   ├── Tab1.Feature_TeamViewer.ps1   # TeamViewer integration
│   ├── Tab1.Feature_CitrixLogoff.ps1 # Citrix session logoff
│   └── Tab1.Feature_EditUser.ps1     # Edit user attributes (popup)
└── Dialogs/
    └── GroupSelectionDialog.ps1      # Filterable group selection dialog
```

---

## Requirements

- Windows PowerShell >= 5.1
- RSAT-AD-PowerShell (`ActiveDirectory` module)
- Network access to the Domain Controller
- For Citrix features: Citrix Broker PowerShell SDK on the Delivery Controller

---

## Installation & Usage

```bash
git clone https://github.com/savenna-kaiser/AD-Management-Dashboard.git
cd AD-Management-Dashboard
```

Then either double-click `Main.cmd` to launch, or run directly in PowerShell:

```powershell
powershell.exe -ExecutionPolicy Bypass -File ".\Main.ps1"
```

---

## Note

This repository is an anonymised version of a tool used in a production environment. Domain-specific values (servers, OUs, domain name) have been replaced with generic placeholders and must be adapted to your own environment before use.
