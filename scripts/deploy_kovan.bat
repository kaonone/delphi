@echo off
rem === DEFINE MODULES ===
rem ==== External ====

rem ===== Tokens ====
SET EXT_TOKEN_DAI=0xff795577d9ac8bd7d90ee22b6c1703490b6512fd
SET EXT_TOKEN_USDC=0xe22da380ee6B445bb8273C81944ADEB6E8450422
SET EXT_TOKEN_SUSD=0xD868790F57B39C9B2B51b12de046975f986675f9
SET EXT_TOKEN_USDT=0x13512979ADE267AB5100878E2e0f485B568328a4
SET EXT_TOKEN_TUSD=0x1c4a937d171752e1313D70fb16Ae2ea02f86303e

SET EXT_TOKEN_BAL=0x4Ea46044d4bCEF7e413F459fCFFa2B6718D85CbE
SET EXT_TOKEN_AKRO=0x27f204d58dc05d5bcb8d4fdf65a8cfbbf50a8018

rem ===== AAVE ====
SET EXT_AAVE_ADDRESS_PROVIDER=0x506B0B2CF20FAA8f38a4E2B524EE43e1f4458Cc5
SET EXT_AAVE_REFCODE=0

rem ===== Balancer ====
SET EXT_BPT_WETH_WBTC=0x95ec87ac8211E40a201cE8c5CF53f6BeBbf25aA1

rem ==== Akropolis ====
SET MODULE_POOL=0xB8CE630eBD9d3932565346dDaCAc59DB0AB624fe
SET MODULE_ACCESS=0xdc605f07Fd230Fc1327f83FF140379C0C1D7773F
SET MODULE_SAVINGS=0x7E9a8806D37653B7289ae09F36C708485F00DF4b
SET MODULE_INVESTING=0xf63FEC0879F85E7Ccf262C34e0697Fc359E98C32
SET MODULE_STAKING=0xF69Ff7e49423fDD3BdedBE7C9776c4B68DA6dFCD

SET PROTOCOL_AAVE_DAI=0xE87EeAbFBaeAd01B716935b551BE41898F843038
SET POOL_TOKEN_AAVE_DAI=0x47377b24A52B0635Fb9F2A45711d56D35CeA8240

SET PROTOCOL_AAVE_USDC=0xD93302fA097923eBb2C096ca28Ba1F5F3B0E80c4
SET POOL_TOKEN_AAVE_USDC=0x15eA9cD690730d8A49375a8355cE390010a04B4d

SET PROTOCOL_AAVE_SUSD=0x221B1F0d64537A9925e23869B7182103c1B1ABa0
SET POOL_TOKEN_AAVE_SUSD=0x238083F1670b1Ba4eDEE87373A13f8326679EBB2

SET PROTOCOL_AAVE_USDT=0x8fAf519e5c68344081c3b4Db9d11EaD00C6F23f6
SET POOL_TOKEN_AAVE_USDT=0xaBEb317aed8D8d4A12BBD0205faED96a76470505

SET PROTOCOL_AAVE_TUSD=0x4090df330aa4B3C32DDe2dF5E98068e16961B80e
SET POOL_TOKEN_AAVE_TUSD=0xB3d80A044397b04e0aebc87454767d4ee9bD09B1

SET PROTOCOL_BALANCER_WETH_WBTC=0xAe703C0F711238dB3a61DE8920860ad2c75Dc9b3
SET POOL_TOKEN_BALANCER_WETH_WBTC=0x82Be1a3164fbE36F79D7d1da200D8F5360B82b9e

rem === GOTO REQUESTED OP===
if "%1" neq "" goto :%1
goto :done

rem === ACTION ===
:show
echo npx oz create InvestingModule --network kovan --init "initialize(address _pool)" --args %MODULE_POOL%
echo npx oz send-tx --to %MODULE_POOL% --network kovan --method set --args "investing, %MODULE_INVESTING%, false"
goto :done

