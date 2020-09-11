@echo off
rem === DEFINE MODULES ===
rem ==== External ====

rem ===== Tokens ====
SET EXT_TOKEN_DAI=0x6b175474e89094c44da98b954eedeac495271d0f
SET EXT_TOKEN_USDC=0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48
SET EXT_TOKEN_SUSD=0x57Ab1ec28D129707052df4dF418D58a2D46d5f51
SET EXT_TOKEN_BUSD=0x4Fabb145d64652a948d72533023f6E7A623C7C53
SET EXT_TOKEN_AKRO=0x8ab7404063ec4dbcfd4598215992dc3f8ec853d7
SET EXT_TOKEN_ADEL=0x94d863173EE77439E4292284fF13fAD54b3BA182

rem ===== Compound ====
SET EXT_COMPOUND_CTOKEN_DAI=0x5d3a536e4d6dbd6114cc1ead35777bab948e3643
SET EXT_COMPOUND_CTOKEN_USDC=0x39aa39c021dfbae8fac545936693ac917d5e7563
SET EXT_COMPOUND_COMPTROLLER=0x3d9819210a31b4961b30ef54be2aed79b9c9cd3b

rem ===== Curve.Fi ====
SET EXT_CURVEFY_Y_DEPOSIT=0xbBC81d23Ea2c3ec7e56D39296F0cbB648873a5d3
SET EXT_CURVEFY_Y_GAUGE=0xFA712EE4788C042e2B7BB55E6cb8ec569C4530c1
SET EXT_CURVEFY_SUSD_DEPOSIT=0xFCBa3E75865d2d561BE8D220616520c171F12851
SET EXT_CURVEFY_SUSD_GAUGE=0xa90996896660decc6e997655e065b23788857849
SET EXT_CURVEFY_BUSD_DEPOSIT=0xb6c057591E073249F2D9D88Ba59a46CFC9B59EdB
SET EXT_CURVEFY_BUSD_GAUGE=0x69Fb7c45726cfE2baDeE8317005d3F94bE838840
SET EXT_CURVEFY_SBTC_SWAP=0x7fC77b5c7614E1533320Ea6DDc2Eb61fa00A9714
SET EXT_CURVEFY_SBTC_GAUGE=0x705350c4BcD35c9441419DdD5d2f097d7a55410F

rem ===== AAVE ====
SET EXT_AAVE_ADDRESS_PROVIDER=0x24a42fD28C976A61Df5D00D0599C34c4f90748c8
SET EXT_AAVE_REFCODE=0

rem ==== Akropolis ====
SET MODULE_POOL=0x4C39b37f5F20a0695BFDC59cf10bd85a6c4B7c30
SET MODULE_ACCESS=0x5fFcf7da7BdC49CA8A2E7a542BD59dC38228Dd45
SET MODULE_SAVINGS=0x73fC3038B4cD8FfD07482b92a52Ea806505e5748
SET MODULE_INVESTING=0xF311b1258d0F245b85090e4Fb01f2277cB2328aD
SET MODULE_STAKING=0x3501Ec11d205fa249f2C42f5470e137b529b35D0
SET MODULE_STAKING_ADEL=0x1A547c3dd03c39Fb2b5aEaFC524033879bD28F13
SET MODULE_REWARD=0x2A9dcb9d79Aba0CC64565A87c9d20D11D1f33a07

SET PROTOCOL_CURVEFY_Y=0x7967adA2A32A633d5C055e2e075A83023B632B4e
SET POOL_TOKEN_CURVEFY_Y=0x2AFA3c8Bf33E65d5036cD0f1c3599716894B3077

SET PROTOCOL_CURVEFY_SBTC=0xEEEf30D50a7c6676B260a26A5fBe13e45fD7b5A9
SET POOL_TOKEN_CURVEFY_SBTC=0x933082B3D21a6ED90ed7EcA470Fd424Df5D21BEf

SET PROTOCOL_CURVEFY_SUSD=0x91d7b9a8d2314110D4018C88dBFDCF5E2ba4772E
SET POOL_TOKEN_CURVEFY_SUSD=0x520d25b08080296db66fd9f268ae279b66a8effb

