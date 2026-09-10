@echo off
title النظام المحاسبي - تشغيل جميع الأنظمة
chcp 65001 >nul
echo ============================================================
echo          النظام المحاسبي - تشغيل الأنظمة الخمسة
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

rem ---------- فتح كل نظام كتطبيق مستقل ----------
start "" chrome --app="http://localhost:8080/?sys=admin"
start "" chrome --app="http://localhost:8081/?sys=branch1"
start "" chrome --app="http://localhost:8082/?sys=branch2"
start "" chrome --app="http://localhost:8083/?sys=branch3"
start "" chrome --app="http://localhost:8084/?sys=branch4"

echo تم فتح الأنظمة الخمسة كتطبيقات مستقلة بنجاح.
echo.
echo   النظام الأساسي : http://localhost:8080/
echo   فرع صنعاء       : http://localhost:8081/
echo   فرع عدن         : http://localhost:8082/
echo   فرع تعز         : http://localhost:8083/
echo   فرع الحديدة     : http://localhost:8084/
echo.
echo أبقِ هذه النافذة مفتوحة أو أغلقها - الخادم يعمل خلف الكواليس.
timeout /t 5 /nobreak >nul