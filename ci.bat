@echo off

call mvn -B verify
if errorlevel 1 exit /b 1

if not exist target\hello.jar exit /b 1

java -jar target\hello.jar
if errorlevel 1 exit /b 1

exit /b 0