SET PROTOCOL_CURVEFY_BUSD=0xEaE1A8206F68a7ef629e85fc69E82CFD36E83BA4
SET POOL_TOKEN_CURVEFY_BUSD=0x8367Af78444C5B57Bc1cF38dED331d03558e67Bb

SET PROTOCOL_COMPOUND_DAI=0x08DDB58D31C08242Cd444BB5B43F7d2C6bcA0396
SET POOL_TOKEN_COMPOUND_DAI=0x9Fca734Bb62C20D2cF654705b8fbf4F49FF5cC31

SET PROTOCOL_COMPOUND_USDC=0x9984D588EF2112894a0513663ba815310D383E3c
SET POOL_TOKEN_COMPOUND_USDC=0x5Ad76E93a3a852C9af760dA3FdB7983C265d8997

SET PROTOCOL_AAVE_SUSD=0xBED50F08B8e68293bd7Db742c4207F2F6E520cD2
SET POOL_TOKEN_AAVE_SUSD=0x8E2317458878B9223904BdD95173EE96D46feC77

SET PROTOCOL_AAVE_BUSD=0x051E3A47724740d47042Edc71C0AE81A35fDEDE9
SET POOL_TOKEN_AAVE_BUSD=0xb62B6B192524F6b220a08f0D5D0EB748A8cbAA1b

rem === GOTO REQUESTED OP===
if "%1" neq "" goto :%1
goto :done

rem === ACTION ===
:show
echo npx oz create RewardVestingModule --network mainnet --init "initialize(address _pool)" --args %MODULE_POOL%
echo npx oz send-tx --to %MODULE_POOL% --network mainnet --method set --args "reward, %MODULE_REWARD%, false"
echo npx oz send-tx --to %MODULE_POOL% --network mainnet --method set --args "akro, %EXT_TOKEN_AKRO%, false"
echo npx oz send-tx --to %MODULE_POOL% --network mainnet --method set --args "adel, %EXT_TOKEN_ADEL%, false"
goto :done

:init
echo INIT PROJECT, ADD CONTRACTS
call npx oz init
call npx oz add Pool AccessModule SavingsModule StakingPool
call npx oz add CompoundProtocol_DAI PoolToken_Compound_DAI
call npx oz add CompoundProtocol_USDC PoolToken_Compound_USDC
rem call npx oz add CurveFiProtocol_Y PoolToken_CurveFiY
rem call npx oz add CurveFiProtocol_SBTC PoolToken_CurveFi_SBTC
call npx oz add CurveFiProtocol_SUSD PoolToken_CurveFi_SUSD
call npx oz add CurveFiProtocol_BUSD PoolToken_CurveFi_BUSD
call npx oz add AaveProtocol_SUSD PoolToken_Aave_SUSD
call npx oz add AaveProtocol_BUSD PoolToken_Aave_BUSD
goto :done

:createPool
echo CREATE POOL
call npx oz create Pool --network mainnet --init
goto :done

