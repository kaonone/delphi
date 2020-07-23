@echo off
rem === DEFINE MODULES ===

SET EXT_TOKEN_DAI=0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa
SET EXT_COMPOUND_CTOKEN_DAI=0x6D7F0754FFeb405d23C51CE938289d4835bE3b14
SET EXT_CURVEFY_Y_DEPOSIT=0x31191Ad863e842C212A40CFaa47D8108Ad35C8B2

SET MODULE_POOL=0x7F157C18D9b74fD6DC1792F905812C97d4eD1C4D
SET MODULE_ACCESS=0x25F80Ae760F8555EDF3a42fB3043b73C6A78D920
SET MODULE_SAVINGS=0xEbc77a8542Afd7340eAa584f5048c3045A11Dadf

SET PROTOCOL_CURVEFY_Y=0x675F893610c799Dd92d43BF6e793BbC68DC8d679
SET POOL_TOKEN_CURVEFY_Y=0x7766C241236690c0abCa88e2758a5C4395B59831

SET PROTOCOL_COMPOUND_DAI=0x53Cd3DB8AA9739B92C26779A4F6D67405B444657
SET POOL_TOKEN_COMPOUND_DAI=0xAdb69BAEE6514be4ba6d20376c5EFCDd72111Cb2

rem === ACTION ===
goto :setupContracts

:init
echo INIT PROJECT, ADD CONTRACTS
call npx oz init
call npx oz add Pool AccessModule SavingsModule
call npx oz add CurveFiYProtocol PoolToken_CurveFiY
call npx oz add CompoundProtocol_DAI PoolToken_Compound_DAI
goto :done

:createPool
echo CREATE POOL
call npx oz create Pool --network rinkeby --init
goto :done

:createModules
echo CREATE MODULES
call npx oz create AccessModule --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create SavingsModule --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE PROTOCOLS AND TOKENS
echo CREATE Curve.Fi Y
call npx oz create CurveFiYProtocol --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create PoolToken_CurveFiY --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Compound DAI
call npx oz create CompoundProtocol_DAI --network rinkeby --init "initialize(address _pool, address _token, address _cToken)" --args "%MODULE_POOL%, %EXT_TOKEN_DAI%, %EXT_COMPOUND_CTOKEN_DAI%"
call npx oz create PoolToken_Compound_DAI --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
goto :done

:setupContracts
echo SETUP POOL: CALL FOR ALL MODULES (set)
call npx oz send-tx --to %MODULE_POOL% --network rinkeby --method set --args "access, %MODULE_ACCESS%, false"
call npx oz send-tx --to %MODULE_POOL% --network rinkeby --method set --args "savings, %MODULE_SAVINGS%, false"
echo SETUP OTHER CONTRACTS
call npx oz send-tx --to %PROTOCOL_CURVEFY_Y% --network rinkeby --method setCurveFi --args %EXT_CURVEFY_Y_DEPOSIT%
call npx oz send-tx --to %MODULE_SAVINGS% --network rinkeby --method registerProtocol --args "%PROTOCOL_CURVEFY_Y%, %POOL_TOKEN_CURVEFY_Y%"
call npx oz send-tx --to %MODULE_SAVINGS% --network rinkeby --method registerProtocol --args "%PROTOCOL_COMPOUND_DAI%, %POOL_TOKEN_COMPOUND_DAI%"
goto :done

:setupOperators
echo SETUP PROTOCOLS
call npx oz send-tx --to %PROTOCOL_CURVEFY_Y% --network rinkeby --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %PROTOCOL_COMPOUND_DAI% --network rinkeby --method addDefiOperator --args %MODULE_SAVINGS%
echo SETUP POOL TOKENS
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_Y% --network rinkeby --method addMinter --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_COMPOUND_DAI% --network rinkeby --method addMinter --args %MODULE_SAVINGS%
goto :done

:done
echo DONE