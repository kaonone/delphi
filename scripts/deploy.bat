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
SET MODULE_POOL=0x8538Cf86d777484551D6bc8140e4fC35c155Bdc2
SET MODULE_ACCESS=0x0B80CBfE5E1d7061Ea0927103796985652E0a32f
SET MODULE_SAVINGS=0xF5402dDA4C904AbfF40Bc2A7A133980785F59780
SET MODULE_STAKING=0x14d5e052965A243C3B4B140E72FB5F69268D4828

SET PROTOCOL_CURVEFY_Y=0x2c1e51FB4D01B50A5b1a97E3f5Cd4195119a153C
SET POOL_TOKEN_CURVEFY_Y=0xF92Ad527Bb3c13ee164Cb63bD77A1bA46E2f391D

SET PROTOCOL_CURVEFY_SBTC=0x12e28e53E8A988d8D2B1eEf4BFFfD975F50786C1
SET POOL_TOKEN_CURVEFY_SBTC=0xA9Dd6DDeD616685E267CF838f62C3Abaa1Fa5B2e

SET PROTOCOL_CURVEFY_SUSD=0xD41D0d908AFAcaCD66168cCa39dff65717FaAB66
SET POOL_TOKEN_CURVEFY_SUSD=0x29f573462B6c443Fe0e6f90a4bd44192AF57716f

SET PROTOCOL_COMPOUND_DAI=0x8096962Bd35deDc8c2AfC7C5433db083f79F10Da
SET POOL_TOKEN_COMPOUND_DAI=0x312A3779f6e57Cd9AFE168883f699B0ab7dE96a0

SET PROTOCOL_COMPOUND_USDC=0xb55c7880683fa742576053cF9B49Ad4d1D39d0f2
SET POOL_TOKEN_COMPOUND_USDC=0xee49ED50Ad0B1102001743bE3D4263acA7AB11aa

rem === ACTION ===
goto :done

:init
echo INIT PROJECT, ADD CONTRACTS
call npx oz init
call npx oz add Pool AccessModule SavingsModule
call npx oz add CurveFiProtocol_Y PoolToken_CurveFiY
call npx oz add CurveFiProtocol_SBTC PoolToken_CurveFi_SBTC
call npx oz add CurveFiProtocol_SUSD PoolToken_CurveFi_SUSD
call npx oz add CompoundProtocol_DAI PoolToken_Compound_DAI
call npx oz add CompoundProtocol_USDC PoolToken_Compound_USDC
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
echo CREATE Curve.Fi Y
call npx oz create CurveFiProtocol_Y --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create PoolToken_CurveFi_Y --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Curve.Fi SBTC
call npx oz create CurveFiProtocol_SBTC --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create PoolToken_CurveFi_SBTC --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Curve.Fi SUSD
call npx oz create CurveFiProtocol_SUSD --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create PoolToken_CurveFi_SUSD --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Compound DAI
call npx oz create CompoundProtocol_DAI --network rinkeby --init "initialize(address _pool, address _token, address _cToken, address _comptroller)" --args "%MODULE_POOL%, %EXT_TOKEN_DAI%, %EXT_COMPOUND_CTOKEN_DAI%, %EXT_COMPOUND_COMPTROLLER%"
call npx oz create PoolToken_Compound_DAI --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Compound USDC
call npx oz create CompoundProtocol_USDC --network rinkeby --init "initialize(address _pool, address _token, address _cToken, address _comptroller)" --args "%MODULE_POOL%, %EXT_TOKEN_USDC%, %EXT_COMPOUND_CTOKEN_USDC%, %EXT_COMPOUND_COMPTROLLER%"
call npx oz create PoolToken_Compound_USDC --network rinkeby --init "initialize(address _pool)" --args %MODULE_POOL%
goto :done

:setupContracts
echo SETUP POOL: CALL FOR ALL MODULES (set)
npx oz send-tx --to %MODULE_POOL% --network rinkeby --method set --args "access, %MODULE_ACCESS%, false"
npx oz send-tx --to %MODULE_POOL% --network rinkeby --method set --args "savings, %MODULE_SAVINGS%, false"
npx oz send-tx --to %MODULE_POOL% --network rinkeby --method set --args "staking, %MODULE_STAKING%, false"
echo SETUP OTHER CONTRACTS
call npx oz send-tx --to %PROTOCOL_CURVEFY_Y% --network rinkeby --method setCurveFi --args "%EXT_CURVEFY_Y_DEPOSIT%, %EXT_CURVEFY_Y_REWARDS%"
call npx oz send-tx --to %PROTOCOL_CURVEFY_SBTC% --network rinkeby --method setCurveFi --args "%EXT_CURVEFY_SBTC_DEPOSIT%, %EXT_CURVEFY_SBTC_REWARDS%"
call npx oz send-tx --to %PROTOCOL_CURVEFY_SUSD% --network rinkeby --method setCurveFi --args "%EXT_CURVEFY_SUSD_DEPOSIT%, %EXT_CURVEFY_SUSD_REWARDS%"
call npx oz send-tx --to %MODULE_SAVINGS% --network rinkeby --method registerProtocol --args "%PROTOCOL_CURVEFY_Y%, %POOL_TOKEN_CURVEFY_Y%"
call npx oz send-tx --to %MODULE_SAVINGS% --network rinkeby --method registerProtocol --args "%PROTOCOL_CURVEFY_SBTC%, %POOL_TOKEN_CURVEFY_SBTC%"
call npx oz send-tx --to %MODULE_SAVINGS% --network rinkeby --method registerProtocol --args "%PROTOCOL_CURVEFY_SUSD%, %POOL_TOKEN_CURVEFY_SUSD%"
call npx oz send-tx --to %MODULE_SAVINGS% --network rinkeby --method registerProtocol --args "%PROTOCOL_COMPOUND_DAI%, %POOL_TOKEN_COMPOUND_DAI%"
call npx oz send-tx --to %MODULE_SAVINGS% --network rinkeby --method registerProtocol --args "%PROTOCOL_COMPOUND_USDC%, %POOL_TOKEN_COMPOUND_USDC%"
goto :done

:setupOperators
echo SETUP PROTOCOLS
call npx oz send-tx --to %PROTOCOL_CURVEFY_Y% --network rinkeby --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %PROTOCOL_CURVEFY_SBTC% --network rinkeby --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %PROTOCOL_CURVEFY_SUSD% --network rinkeby --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %PROTOCOL_COMPOUND_DAI% --network rinkeby --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %PROTOCOL_COMPOUND_USDC% --network rinkeby --method addDefiOperator --args %MODULE_SAVINGS%
echo SETUP POOL TOKENS
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_Y% --network rinkeby --method addMinter --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_SBTC% --network rinkeby --method addMinter --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_SUSD% --network rinkeby --method addMinter --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_COMPOUND_DAI% --network rinkeby --method addMinter --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_COMPOUND_USDC% --network rinkeby --method addMinter --args %MODULE_SAVINGS%
goto :done

:done
echo DONE