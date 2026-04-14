# File Manager Pro - Android Server

A full-stack File Manager application with Flutter frontend and Python Flask backend.

## Architecture

```
file_manager_pro/
├── backend/              # Python Flask API Server
│   ├── core/
│   │   ├── file_operations.py   # File system CRUD
│   │   ├── terminal_engine.py   # Shell command execution
│   │   └── server_manager.py    # HTTP server management
│   └── server.py                # Main API (port 8000)
├── frontend_flutter/     # Flutter Mobile App
│   └── lib/
│       ├── main.dart
│       ├── services/     # API communication
│       ├── providers/    # State management
│       └── screens/      # UI screens
├── kivy_app/             # Kivy standalone (legacy)
├── run.sh                # Linux/Mac launcher
└── run.bat               # Windows launcher
```

## Features

- **File Browser** — Navigate, create, rename, delete, copy/cut/paste
- **Integrated Terminal** — Execute commands with autocomplete & history
- **Server Manager** — Start/stop Python HTTP, npm, or custom servers
- **File Search** — Search across the filesystem
- **Storage Info** — View disk usage statistics

## Build

APK is built automatically via GitHub Actions on every push to `main`.

Download from: **Actions → Build Flutter APK → Artifacts**

## Manual Setup

### Backend
```bash
cd backend
pip install -r requirements.txt
python server.py
```

### Flutter
```bash
cd frontend_flutter
flutter create --org com.filemanager .
flutter pub get
flutter run
```
