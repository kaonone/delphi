@echo off
rem === DEFINE MODULES ===
rem ==== External ====

rem ===== Tokens ====
SET EXT_TOKEN_DAI=0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa
SET EXT_TOKEN_USDC=0x4DBCdF9B62e891a7cec5A2568C3F4FAF9E8Abe2b
SET EXT_TOKEN_USDT=0x3E3dff5157734D802116afb1F2b7b5578Ec47037
SET EXT_TOKEN_TUSD=0xe7dB8abd6e2c15a39C4AA15A136E48F9B7f8F1d0
SET EXT_TOKEN_AKRO=0xad7541B1E795656851caD5c70aA8d495063D9a95
SET EXT_TOKEN_ADEL=0x4d7af020D42D3E1a3C0CaE7A8e56127a05EF5e5f
SET EXT_TOKEN_WETH=0xc778417e063141139fce010982780140aa0cd5ab

rem ===== Dexag ====
SET EXT_DEXAG_PROXY=0x799236656Ed38def85A821bb3C7898BA3E2596BE

rem ===== Curve.Fi ====
SET EXT_CURVEFY_Y_DEPOSIT=0xEa5Ec001f0cC9520c114a6d197AF95B888A75C78
SET EXT_CURVEFY_Y_MINTER=0x09f6ed0bA8cD328Ff73A903CA60C8065DC513dCA
SET EXT_CURVEFY_Y_GAUGE=0xF8AB862498e746dFDD9dB3caA09fD13c634C7E2C

rem ==== Akropolis ====
SET MODULE_POOL=0x6CEEd89849f5890392D7c2Ecb429888e2123E99b
SET MODULE_ACCESS=0xbFC891b6c83b36aFC9493957065D304661c4189A

SET MODULE_VAULT_SAVINGS=0xFe82759ae7c1E64A4fDC345bf98529B4267C2994
SET VAULT_PROTOCOL_CURVE=0x7A4619fD8DD9D1d5d4d55bf5385E31496998939C
SET STRATEGY_CURVE=0x393b31207905166F15B4F1D28091cF22C8290A6b
SET POOL_TOKEN_VAULT_CURVE=0x9eaCf1fA9283344561F7b6E0a3914f56435d90bf

rem ==== Roles ====
SET VAULT_OPERATOR=0x5D507818B52A891fe296463adC01EeD9C51e218b


rem === GOTO REQUESTED OP===
if "%1" neq "" goto :%1
goto :done

rem === ACTIONS ===
:show
goto :done

:create
call truffle compile --all
call npx oz create VaultSavingsModule --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL% --skip-compile
call npx oz create VaultProtocolCurveFi --network rinkeby --init "initialize(address _pool, address[] memory tokens)" --args "%MODULE_POOL%,[%EXT_TOKEN_DAI%,%EXT_TOKEN_USDC%,%EXT_TOKEN_USDT%,%EXT_TOKEN_TUSD%]" --skip-compile
call npx oz create CurveFiStablecoinStrategy --network rinkeby --init "initialize(address _pool, string memory _strategyId)" --args "%MODULE_POOL%,""CRV-DEXAG-DAI""" --skip-compile
call npx oz create PoolToken_Vault_CurveFi --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL% --skip-compile
goto :done

:setup
call npx oz send-tx --to %MODULE_POOL% --network rinkeby --method set --args "vault, %MODULE_VAULT_SAVINGS%, false"
call npx oz send-tx --to %STRATEGY_CURVE% --network rinkeby --method setProtocol --args "%EXT_CURVEFY_Y_DEPOSIT%,%EXT_CURVEFY_Y_GAUGE%,%EXT_CURVEFY_Y_MINTER%,%EXT_DEXAG_PROXY%"
call npx oz send-tx --to %STRATEGY_CURVE% --network rinkeby --method addDefiOperator --args %VAULT_PROTOCOL_CURVE%
call npx oz send-tx --to %STRATEGY_CURVE% --network rinkeby --method addDefiOperator --args %MODULE_VAULT_SAVINGS%
call npx oz send-tx --to %VAULT_PROTOCOL_CURVE% --network rinkeby --method addDefiOperator --args %MODULE_VAULT_SAVINGS%
call npx oz send-tx --to %VAULT_PROTOCOL_CURVE% --network rinkeby --method registerStrategy --args %STRATEGY_CURVE%
call npx oz send-tx --to %VAULT_PROTOCOL_CURVE% --network rinkeby --method setQuickWithdrawStrategy --args %STRATEGY_CURVE%
call npx oz send-tx --to %POOL_TOKEN_VAULT_CURVE% --network rinkeby --method addMinter --args %MODULE_VAULT_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_VAULT_CURVE% --network rinkeby --method addMinter --args %VAULT_PROTOCOL_CURVE%
call npx oz send-tx --to %MODULE_VAULT_SAVINGS% --network rinkeby --method registerVault --args "%VAULT_PROTOCOL_CURVE%,%POOL_TOKEN_VAULT_CURVE%"
call npx oz send-tx --to %MODULE_VAULT_SAVINGS% --network rinkeby --method setVaultRemainder --args "%VAULT_PROTOCOL_CURVE%,1000000,0"
call npx oz send-tx --to %MODULE_VAULT_SAVINGS% --network rinkeby --method setVaultRemainder --args "%VAULT_PROTOCOL_CURVE%,1000000,1"
call npx oz send-tx --to %MODULE_VAULT_SAVINGS% --network rinkeby --method setVaultRemainder --args "%VAULT_PROTOCOL_CURVE%,1000000,2"
call npx oz send-tx --to %MODULE_VAULT_SAVINGS% --network rinkeby --method setVaultRemainder --args "%VAULT_PROTOCOL_CURVE%,1000000,3"
goto :done

:setupOperator
call npx oz send-tx --to %MODULE_VAULT_SAVINGS% --network rinkeby --method addVaultOperator --args %VAULT_OPERATOR%
call npx oz send-tx --to %STRATEGY_CURVE% --network rinkeby --method addDefiOperator --args %VAULT_OPERATOR%
goto :done

:done
echo DONE