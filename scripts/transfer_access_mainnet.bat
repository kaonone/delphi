@echo off
rem === DEFINE MODULES, PROTOCOLS, POOL_TOKENS  ===
SET MODULE_POOL=0x4C39b37f5F20a0695BFDC59cf10bd85a6c4B7c30
SET MODULE_ACCESS=0x5fFcf7da7BdC49CA8A2E7a542BD59dC38228Dd45
SET MODULE_SAVINGS=0x73fC3038B4cD8FfD07482b92a52Ea806505e5748
SET MODULE_STAKING=0x3501Ec11d205fa249f2C42f5470e137b529b35D0

SET PROTOCOL_CURVEFY_Y=0x7967adA2A32A633d5C055e2e075A83023B632B4e
SET POOL_TOKEN_CURVEFY_Y=0x2AFA3c8Bf33E65d5036cD0f1c3599716894B3077

SET PROTOCOL_CURVEFY_SBTC=
SET POOL_TOKEN_CURVEFY_SBTC=

SET PROTOCOL_CURVEFY_SUSD=0x91d7b9a8d2314110D4018C88dBFDCF5E2ba4772E
SET POOL_TOKEN_CURVEFY_SUSD=0x520d25b08080296db66fd9f268ae279b66a8effb

SET PROTOCOL_CURVEFY_BUSD=0xEaE1A8206F68a7ef629e85fc69E82CFD36E83BA4
SET POOL_TOKEN_CURVEFY_BUSD=0x8367Af78444C5B57Bc1cF38dED331d03558e67Bb

SET PROTOCOL_COMPOUND_DAI=0x08DDB58D31C08242Cd444BB5B43F7d2C6bcA0396
SET POOL_TOKEN_COMPOUND_DAI=0x9Fca734Bb62C20D2cF654705b8fbf4F49FF5cC31

SET PROTOCOL_COMPOUND_USDC=0x9984D588EF2112894a0513663ba815310D383E3c
SET POOL_TOKEN_COMPOUND_USDC=0x5Ad76E93a3a852C9af760dA3FdB7983C265d8997

rem === DEFINE NEW OWNERS ===
set NEW_OWNER=0x4454fC25daF515D1237d0ea76aC3Ea931118eeF0

rem === GOTO REQUESTED OP===
if "%1" neq "" goto :%1
goto :done

:addRoles
echo ADD ROLES TO NEW OWNER
echo ADD MODULE ROLES
call npx oz send-tx --to %MODULE_ACCESS% --network mainnet --method addWhitelistAdmin --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %MODULE_SAVINGS% --network mainnet --method addCapper --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %MODULE_STAKING% --network mainnet --method addCapper --args %NEW_OWNER% || goto :error
echo ADD PROTOCOL ROLES
call npx oz send-tx --to %PROTOCOL_COMPOUND_DAI% --network mainnet --method addDefiOperator --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %PROTOCOL_COMPOUND_USDC% --network mainnet --method addDefiOperator --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %PROTOCOL_CURVEFY_Y% --network mainnet --method addDefiOperator --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %PROTOCOL_CURVEFY_SUSD% --network mainnet --method addDefiOperator --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %PROTOCOL_CURVEFY_BUSD% --network mainnet --method addDefiOperator --args %NEW_OWNER% || goto :error
rem call npx oz send-tx --to %PROTOCOL_CURVEFY_SBTC% --network mainnet --method addDefiOperator --args %NEW_OWNER% || goto :error
echo ADD POOL_TOKEN ROLES
call npx oz send-tx --to %POOL_TOKEN_COMPOUND_DAI% --network mainnet --method addMinter --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %POOL_TOKEN_COMPOUND_USDC% --network mainnet --method addMinter --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_Y% --network mainnet --method addMinter --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_SUSD% --network mainnet --method addMinter --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_BUSD% --network mainnet --method addMinter --args %NEW_OWNER% || goto :error
rem call npx oz send-tx --to %POOL_TOKEN_CURVEFY_SBTC% --network mainnet --method addMinter --args %NEW_OWNER% || goto :error
goto :done

