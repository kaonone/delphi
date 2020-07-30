@echo off
rem === DEFINE MODULES ===

SET EXT_TOKEN_DAI=0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa
SET EXT_COMPOUND_CTOKEN_DAI=0x6D7F0754FFeb405d23C51CE938289d4835bE3b14
SET EXT_COMPOUND_COMPTROLLER=0xD9580ad2bE0013A3a8187Dc29B3F63CDC522Bde7
SET EXT_CURVEFY_Y_DEPOSIT=0x31191Ad863e842C212A40CFaa47D8108Ad35C8B2
SET EXT_CURVEFY_Y_REWARDS=0xf89fA9449058C1802eAf9d544A4a7c06585C4D0A

SET MODULE_POOL=0x1A37Ecaff088011697C7E6C30E9D6ab5A466e5eF
SET MODULE_ACCESS=0x2F04a1Ed74a24c6168bB746a2403c06a3Fe3E17F
SET MODULE_SAVINGS=0x2C6c379F44e9e929F206D115C9d1cd9c2be41562

SET PROTOCOL_CURVEFY_Y=0x0c2F04439B94d0558a76FaAd119e42c64dd7952C
SET POOL_TOKEN_CURVEFY_Y=0xD958eC02c08388AfBdf26C876F0f8F7826dE9f27

SET PROTOCOL_COMPOUND_DAI=0xf5D9a6780e2efdB33241488ceE9D4cde50DFA439
SET POOL_TOKEN_COMPOUND_DAI=0x9C0edE89952C74aC818439c6862573f7Ba04041B

rem === ACTION ===
goto :setupOperators

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
call npx oz create CompoundProtocol_DAI --network rinkeby --init "initialize(address _pool, address _token, address _cToken, address _comptroller)" --args "%MODULE_POOL%, %EXT_TOKEN_DAI%, %EXT_COMPOUND_CTOKEN_DAI%, %EXT_COMPOUND_COMPTROLLER%"
call npx oz create PoolToken_Compound_DAI --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
goto :done

:setupContracts
echo SETUP POOL: CALL FOR ALL MODULES (set)
call npx oz send-tx --to %MODULE_POOL% --network rinkeby --method set --args "access, %MODULE_ACCESS%, false"
call npx oz send-tx --to %MODULE_POOL% --network rinkeby --method set --args "savings, %MODULE_SAVINGS%, false"
echo SETUP OTHER CONTRACTS
call npx oz send-tx --to %PROTOCOL_CURVEFY_Y% --network rinkeby --method setCurveFi --args "%EXT_CURVEFY_Y_DEPOSIT%, %EXT_CURVEFY_Y_REWARDS%"
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