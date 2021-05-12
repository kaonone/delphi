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
SET EXT_CURVEFY_Y_MINTER=0x5D347D43dDFD84d6DEa281caDc86Aa9Cce0C715E
SET EXT_CURVEFY_Y_GAUGE=0x39de848e1915378F25df29Cb34C41604529bCEc4

rem ==== Akropolis ====
SET MODULE_POOL=0x6CEEd89849f5890392D7c2Ecb429888e2123E99b
SET MODULE_ACCESS=0xbFC891b6c83b36aFC9493957065D304661c4189A

SET MODULE_VAULT_SAVINGS=0xA0ce47C8072C0eAA5d0E343b7aE533e0E377c0F7
SET VAULT_PROTOCOL_CURVE=0x181A9a2bC318F1748437089c1Fc7543e449B99B4
SET STRATEGY_CURVE=0x6cd11F017015475Ff08f3e547a45f99AE15081c9
SET POOL_TOKEN_VAULT_CURVE=0x6D205cf0d2A71F687AE727c17768703a9c7A7ADD

rem ==== Roles ====
SET VAULT_OPERATOR_01=0x5D507818B52A891fe296463adC01EeD9C51e218b
SET VAULT_OPERATOR_02=0x98f0D2dDB5262202E95666e646775FcC773B8C02 


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
call npx oz send-tx --to %MODULE_VAULT_SAVINGS% --network rinkeby --method addVaultOperator --args %VAULT_OPERATOR_01%
call npx oz send-tx --to %MODULE_VAULT_SAVINGS% --network rinkeby --method addVaultOperator --args %VAULT_OPERATOR_02%
call npx oz send-tx --to %POOL_TOKEN_VAULT_CURVE% --network rinkeby --method addMinter --args %VAULT_OPERATOR_02%
rem call npx oz send-tx --to %STRATEGY_CURVE% --network rinkeby --method addDefiOperator --args %VAULT_OPERATOR%
goto :done

:done
echo DONE