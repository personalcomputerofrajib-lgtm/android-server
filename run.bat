@echo off
REM =============================================
REM FILE MANAGER PRO — Windows Launcher
REM =============================================

echo.
echo ============================================
echo   FILE MANAGER PRO — Launcher
echo ============================================
echo.

echo [1/3] Installing backend dependencies...
cd backend
pip install flask flask-cors psutil -q
echo   Done.

echo [2/3] Starting backend API server...
start /B python server.py
echo   Backend starting at http://127.0.0.1:8000

timeout /t 2 >nul

echo [3/3] Flutter setup...
cd ..\frontend_flutter
call flutter pub get
echo.
echo ============================================
echo   Backend running at http://127.0.0.1:8000
echo   Run: cd frontend_flutter ^& flutter run
echo ============================================
echo.
pause
