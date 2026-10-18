@pushd "%~dp0"
@where cl.exe >nul 2>nul
@if errorlevel 1 exit /b 1
@cl /nologo /LD /MT /O2 /EHsc /W4 /I minhook\include bridge.cpp minhook\src\buffer.c minhook\src\hook.c minhook\src\trampoline.c minhook\src\hde\hde32.c /link /OUT:bs2_steam_bridge.dll
