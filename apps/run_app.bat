@echo off
title تشغيل تطبيق النظام المحاسبي
chcp 65001 >nul
cd /d "%~dp0.."

rem ============ تحديد رابط التطبيق (المعامل الأول أو الافتراضي) ============
set "APP_URL=%~1"
if "%APP_URL%"=="" set "APP_URL=https://accountingsystem-fc3f0.web.app/?sys=admin"

rem ============ إذا كان الرابط سحابياً (https) افتح مباشرة بدون أي تأخير ============
echo %APP_URL% | findstr /i "https://" >nul
if not errorlevel 1 goto :open

rem ============ التأكد من أن الخادم المحلي يعمل (وبدء تشغيله إن لزم) ============
where curl >nul 2>&1
if %errorlevel%==0 (
    curl -s --max-time 1 "http://localhost:8080/api/ping" >nul 2>&1
    if errorlevel 1 (
        start "" /min python "%~dp0..\serve_all.py"
        timeout /t 4 /nobreak >nul
    )
) else (
    powershell -NoProfile -Command "(New-Object Net.Sockets.TcpClient).Connect('127.0.0.1',8080)" >nul 2>&1
    if errorlevel 1 (
        start "" /min python "%~dp0..\serve_all.py"
        timeout /t 4 /nobreak >nul
    )
)

:open
rem ============ فتح التطبيق كنافذة مستقلة في Chrome ============
start "" chrome --app="%APP_URL%" --new-window

exit