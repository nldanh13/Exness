@echo off
rem Bam dup file nay de mo giao dien dieu khien bot tren trinh duyet (http://localhost:8765).
rem Dong cua so den nay de tat giao dien.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0GiaoDien.ps1"
if errorlevel 1 pause
