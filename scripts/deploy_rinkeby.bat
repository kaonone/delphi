@echo off
rem === DEFINE MODULES ===
rem ==== External ====

rem ===== Tokens ====
SET EXT_TOKEN_DAI=0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa
SET EXT_TOKEN_USDC=0x4DBCdF9B62e891a7cec5A2568C3F4FAF9E8Abe2b
SET EXT_TOKEN_AKRO=0xad7541B1E795656851caD5c70aA8d495063D9a95

rem ===== Compound ====
SET EXT_COMPOUND_CTOKEN_DAI=0x6D7F0754FFeb405d23C51CE938289d4835bE3b14
SET EXT_COMPOUND_CTOKEN_USDC=0x5B281A6DdA0B271e91ae35DE655Ad301C976edb1
SET EXT_COMPOUND_COMPTROLLER=0xD9580ad2bE0013A3a8187Dc29B3F63CDC522Bde7

rem ===== Curve.Fi ====
SET EXT_CURVEFY_Y_DEPOSIT=0xE58e27F0D7aADF7857dbC50f9f471eFa54E15178
SET EXT_CURVEFY_Y_REWARDS=0x3a24cd58e76b11c5d8fd48215c721e8aa885b1d8
SET EXT_CURVEFY_SBTC_DEPOSIT=0xE639834AC3EBd7a24263eD5BdC38213bb4a8fdC6
SET EXT_CURVEFY_SBTC_REWARDS=0x69f60335b0ead20169ef3bfd94cce73ce03b8c3e
SET EXT_CURVEFY_SUSD_DEPOSIT=0x627E0ca4c14299ACE0383fC9CBb57634ef843499
SET EXT_CURVEFY_SUSD_REWARDS=0x716312d5176aC683953d54773B87A6001e449fD6

rem ==== Akropolis ====
SET MODULE_POOL=0x6CEEd89849f5890392D7c2Ecb429888e2123E99b
SET MODULE_ACCESS=0xbFC891b6c83b36aFC9493957065D304661c4189A
SET MODULE_SAVINGS=0xb733994019A4F55CAa3f130400B7978Cc6624c39
SET MODULE_STAKING=0x6887DF2f4296e8B772cb19479472A16E836dB9e0

SET PROTOCOL_CURVEFY_Y=0x1b19B5AE07b9414687A58BE6be9881641FB5F771
SET POOL_TOKEN_CURVEFY_Y=0x84857Bb64950e7BC2DfEB8Cb69fb75F3f7512E8E

SET PROTOCOL_CURVEFY_SBTC=
SET POOL_TOKEN_CURVEFY_SBTC=

SET PROTOCOL_CURVEFY_SUSD=0x3A52c1BB8651d8a73Ebf9E569AE5fe9b558Fcde1
SET POOL_TOKEN_CURVEFY_SUSD=0x0ecaf0f8A287aC68dB7D45C65b4B15c0889cA819

SET PROTOCOL_COMPOUND_DAI=0x853D71180E6bA6584f3D400b21E4aEe2463129A4
SET POOL_TOKEN_COMPOUND_DAI=0x06C2119701B0034BFaC3Be3C65DAc35054404571

SET PROTOCOL_COMPOUND_USDC=0x048E645BA2965F48d72e7b855D6636F951aeD303
SET POOL_TOKEN_COMPOUND_USDC=0x551AaBC00A7d02b51A81138fb8fA455786720793

rem === ACTION ===
echo call npx oz send-tx --to %PROTOCOL_CURVEFY_Y% --network rinkeby --method setCurveFi --args "%EXT_CURVEFY_Y_DEPOSIT%, %EXT_CURVEFY_Y_REWARDS%"
echo call npx oz send-tx --to %MODULE_SAVINGS% --network rinkeby --method registerProtocol --args "%PROTOCOL_CURVEFY_Y%, %POOL_TOKEN_CURVEFY_Y%"
echo call npx oz send-tx --to %PROTOCOL_CURVEFY_Y% --network rinkeby --method addDefiOperator --args %MODULE_SAVINGS%
echo call npx oz send-tx --to %POOL_TOKEN_CURVEFY_Y% --network rinkeby --method addMinter --args %MODULE_SAVINGS%
goto :done

:init
echo INIT PROJECT, ADD CONTRACTS
rem call npx oz init
call npx oz add Pool AccessModule SavingsModule StakingPool
call npx oz add CompoundProtocol_DAI PoolToken_Compound_DAI
call npx oz add CompoundProtocol_USDC PoolToken_Compound_USDC
rem call npx oz add CurveFiProtocol_Y PoolToken_CurveFiY
rem call npx oz add CurveFiProtocol_SBTC PoolToken_CurveFi_SBTC
call npx oz add CurveFiProtocol_SUSD PoolToken_CurveFi_SUSD
goto :done

:createPool
echo CREATE POOL
call npx oz create Pool --network rinkeby --init
goto :done

