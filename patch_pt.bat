@echo off
setlocal

echo.
echo   patch_pt.bat           apply patch
echo   patch_pt.bat restore   restore original
echo.

echo   elevating ...
fltmc >nul 2>&1
if errorlevel 1 (
    if "%~1"=="" (powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs") else (powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs")
    exit /b
)

echo   locating packet tracer ...
set "EXE=%~dp0PacketTracer.exe"
if not exist "%EXE%" for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "$l=@(\"$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Cisco Packet Tracer\Cisco Packet Tracer.lnk\",\"$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Cisco Packet Tracer\Cisco Packet Tracer.lnk\");foreach($x in $l){if(Test-Path $x){$t=(New-Object -ComObject WScript.Shell).CreateShortcut($x).TargetPath;if($t -and (Test-Path $t)){$t;break}}}"`) do set "EXE=%%T"
if not exist "%EXE%" set "EXE=C:\Program Files\Cisco Packet Tracer 9.0.1\bin\PacketTracer.exe"
if not exist "%EXE%" (echo   [x] packettracer.exe not found & goto :done)
echo       %EXE%
set "BAK=%EXE%.bak"

if /i "%~1"=="restore" goto :restore

echo   hashing ...
for /f "usebackq delims=" %%H in (`powershell -NoProfile -Command "(Get-FileHash -LiteralPath '%EXE%' -Algorithm SHA256).Hash.ToLower()"`) do set "H=%%H"
set "H1=843579cc806a41d57a4ca524d6805b97ee1f91e0ddd02ac09be8461db04b94a1"
set "H2=df624dc8573abca6d54a735686accd64776eb8f8f444d97c87938f97a6f024c6"
if /i "%H%"=="%H1%" goto :patch
if /i "%H%"=="%H2%" goto :patch
echo       %H%
echo   [x] not packet tracer 9.0.1 - nothing changed
goto :done

:patch
echo   backing up ...
if not exist "%BAK%" copy /y "%EXE%" "%BAK%" >nul
copy /y "%BAK%" "%EXE%" >nul
echo   stopping packet tracer ...
taskkill /f /im PacketTracer.exe >nul 2>&1
taskkill /f /im QtWebEngineProcess.exe >nul 2>&1
echo   patching ...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$e='%EXE%';$b=[IO.File]::ReadAllBytes($e);$p=@(@(0x963880,0xB0,0x00,0xC3,0x90,0x90,0x90),@(0x24AAA30,0xB0,0x01,0xC3),@(0x17DF40,0xB8,0x01,0x00,0x00,0x00,0xC3),@(0x24A120A,0x90,0x90),@(0x24AA8FC,0xEB,0x00),@(0x24A17AA,0xE9,0x5A,0x04,0x00,0x00,0x90),@(0x127D10,0xB0,0x01,0xC3,0x90,0x90));foreach($x in $p){for($i=1;$i -lt $x.Count;$i++){$b[$x[0]+$i-1]=[byte]$x[$i]}};[IO.File]::WriteAllBytes($e,$b)" && goto :verify
echo   [x] patch failed
goto :done

:restore
echo   restoring ...
copy /y "%BAK%" "%EXE%" >nul
goto :verify

:verify
echo   verifying ...
for /f "usebackq delims=" %%H in (`powershell -NoProfile -Command "(Get-FileHash -LiteralPath '%EXE%' -Algorithm SHA256).Hash.ToLower()"`) do set "H=%%H"
echo       %H%
echo   done
goto :done

:done
echo.
if not "%PT_NO_PAUSE%"=="1" pause >nul
endlocal
