@echo off
rem === DEFINE MODULES ===
rem ==== External ====

rem ===== Tokens ====
SET EXT_TOKEN_DAI=0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa
SET EXT_TOKEN_USDC=0x4DBCdF9B62e891a7cec5A2568C3F4FAF9E8Abe2b
SET EXT_TOKEN_USDT=0xD9BA894E0097f8cC2BBc9D24D308b98e36dc6D02
SET EXT_TOKEN_TUSD=0xe7dB8abd6e2c15a39C4AA15A136E48F9B7f8F1d0
SET EXT_TOKEN_AKRO=0xad7541B1E795656851caD5c70aA8d495063D9a95
SET EXT_TOKEN_ADEL=0x4d7af020D42D3E1a3C0CaE7A8e56127a05EF5e5f
SET EXT_TOKEN_WETH=0xc778417e063141139fce010982780140aa0cd5ab

rem ===== Dexag ====
SET EXT_DEXAG_PROXY=0x799236656Ed38def85A821bb3C7898BA3E2596BE

rem ===== Curve.Fi ====
SET EXT_CURVEFY_Y_DEPOSIT=0xe1d093026A770dd20013a8A163E554E7bE063A2F
SET EXT_CURVEFY_Y_MINTER=0x09f6ed0bA8cD328Ff73A903CA60C8065DC513dCA
SET EXT_CURVEFY_Y_GAUGE=0x785D38FBd4CFD193De7a3A2289f1a6795d742B12

rem ==== Akropolis ====
SET MODULE_POOL=0x6CEEd89849f5890392D7c2Ecb429888e2123E99b
SET MODULE_ACCESS=0xbFC891b6c83b36aFC9493957065D304661c4189A

SET MODULE_VAULT_SAVINGS=0x3Dc1076f4fef5e25788bB63029D1BD7826d4666C
SET VAULT_CURVE=0xD79Ae708Af5442b9525039E4a40eA532BfC5580C
SET STRATEGY_CURVE=0xF73f6443eD375F0a736D9f9a0F196Ab6814BC68F
SET POOL_TOKEN_VAULT_CURVE=0x52Ea24E265D1686Eb8E3f95a9CD8D97acfb0e8EA

rem === GOTO REQUESTED OP===
if "%1" neq "" goto :%1
goto :done

rem === ACTIONS ===
:show
goto :done

:create
call npx oz create VaultSavingsModule --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create VaultProtocol --network rinkeby --init "initialize(address _pool, address[] memory tokens)" --args "%MODULE_POOL%,[%EXT_TOKEN_DAI%,%EXT_TOKEN_USDC%,%EXT_TOKEN_USDT%,%EXT_TOKEN_TUSD%]"
call npx oz create CurveFiStablecoinStrategy --network rinkeby --init "initialize(address _pool, string memory _strategyId)" --args "%MODULE_POOL%,CRV-UNI-DAI"
call npx oz create PoolToken_Vault_CurveFi --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
goto :done

:setup
call npx oz send-tx --to %MODULE_POOL% --network rinkeby --method set --args "vault, %MODULE_VAULT_SAVINGS%, false"
call npx oz send-tx --to %VAULT_CURVE% --network rinkeby --method addDefiOperator --args %MODULE_VAULT_SAVINGS%
call npx oz send-tx --to %STRATEGY_CURVE% --network rinkeby --method setProtocol --args "%EXT_CURVEFY_Y_DEPOSIT%,%EXT_CURVEFY_Y_GAUGE%,%EXT_CURVEFY_Y_MINTER%,%EXT_DEXAG_PROXY%"
call npx oz send-tx --to %STRATEGY_CURVE% --network rinkeby --method addDefiOperator --args %VAULT_CURVE%
call npx oz send-tx --to %VAULT_CURVE% --network rinkeby --method registerStrategy --args %STRATEGY_CURVE%
call npx oz send-tx --to %VAULT_CURVE% --network rinkeby --method setQuickWithdrawStrategy --args %STRATEGY_CURVE%
call npx oz send-tx --to %POOL_TOKEN_VAULT_CURVE% --network rinkeby --method addMinter --args %MODULE_VAULT_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_VAULT_CURVE% --network rinkeby --method addMinter --args %VAULT_CURVE%
call npx oz send-tx --to %MODULE_VAULT_SAVINGS% --network rinkeby --method registerVault --args "%VAULT_CURVE%,%POOL_TOKEN_VAULT_CURVE%"
goto :done


:done
echo DONE