:deploy1
echo npx oz send-tx --to %MODULE_INVESTING% --network kovan --method registerProtocol --args "%PROTOCOL_BALANCER_WETH_WBTC%, %POOL_TOKEN_BALANCER_WETH_WBTC%"
echo npx oz send-tx --to %PROTOCOL_BALANCER_WETH_WBTC% --network kovan --method addDefiOperator --args %MODULE_INVESTING%
echo npx oz send-tx --to %POOL_TOKEN_BALANCER_WETH_WBTC% --network kovan --method addMinter --args %MODULE_INVESTING%
goto :done

:deploy2
call npx oz send-tx --to %MODULE_SAVINGS% --network kovan --method registerProtocol --args "%PROTOCOL_BALANCER_WETH_WBTC%, %POOL_TOKEN_BALANCER_WETH_WBTC%"
call npx oz send-tx --to %PROTOCOL_BALANCER_WETH_WBTC% --network kovan --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_BALANCER_WETH_WBTC% --network kovan --method addMinter --args %MODULE_SAVINGS%
goto :done


:init
echo INIT PROJECT, ADD CONTRACTS
rem call npx oz init
call npx oz add Pool AccessModule SavingsModule StakingPool
call npx oz add AaveProtocol_DAI PoolToken_Aave_DAI
call npx oz add AaveProtocol_USDC PoolToken_Aave_USDC
goto :done

:createPool
echo CREATE POOL
call npx oz create Pool --network kovan --init
goto :done

:createModules
echo CREATE MODULES
call npx oz create AccessModule --network kovan --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create SavingsModule --network kovan --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create InvestingModule --network kovan --init "initialize(address _pool)" --args %MODULE_POOL%
call npx oz create StakingPool --network kovan --init "initialize(address _pool,address _stakingToken, uint256 _defaultLockInDuration)" --args "%MODULE_POOL%, %EXT_TOKEN_AKRO%, 0"
echo CREATE PROTOCOLS AND TOKENS
echo CREATE Aave DAI
call npx oz create AaveProtocol_DAI --network kovan --init "initialize(address _pool, address _token, address aaveAddressProvider, uint16 _aaveReferralCode)" --args "%MODULE_POOL%, %EXT_TOKEN_DAI%, %EXT_AAVE_ADDRESS_PROVIDER%, %EXT_AAVE_REFCODE%"
call npx oz create PoolToken_Aave_DAI --network kovan --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Aave USDC
call npx oz create AaveProtocol_USDC --network kovan --init "initialize(address _pool, address _token, address aaveAddressProvider, uint16 _aaveReferralCode)" --args "%MODULE_POOL%, %EXT_TOKEN_USDC%, %EXT_AAVE_ADDRESS_PROVIDER%, %EXT_AAVE_REFCODE%"
call npx oz create PoolToken_Aave_USDC --network kovan --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Aave SUSD
call npx oz create AaveProtocol_SUSD --network kovan --init "initialize(address _pool, address _token, address aaveAddressProvider, uint16 _aaveReferralCode)" --args "%MODULE_POOL%, %EXT_TOKEN_SUSD%, %EXT_AAVE_ADDRESS_PROVIDER%, %EXT_AAVE_REFCODE%"
call npx oz create PoolToken_Aave_SUSD --network kovan --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Aave USDT
call npx oz create AaveProtocol_USDT --network kovan --init "initialize(address _pool, address _token, address aaveAddressProvider, uint16 _aaveReferralCode)" --args "%MODULE_POOL%, %EXT_TOKEN_USDT%, %EXT_AAVE_ADDRESS_PROVIDER%, %EXT_AAVE_REFCODE%"
call npx oz create PoolToken_Aave_USDT --network kovan --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Aave TUSD
call npx oz create AaveProtocol_TUSD --network kovan --init "initialize(address _pool, address _token, address aaveAddressProvider, uint16 _aaveReferralCode)" --args "%MODULE_POOL%, %EXT_TOKEN_TUSD%, %EXT_AAVE_ADDRESS_PROVIDER%, %EXT_AAVE_REFCODE%"
call npx oz create PoolToken_Aave_TUSD --network kovan --init "initialize(address _pool)" --args %MODULE_POOL%
echo CREATE Balancer WETH/WBTC
call npx oz create BalancerProtocol_WETH_WBTC --network kovan --init "initialize(address _pool, address _bpt, address _bal)" --args "%MODULE_POOL%, %EXT_BPT_WETH_WBTC%, %EXT_TOKEN_BAL%"
call npx oz create PoolToken_Balancer_WETH_WBTC --network kovan --init "initialize(address _pool)" --args %MODULE_POOL%
goto :done

