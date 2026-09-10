@echo off
title تشغيل تطبيق النظام المحاسبي
chcp 65001 >nul
cd /d "%~dp0.."

rem ============ تحديد رابط التطبيق (المعامل الأول أو الافتراضي) ============
set "APP_URL=%~1"
if "%APP_URL%"=="" set "APP_URL=http://localhost:8080/?sys=admin"

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

rem ============ فتح التطبيق كنافذة مستقلة (بدون أشرطة المتصفح) ============
start "" chrome --app="%APP_URL%" --new-window

exit