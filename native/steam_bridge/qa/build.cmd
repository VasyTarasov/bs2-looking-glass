@echo off
if "%~1"=="" exit /b 2
if not exist "%~f1\test_prepare_profile.json" exit /b 3
where cl.exe >nul 2>nul
if errorlevel 1 exit /b 4
pushd "%~f1"
cl /nologo /LD /MT /O2 /EHsc "%~dp0input_qa.cpp" "%~dp0..\minhook\src\buffer.c" "%~dp0..\minhook\src\hook.c" "%~dp0..\minhook\src\trampoline.c" "%~dp0..\minhook\src\hde\hde32.c" /link /OUT:input_qa.dll user32.lib
popd