:removeCurrentRoles
echo REMOVE ROLES FORM OLD OWNER
echo REMOVE MODULE ROLES
call npx oz send-tx --to %MODULE_ACCESS% --network mainnet --method renounceWhitelistAdmin || goto :error
call npx oz send-tx --to %MODULE_SAVINGS% --network mainnet --method renounceCapper || goto :error
call npx oz send-tx --to %MODULE_STAKING% --network mainnet --method renounceCapper || goto :error
echo REMOVE PROTOCOL ROLES
call npx oz send-tx --to %PROTOCOL_COMPOUND_DAI% --network mainnet --method renounceDefiOperator || goto :error
call npx oz send-tx --to %PROTOCOL_COMPOUND_USDC% --network mainnet --method renounceDefiOperator || goto :error
call npx oz send-tx --to %PROTOCOL_CURVEFY_Y% --network mainnet --method renounceDefiOperator || goto :error
call npx oz send-tx --to %PROTOCOL_CURVEFY_SUSD% --network mainnet --method renounceDefiOperator || goto :error
call npx oz send-tx --to %PROTOCOL_CURVEFY_BUSD% --network mainnet --method renounceDefiOperator || goto :error
rem call npx oz send-tx --to %PROTOCOL_CURVEFY_SBTC% --network mainnet --method renounceDefiOperator || goto :error
echo REMOVE POOL_TOKEN ROLES
call npx oz send-tx --to %POOL_TOKEN_COMPOUND_DAI% --network mainnet --method renounceMinter || goto :error
call npx oz send-tx --to %POOL_TOKEN_COMPOUND_USDC% --network mainnet --method renounceMinter || goto :error
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_Y% --network mainnet --method renounceMinter || goto :error
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_SUSD% --network mainnet --method renounceMinter || goto :error
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_BUSD% --network mainnet --method renounceMinter || goto :error
rem call npx oz send-tx --to %POOL_TOKEN_CURVEFY_SBTC% --network mainnet --method renounceMinter || goto :error
goto :done

:transferOwnership
echo TRANSFER OWNERSHIP
echo TRANSFER MODULE OWNERSHIP
call npx oz send-tx --to %MODULE_POOL% --network mainnet --method transferOwnership --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %MODULE_ACCESS% --network mainnet --method transferOwnership --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %MODULE_SAVINGS% --network mainnet --method transferOwnership --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %MODULE_STAKING% --network mainnet --method transferOwnership --args %NEW_OWNER% || goto :error
echo TRANSFER PROTOCOL OWNERSHIP
call npx oz send-tx --to %PROTOCOL_COMPOUND_DAI% --network mainnet --method transferOwnership --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %PROTOCOL_COMPOUND_USDC% --network mainnet --method transferOwnership --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %PROTOCOL_CURVEFY_Y% --network mainnet --method transferOwnership --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %PROTOCOL_CURVEFY_SUSD% --network mainnet --method transferOwnership --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %PROTOCOL_CURVEFY_BUSD% --network mainnet --method transferOwnership --args %NEW_OWNER%
rem call npx oz send-tx --to %PROTOCOL_CURVEFY_SBTC% --network mainnet --method transferOwnership --args %NEW_OWNER%
echo TRANSFER POOL_TOKEN OWNERSHIP
call npx oz send-tx --to %POOL_TOKEN_COMPOUND_DAI% --network mainnet --method transferOwnership --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %POOL_TOKEN_COMPOUND_USDC% --network mainnet --method transferOwnership --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_Y% --network mainnet --method transferOwnership --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_SUSD% --network mainnet --method transferOwnership --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_BUSD% --network mainnet --method transferOwnership --args %NEW_OWNER% || goto :error
rem call npx oz send-tx --to %POOL_TOKEN_CURVEFY_SBTC% --network mainnet --method transferOwnership --args %NEW_OWNER% || goto :error
goto :done

:transferUpgradeAdmin
echo TRANSFER UPGRADE ADMIN OWNERSHIP TO %NEW_OWNER%
call npx oz set-admin %NEW_OWNER% --network mainnet
goto :done

:error
exit /b %errorlevel%

:done
echo DONE