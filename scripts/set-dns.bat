@echo off
REM ============================================================
REM  set-dns.bat
REM  Sets DNS servers to 192.0.2.10 (primary) and 192.0.2.11
REM  on all active Ethernet/Wi-Fi network adapters.
REM  Edit PRIMARY/SECONDARY to your DNS servers first.
REM  Must be run as Administrator.
REM ============================================================

set PRIMARY=192.0.2.10
set SECONDARY=192.0.2.11

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
