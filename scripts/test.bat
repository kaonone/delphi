@ECHO OFF
SETLOCAL

rem CD akropolisOS
SET ganache_port=8545
SET GAS_REPORTER=true

FOR /F "tokens=5" %%i IN ('netstat -aon ^| findstr %ganache_port%.*LISTENING') DO SET pid=%%i
IF "%pid%" == "" (
    START npx ganache-cli --gasLimit 0xfffffffffff -e 10000000 --port %ganache_port%
	rem START npx ganache-cli --allowUnlimitedContractSize --gasLimit 0xfffffffffff -e 10000000 --port %ganache_port%
    FOR /F "tokens=5" %%i IN ('netstat -aon ^| findstr %ganache_port%.*LISTENING') DO SET pid=%%i
    ECHO Ganache is running on port %ganache_port% with PID %pid%
) ELSE (
    ECHO Gahache is already on port %ganache_port% running with PID %pid%
)

CALL npx truffle compile --all
if %ERRORLEVEL% GEQ 1 GOTO end
rem CALL npx typechain --target truffle .\build\contracts\*.json
CALL npm run generate-types
if %ERRORLEVEL% GEQ 1 GOTO end
CALL npx truffle-abi -o ./abi
if %ERRORLEVEL% GEQ 1 GOTO end
CALL npx truffle test

:end
REM taskkill /f /PID %pid%

rem CD ..
ENDLOCAL