:createModules
echo CREATE MODULES
call npx oz create AccessModule --network mainnet --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create SavingsModule --network mainnet --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create InvestingModule --network mainnet --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create StakingPool --network mainnet --init "initialize(address _pool,address _stakingToken, uint256 _defaultLockInDuration)" --args "%MODULE_POOL%, %EXT_TOKEN_AKRO%, 0"
call npx oz create StakingPoolADEL --network mainnet --init "initialize(address _pool,address _stakingToken, uint256 _defaultLockInDuration)" --args "%MODULE_POOL%, %EXT_TOKEN_ADEL%, 0"
call npx oz create RewardVestingModule --network mainnet --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE PROTOCOLS AND TOKENS
echo CREATE Compound DAI
call npx oz create CompoundProtocol_DAI --network mainnet --init "initialize(address _pool, address _token, address _cToken, address _comptroller)" --args "%MODULE_POOL%, %EXT_TOKEN_DAI%, %EXT_COMPOUND_CTOKEN_DAI%, %EXT_COMPOUND_COMPTROLLER%"
call npx oz create PoolToken_Compound_DAI --network mainnet --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Compound USDC
call npx oz create CompoundProtocol_USDC --network mainnet --init "initialize(address _pool, address _token, address _cToken, address _comptroller)" --args "%MODULE_POOL%, %EXT_TOKEN_USDC%, %EXT_COMPOUND_CTOKEN_USDC%, %EXT_COMPOUND_COMPTROLLER%"
call npx oz create PoolToken_Compound_USDC --network mainnet --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Curve.Fi Y
call npx oz create CurveFiProtocol_Y --network mainnet --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create PoolToken_CurveFi_Y --network mainnet --init "initialize(address _pool)" --args %MODULE_POOL%
rem echo CREATE Curve.Fi SBTC
rem call npx oz create CurveFiProtocol_SBTC --network mainnet --init "initialize(address _pool)" --args %MODULE_POOL%
rem call npx oz create PoolToken_CurveFi_SBTC --network mainnet --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Curve.Fi SUSD
call npx oz create CurveFiProtocol_SUSD --network mainnet --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create PoolToken_CurveFi_SUSD --network mainnet --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Curve.Fi BUSD
call npx oz create CurveFiProtocol_BUSD --network mainnet --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create PoolToken_CurveFi_BUSD --network mainnet --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Aave SUSD
call npx oz create AaveProtocol_SUSD --network mainnet --init "initialize(address _pool, address _token, address aaveAddressProvider, uint16 _aaveReferralCode)" --args "%MODULE_POOL%, %EXT_TOKEN_SUSD%, %EXT_AAVE_ADDRESS_PROVIDER%, %EXT_AAVE_REFCODE%"
call npx oz create PoolToken_Aave_SUSD --network mainnet --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Aave BUSD
call npx oz create AaveProtocol_BUSD --network mainnet --init "initialize(address _pool, address _token, address aaveAddressProvider, uint16 _aaveReferralCode)" --args "%MODULE_POOL%, %EXT_TOKEN_SUSD%, %EXT_AAVE_ADDRESS_PROVIDER%, %EXT_AAVE_REFCODE%"
call npx oz create PoolToken_Aave_BUSD --network mainnet --init "initialize(address _pool)" --args %MODULE_POOL%
goto :done

:empty
rem fixes "can not find addModules" error 
goto :done

:addModules
echo SETUP POOL: CALL FOR ALL MODULES (set)
call npx oz send-tx --to %MODULE_POOL% --network mainnet --method set --args "access, %MODULE_ACCESS%, false"
call npx oz send-tx --to %MODULE_POOL% --network mainnet --method set --args "savings, %MODULE_SAVINGS%, false"
call npx oz send-tx --to %MODULE_POOL% --network mainnet --method set --args "investing, %MODULE_INVESTING%, false"
call npx oz send-tx --to %MODULE_POOL% --network mainnet --method set --args "staking, %MODULE_STAKING%, false"
call npx oz send-tx --to %MODULE_POOL% --network mainnet --method set --args "stakingAdel, %MODULE_STAKING_ADEL%, false"
call npx oz send-tx --to %MODULE_POOL% --network mainnet --method set --args "reward, %MODULE_REWARD%, false"
call npx oz send-tx --to %MODULE_POOL% --network mainnet --method set --args "akro, %EXT_TOKEN_AKRO%, false"
call npx oz send-tx --to %MODULE_POOL% --network mainnet --method set --args "adel, %EXT_TOKEN_ADEL%, false"
goto :done

