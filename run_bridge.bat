@echo off
title ARUGA - Stream Bridge (USB Webcam + Tunnel)
cd /d "%~dp0"

echo ==========================================================
echo    ARUGA Stream Bridge - USB webcam to webapp live feed
echo    Local webcam - HTTP MJPEG + telemetry + quick tunnel
echo ==========================================================
echo.

rem =====================================================================
rem  BRIDGE SOURCE CONFIGURATION (edit here, not below)
rem =====================================================================
rem Default: local USB webcam at index 0 (on this machine the "HD Webcam"
rem is normally index 0). If the wrong camera opens (or nothing opens),
rem list the available indices with:
rem     .\.venv\Scripts\python.exe -c "from core.camera_sources import probe_usb_cameras; [print(r) for r in probe_usb_cameras()]"
rem then change 0 below to the right index.
set "BRIDGE_ARGS=--source 0"

rem --- Tapo C200/C230/C310 over RTSP instead of the local webcam? ------
rem Comment the "set BRIDGE_ARGS" line above and uncomment this one.
rem Fill in your own camera credentials; stream1 = HD, stream2 = fast.
rem Recommended thresholds: det-conf 0.45, kpt-conf 0.35, maintain-thresh 0.20
rem set "BRIDGE_ARGS=--tapo-ip 192.168.1.50 --tapo-user YOUR_USER --tapo-pass YOUR_PASS --stream stream2 --det-conf 0.45 --kpt-conf 0.35 --maintain-thresh 0.20"

rem --- Patient audio ---------------------------------------------------
rem A webcam source has no RTSP audio stream, so --patient-audio rtsp is
rem NOT usable here (see the patient-audio defaulting in stream_bridge.py).
rem Use either:
rem     --patient-audio mic        (local microphone)
rem     --patient-audio synthetic  (demo speech; the default for non-RTSP)
rem Example: set "BRIDGE_ARGS=--source 0 --patient-audio mic"
rem ---------------------------------------------------------------------

rem 1. Check if virtual environment already exists
if exist ".venv\Scripts\python.exe" (
    echo [OK] Virtual environment found.
    goto LAUNCH
)

rem 2. If .venv is missing, find a working Python installation on the system
echo [*] Virtual environment (.venv) not found. Checking system Python...

set PYTHON_CMD=
for %%C in (py python3 python) do (
    %%C --version >nul 2>&1
    if not errorlevel 1 (
        set PYTHON_CMD=%%C
        goto PYTHON_FOUND
    )
)

:PYTHON_NOT_FOUND
echo.
echo [ERROR] Python is not installed or not found in your system PATH!
echo.
echo To run this project, the recipient needs to install Python (3.10 - 3.12 recommended):
echo   1. Download Python from: https://www.python.org/downloads/
echo   2. IMPORTANT: Check the box "Add Python to PATH" during installation.
echo.
pause
exit /b 1

:PYTHON_FOUND
echo [OK] Found system Python: %PYTHON_CMD%
echo.
echo [*] Setting up virtual environment for the first time...
echo [*] This will take a few minutes (ONNX Runtime + dependencies)...
echo.
%PYTHON_CMD% -m venv .venv
if errorlevel 1 (
    echo.
    echo [ERROR] Failed to create virtual environment (.venv).
    echo Please make sure your Python installation has the 'venv' module.
    pause
    exit /b 1
)

echo [*] Installing dependencies from requirements.txt...
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt

if errorlevel 1 (
    echo.
    echo [ERROR] Failed to install required packages. Please check your internet connection.
    pause
    exit /b 1
)

echo.
echo [SUCCESS] Environment setup complete!
echo.

:LAUNCH
rem =====================================================================
rem  TUNNEL: cloudflared quick tunnel to http://127.0.0.1:8080
rem  (Windows equivalent of run_tunnel.sh)
rem =====================================================================
rem cloudflared.exe must be on PATH or next to this script (download:
rem https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/ ).
rem It opens in its own window so you can read (and copy) the URL it prints.
where cloudflared.exe >nul 2>&1
if not errorlevel 1 goto TUNNEL_OK
if exist "cloudflared.exe" goto TUNNEL_OK
echo [WARN] cloudflared.exe not found - starting the bridge WITHOUT the tunnel.
echo        The feed stays local-only at http://127.0.0.1:8080/video_feed
goto START_BRIDGE

:TUNNEL_OK
echo [*] Starting cloudflared quick tunnel (separate window)...
start "ARUGA tunnel (cloudflared)" cmd /k cloudflared.exe tunnel --url http://127.0.0.1:8080

rem ---------------------------------------------------------------------
rem  TUNNEL URL REGISTRATION (manual - equivalent of run_tunnel.sh)
rem ---------------------------------------------------------------------
rem The webapp finds the bridge through the public discovery API, so the
rem quick-tunnel URL must be registered there. A .bat reimplementation of
rem run_tunnel.sh's watcher loop is impractical here, so do these TWO
rem steps once after the tunnel window prints its URL:
rem
rem  1) Copy the quick-tunnel URL printed in the "ARUGA tunnel" window,
rem     e.g.  https://abcd-1234-xy.trycloudflare.com
rem
rem  2) Register it with a POST to the /bridge-url endpoint. The API token
rem     lives in the token file only (never paste, commit, or share it):
rem        Linux equivalent:   ~/Projects/aruga-api/.api_token
rem        Windows equivalent: %USERPROFILE%\Projects\aruga-api\.api_token
rem     In cmd.exe (from any directory), as two commands on two lines
rem     (the ^ before the angle bracket is just so this comment line is
rem     not parsed as a redirection - drop it when you actually run it):
rem
rem        set /p ARUGA_TOKEN=^<"%USERPROFILE%\Projects\aruga-api\.api_token"
rem        curl.exe -X POST https://aruga-api.pages.dev/bridge-url -H "Content-Type: application/json" -H "Authorization: Bearer %ARUGA_TOKEN%" -d "{\"url\":\"https://YOUR-URL.trycloudflare.com\"}"
rem
rem     Re-run step 2 whenever cloudflared prints a NEW URL (it rotates on
rem     restart). run_tunnel.sh on the Linux host is the canonical
rem     automated implementation of this registration loop.
rem ---------------------------------------------------------------------

:START_BRIDGE
echo [*] Starting ARUGA Stream Bridge with: %BRIDGE_ARGS%
echo [*] Feed:  http://127.0.0.1:8080/video_feed
echo.
.\.venv\Scripts\python.exe stream_bridge.py %BRIDGE_ARGS%

pause