:empty
rem fixes "can not find addModules" error 
goto :done

:addModules
echo SETUP POOL: CALL FOR ALL MODULES (set)
call npx oz send-tx --to %MODULE_POOL% --network kovan --method set --args "access, %MODULE_ACCESS%, false"
call npx oz send-tx --to %MODULE_POOL% --network kovan --method set --args "savings, %MODULE_SAVINGS%, false"
call npx oz send-tx --to %MODULE_POOL% --network kovan --method set --args "investing, %MODULE_INVESTING%, false"
call npx oz send-tx --to %MODULE_POOL% --network kovan --method set --args "staking, %MODULE_STAKING%, false"
goto :done

:addProtocols
echo ADD PROTOCOLS
call npx oz send-tx --to %MODULE_SAVINGS% --network kovan --method registerProtocol --args "%PROTOCOL_AAVE_DAI%, %POOL_TOKEN_AAVE_DAI%"
call npx oz send-tx --to %MODULE_SAVINGS% --network kovan --method registerProtocol --args "%PROTOCOL_AAVE_USDC%, %POOL_TOKEN_AAVE_USDC%"
call npx oz send-tx --to %MODULE_SAVINGS% --network kovan --method registerProtocol --args "%PROTOCOL_AAVE_SUSD%, %POOL_TOKEN_AAVE_SUSD%"
call npx oz send-tx --to %MODULE_SAVINGS% --network kovan --method registerProtocol --args "%PROTOCOL_AAVE_USDT%, %POOL_TOKEN_AAVE_USDT%"
call npx oz send-tx --to %MODULE_SAVINGS% --network kovan --method registerProtocol --args "%PROTOCOL_AAVE_TUSD%, %POOL_TOKEN_AAVE_TUSD%"
call npx oz send-tx --to %MODULE_INVESTING% --network kovan --method registerProtocol --args "%PROTOCOL_BALANCER_WETH_WBTC%, %POOL_TOKEN_BALANCER_WETH_WBTC%"
goto :done

:setupOperators
echo SETUP OPERATORS FOR PROTOCOLS
call npx oz send-tx --to %PROTOCOL_AAVE_DAI% --network kovan --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %PROTOCOL_AAVE_USDC% --network kovan --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %PROTOCOL_AAVE_SUSD% --network kovan --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %PROTOCOL_AAVE_USDT% --network kovan --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %PROTOCOL_AAVE_TUSD% --network kovan --method addDefiOperator --args %MODULE_SAVINGS%
call npx oz send-tx --to %PROTOCOL_BALANCER_WETH_WBTC% --network kovan --method addDefiOperator --args %MODULE_INVESTING%
echo SETUP MINTERS FOR POOL TOKENS
call npx oz send-tx --to %POOL_TOKEN_AAVE_DAI% --network kovan --method addMinter --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_AAVE_USDC% --network kovan --method addMinter --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_AAVE_SUSD% --network kovan --method addMinter --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_AAVE_USDT% --network kovan --method addMinter --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_AAVE_TUSD% --network kovan --method addMinter --args %MODULE_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_BALANCER_WETH_WBTC% --network kovan --method addMinter --args %MODULE_INVESTING%
goto :done

:done
echo DONE