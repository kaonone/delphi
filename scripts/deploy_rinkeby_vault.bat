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
SET EXT_TOKEN_WETH=
SET EXT_TOKEN_UNISWAP_CRV_WETH=


rem ===== Curve.Fi ====
SET EXT_CURVEFY_Y_DEPOSIT=0xd91fB51f8a0f44CB094548e9aaB80136731939fE
SET EXT_CURVEFY_Y_MINTER=0x1c1f8D0F00d8e3c004d5b4Fad482B94887227bEA
SET EXT_CURVEFY_Y_GAUGE=0x2cbc5d838883598ad8523b817f7edde25d2cc76e

rem ==== Akropolis ====
SET MODULE_POOL=0x6CEEd89849f5890392D7c2Ecb429888e2123E99b
SET MODULE_ACCESS=0xbFC891b6c83b36aFC9493957065D304661c4189A
SET MODULE_VAULT_SAVINGS=

SET MODULE_CURVE_STRATEGY=
SET POOL_TOKEN_CURVE_STRATEGY=

rem === GOTO REQUESTED OP===
if "%1" neq "" goto :%1
goto :done

rem === ACTIONS ===

:show
echo npx oz create VaultPoolToken --network rinkeby --init "initialize(address _pool, string memory poolName, string memory poolSymbol)" --args "%MODULE_POOL%,AkropolisCurveFiStrategy,adsCRV"
goto :done


:create
call npx oz create VaultSavingsModule --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create CurveFiStablecoinStrategy --network rinkeby --init "initialize(address _pool, address[] memory tokens, uint256 _daiInd)" --args "%MODULE_POOL%,[%EXT_TOKEN_DAI%,%EXT_TOKEN_USDC%,%EXT_TOKEN_USDT%,%EXT_TOKEN_TUSD%],0"
call npx oz create VaultPoolToken --network rinkeby --init "initialize(address _pool, string memory poolName, string memory poolSymbol)" --args "%MODULE_POOL%,AkropolisCurveFiStrategy,adsCRV"
goto :done

:setup
call npx oz send-tx --to %MODULE_POOL% --network rinkeby --method set --args "vault, %MODULE_VAULT_SAVINGS%, false"
call npx oz send-tx --to %MODULE_POOL% --network rinkeby --method set --args "strategy, %MODULE_CURVE_STRATEGY%, false"

call npx oz send-tx --to %MODULE_CURVE_STRATEGY% --network rinkeby --method setProtocol --args "%EXT_CURVEFY_Y_DEPOSIT%,%EXT_CURVEFY_Y_GAUGE%,%EXT_CURVEFY_Y_MINTER%,%EXT_TOKEN_UNISWAP_CRV_WETH%,%EXT_TOKEN_WETH%"
call npx oz send-tx --to %MODULE_CURVE_STRATEGY% --network rinkeby --method addDefiOperator --args %MODULE_VAULT_SAVINGS%

call npx oz send-tx --to %POOL_TOKEN_CURVE_STRATEGY% --network rinkeby --method addMinter --args %MODULE_VAULT_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_CURVE_STRATEGY% --network rinkeby --method addMinter --args %MODULE_CURVE_STRATEGY%
goto :done

:setup2
call npx oz send-tx --to %MODULE_VAULT_SAVINGS% --network rinkeby --method registerProtocol --args "%MODULE_CURVE_STRATEGY%,%POOL_TOKEN_CURVE_STRATEGY%"
goto :done


:done
echo DONE