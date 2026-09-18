@echo off
title النظام المحاسبي - تشغيل النظام الأساسي
chcp 65001 >nul
echo ============================================================
echo          النظام المحاسبي - تشغيل النظام الأساسي
echo ============================================================
echo.
set "ROOT=%~dp0"
cd /d "%ROOT%"

rem ---------- بدء الخادم المحلي (إن لم يكن يعمل) ----------
where curl >nul 2>&1
if %errorlevel%==0 (
    curl -s --max-time 1 "http://localhost:8080/api/ping" >nul 2>&1
    if errorlevel 1 (
        start "" /min python "%ROOT%serve_all.py"
        timeout /t 4 /nobreak >nul
    )
) else (
    powershell -NoProfile -Command "(New-Object Net.Sockets.TcpClient).Connect('127.0.0.1',8080)" >nul 2>&1
    if errorlevel 1 (
        start "" /min python "%ROOT%serve_all.py"
        timeout /t 4 /nobreak >nul
    )
)

rem ---------- فتح النظام الأساسي كتطبيق مستقل ----------
start "" chrome --app="http://localhost:8080/?sys=admin"

echo تم فتح النظام الأساسي كتطبيق مستقل بنجاح.
echo.
echo   النظام الأساسي : http://localhost:8080/
echo   (كل الفروع تُدار وتُفتح عبر السحابة من النظام الأساسي)
echo.
echo أبقِ هذه النافذة مفتوحة أو أغلقها - الخادم يعمل خلف الكواليس.
timeout /t 5 /nobreak >nul
