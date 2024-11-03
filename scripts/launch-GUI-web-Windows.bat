@ECHO OFF
SET SCRIPTDIR=%~dp0.
cd "%SCRIPTDIR%"
cli\sc4pac.bat server --port 51515 --profiles-dir profiles --web-app-dir webapp --auto-shutdown=true %*