:createModules
echo CREATE MODULES
call npx oz create AccessModule --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create SavingsModule --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create StakingPool --network rinkeby --init "initialize(address _pool,address _stakingToken, uint256 _defaultLockInDuration)" --args "%MODULE_POOL%, %EXT_TOKEN_AKRO%, 0"
echo CREATE PROTOCOLS AND TOKENS
echo CREATE Compound DAI
call npx oz create CompoundProtocol_DAI --network rinkeby --init "initialize(address _pool, address _token, address _cToken, address _comptroller)" --args "%MODULE_POOL%, %EXT_TOKEN_DAI%, %EXT_COMPOUND_CTOKEN_DAI%, %EXT_COMPOUND_COMPTROLLER%"
call npx oz create PoolToken_Compound_DAI --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Compound USDC
call npx oz create CompoundProtocol_USDC --network rinkeby --init "initialize(address _pool, address _token, address _cToken, address _comptroller)" --args "%MODULE_POOL%, %EXT_TOKEN_USDC%, %EXT_COMPOUND_CTOKEN_USDC%, %EXT_COMPOUND_COMPTROLLER%"
call npx oz create PoolToken_Compound_USDC --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Curve.Fi Y
call npx oz create CurveFiProtocol_Y --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create PoolToken_CurveFi_Y --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
rem echo CREATE Curve.Fi SBTC
rem call npx oz create CurveFiProtocol_SBTC --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
rem call npx oz create PoolToken_CurveFi_SBTC --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Curve.Fi SUSD
call npx oz create CurveFiProtocol_SUSD --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create PoolToken_CurveFi_SUSD --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
goto :done

:empty
rem fixes "can not find addModules" error 
goto :done

:addModules
echo SETUP POOL: CALL FOR ALL MODULES (set)
call npx oz send-tx --to %MODULE_POOL% --network rinkeby --method set --args "access, %MODULE_ACCESS%, false"
call npx oz send-tx --to %MODULE_POOL% --network rinkeby --method set --args "savings, %MODULE_SAVINGS%, false"
call npx oz send-tx --to %MODULE_POOL% --network rinkeby --method set --args "staking, %MODULE_STAKING%, false"
goto :done

:setupProtocols
echo SETUP OTHER CONTRACTS
rem call npx oz send-tx --to %PROTOCOL_CURVEFY_Y% --network rinkeby --method setCurveFi --args "%EXT_CURVEFY_Y_DEPOSIT%, %EXT_CURVEFY_Y_REWARDS%"
rem call npx oz send-tx --to %PROTOCOL_CURVEFY_SBTC% --network rinkeby --method setCurveFi --args "%EXT_CURVEFY_SBTC_DEPOSIT%, %EXT_CURVEFY_SBTC_REWARDS%"
call npx oz send-tx --to %PROTOCOL_CURVEFY_SUSD% --network rinkeby --method setCurveFi --args "%EXT_CURVEFY_SUSD_DEPOSIT%, %EXT_CURVEFY_SUSD_REWARDS%"
goto :done

:addProtocols
echo ADD PROTOCOLS
call npx oz send-tx --to %MODULE_SAVINGS% --network rinkeby --method registerProtocol --args "%PROTOCOL_COMPOUND_DAI%, %POOL_TOKEN_COMPOUND_DAI%"
call npx oz send-tx --to %MODULE_SAVINGS% --network rinkeby --method registerProtocol --args "%PROTOCOL_COMPOUND_USDC%, %POOL_TOKEN_COMPOUND_USDC%"
rem call npx oz send-tx --to %MODULE_SAVINGS% --network rinkeby --method registerProtocol --args "%PROTOCOL_CURVEFY_Y%, %POOL_TOKEN_CURVEFY_Y%"
rem call npx oz send-tx --to %MODULE_SAVINGS% --network rinkeby --method registerProtocol --args "%PROTOCOL_CURVEFY_SBTC%, %POOL_TOKEN_CURVEFY_SBTC%"
call npx oz send-tx --to %MODULE_SAVINGS% --network rinkeby --method registerProtocol --args "%PROTOCOL_CURVEFY_SUSD%, %POOL_TOKEN_CURVEFY_SUSD%"
goto :done

:setupOperators
echo SETUP OPERATORS FOR PROTOCOLS
call npx oz send-tx --to %PROTOCOL_COMPOUND_DAI% --network rinkeby --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %PROTOCOL_COMPOUND_USDC% --network rinkeby --method addDefiOperator --args %MODULE_SAVINGS%
rem call npx oz send-tx --to %PROTOCOL_CURVEFY_Y% --network rinkeby --method addDefiOperator --args %MODULE_SAVINGS%
rem call npx oz send-tx --to %PROTOCOL_CURVEFY_SBTC% --network rinkeby --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %PROTOCOL_CURVEFY_SUSD% --network rinkeby --method addDefiOperator --args %MODULE_SAVINGS%
echo SETUP MINTERS FOR POOL TOKENS
call npx oz send-tx --to %POOL_TOKEN_COMPOUND_DAI% --network rinkeby --method addMinter --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_COMPOUND_USDC% --network rinkeby --method addMinter --args %MODULE_SAVINGS%
rem call npx oz send-tx --to %POOL_TOKEN_CURVEFY_Y% --network rinkeby --method addMinter --args %MODULE_SAVINGS%
rem call npx oz send-tx --to %POOL_TOKEN_CURVEFY_SBTC% --network rinkeby --method addMinter --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_SUSD% --network rinkeby --method addMinter --args %MODULE_SAVINGS%
goto :done

:done
echo DONE