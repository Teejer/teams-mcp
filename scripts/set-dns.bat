@echo off
REM ============================================================
REM  set-dns.bat
REM  Sets DNS servers to 10.10.1.27 (primary) and 10.10.1.30
REM  on all active Ethernet/Wi-Fi network adapters.
REM  Must be run as Administrator.
REM ============================================================

set PRIMARY=10.10.1.27
set SECONDARY=10.10.1.30

REM --- Check for admin rights ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: This script must be run as Administrator.
    echo Right-click the file and select "Run as administrator".
    pause
    exit /b 1
)

echo Setting DNS servers to %PRIMARY% and %SECONDARY% ...
echo.

REM --- Apply to every connected (non-loopback) interface ---
REM netsh skips interfaces that are disconnected, so this is safe.
netsh interface ip set dns name="Ethernet"  static %PRIMARY% primary
netsh interface ip add dns name="Ethernet"  %SECONDARY% index=2

netsh interface ip set dns name="Wi-Fi"     static %PRIMARY% primary
netsh interface ip add dns name="Wi-Fi"     %SECONDARY% index=2

echo.
echo Done. Current DNS configuration:
echo.
ipconfig /all | findstr /i "DNS Servers"

echo.
pause