:setupProtocols
echo SETUP OTHER CONTRACTS
call npx oz send-tx --to %PROTOCOL_CURVEFY_Y% --network mainnet --method setCurveFi --args "%EXT_CURVEFY_Y_DEPOSIT%, %EXT_CURVEFY_Y_GAUGE%"
rem call npx oz send-tx --to %PROTOCOL_CURVEFY_SBTC% --network mainnet --method setCurveFi --args "%EXT_CURVEFY_SBTC_DEPOSIT%, %EXT_CURVEFY_SBTC_GAUGE%"
call npx oz send-tx --to %PROTOCOL_CURVEFY_SUSD% --network mainnet --method setCurveFi --args "%EXT_CURVEFY_SUSD_DEPOSIT%, %EXT_CURVEFY_SUSD_GAUGE%"
call npx oz send-tx --to %PROTOCOL_CURVEFY_BUSD% --network mainnet --method setCurveFi --args "%EXT_CURVEFY_BUSD_DEPOSIT%, %EXT_CURVEFY_BUSD_GAUGE%"
goto :done

:addProtocols
echo ADD PROTOCOLS
call npx oz send-tx --to %MODULE_SAVINGS% --network mainnet --method registerProtocol --args "%PROTOCOL_COMPOUND_DAI%, %POOL_TOKEN_COMPOUND_DAI%"
call npx oz send-tx --to %MODULE_SAVINGS% --network mainnet --method registerProtocol --args "%PROTOCOL_COMPOUND_USDC%, %POOL_TOKEN_COMPOUND_USDC%"
call npx oz send-tx --to %MODULE_SAVINGS% --network mainnet --method registerProtocol --args "%PROTOCOL_CURVEFY_Y%, %POOL_TOKEN_CURVEFY_Y%"
rem call npx oz send-tx --to %MODULE_INVESTING% --network mainnet --method registerProtocol --args "%PROTOCOL_CURVEFY_SBTC%, %POOL_TOKEN_CURVEFY_SBTC%"
call npx oz send-tx --to %MODULE_SAVINGS% --network mainnet --method registerProtocol --args "%PROTOCOL_CURVEFY_SUSD%, %POOL_TOKEN_CURVEFY_SUSD%"
call npx oz send-tx --to %MODULE_SAVINGS% --network mainnet --method registerProtocol --args "%PROTOCOL_CURVEFY_BUSD%, %POOL_TOKEN_CURVEFY_BUSD%"
call npx oz send-tx --to %MODULE_SAVINGS% --network mainnet --method registerProtocol --args "%PROTOCOL_AAVE_SUSD%, %POOL_TOKEN_AAVE_SUSD%"
call npx oz send-tx --to %MODULE_SAVINGS% --network mainnet --method registerProtocol --args "%PROTOCOL_AAVE_BUSD%, %POOL_TOKEN_AAVE_BUSD%"
goto :done

:setupOperators
echo SETUP OPERATORS FOR PROTOCOLS
call npx oz send-tx --to %PROTOCOL_COMPOUND_DAI% --network mainnet --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %PROTOCOL_COMPOUND_USDC% --network mainnet --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %PROTOCOL_CURVEFY_Y% --network mainnet --method addDefiOperator --args %MODULE_SAVINGS%
rem call npx oz send-tx --to %PROTOCOL_CURVEFY_SBTC% --network mainnet --method addDefiOperator --args %MODULE_INVESTING%
call npx oz send-tx --to %PROTOCOL_CURVEFY_SUSD% --network mainnet --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %PROTOCOL_CURVEFY_BUSD% --network mainnet --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %PROTOCOL_AAVE_SUSD% --network mainnet --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %PROTOCOL_AAVE_BUSD% --network mainnet --method addDefiOperator --args %MODULE_SAVINGS%
echo SETUP MINTERS FOR POOL TOKENS
call npx oz send-tx --to %POOL_TOKEN_COMPOUND_DAI% --network mainnet --method addMinter --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_COMPOUND_USDC% --network mainnet --method addMinter --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_Y% --network mainnet --method addMinter --args %MODULE_SAVINGS%
rem call npx oz send-tx --to %POOL_TOKEN_CURVEFY_SBTC% --network mainnet --method addMinter --args %MODULE_INVESTING%
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_SUSD% --network mainnet --method addMinter --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_BUSD% --network mainnet --method addMinter --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_AAVE_SUSD% --network mainnet --method addMinter --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_AAVE_BUSD% --network mainnet --method addMinter --args %MODULE_SAVINGS%
goto :done

:done
echo DONE