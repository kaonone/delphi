@echo off
rem === DEFINE MODULES, PROTOCOLS, POOL_TOKENS  ===
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


SET PROTOCOL_CURVEFY_BUSD=
SET POOL_TOKEN_CURVEFY_BUSD=

SET PROTOCOL_COMPOUND_DAI=0x853D71180E6bA6584f3D400b21E4aEe2463129A4
SET POOL_TOKEN_COMPOUND_DAI=0x06C2119701B0034BFaC3Be3C65DAc35054404571

SET PROTOCOL_COMPOUND_USDC=0x048E645BA2965F48d72e7b855D6636F951aeD303
SET POOL_TOKEN_COMPOUND_USDC=0x551AaBC00A7d02b51A81138fb8fA455786720793

rem === DEFINE NEW OWNERS ===
set NEW_OWNER=0x701313fb41209ca44628d6312371BeCFEd40Db78

rem === GOTO REQUESTED OP===
if "%1" neq "" goto :%1
goto :done

:addRoles
echo ADD ROLES TO NEW OWNER
echo ADD MODULE ROLES
call npx oz send-tx --to %MODULE_ACCESS% --network rinkeby --method addWhitelistAdmin --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %MODULE_SAVINGS% --network rinkeby --method addCapper --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %MODULE_STAKING% --network rinkeby --method addCapper --args %NEW_OWNER% || goto :error
echo ADD PROTOCOL ROLES
call npx oz send-tx --to %PROTOCOL_COMPOUND_DAI% --network rinkeby --method addDefiOperator --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %PROTOCOL_COMPOUND_USDC% --network rinkeby --method addDefiOperator --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %PROTOCOL_CURVEFY_Y% --network rinkeby --method addDefiOperator --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %PROTOCOL_CURVEFY_SUSD% --network rinkeby --method addDefiOperator --args %NEW_OWNER% || goto :error
rem call npx oz send-tx --to %PROTOCOL_CURVEFY_BUSD% --network rinkeby --method addDefiOperator --args %NEW_OWNER% || goto :error
rem call npx oz send-tx --to %PROTOCOL_CURVEFY_SBTC% --network rinkeby --method addDefiOperator --args %NEW_OWNER% || goto :error
echo ADD POOL_TOKEN ROLES
call npx oz send-tx --to %POOL_TOKEN_COMPOUND_DAI% --network rinkeby --method addMinter --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %POOL_TOKEN_COMPOUND_USDC% --network rinkeby --method addMinter --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_Y% --network rinkeby --method addMinter --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_SUSD% --network rinkeby --method addMinter --args %NEW_OWNER% || goto :error
rem call npx oz send-tx --to %POOL_TOKEN_CURVEFY_BUSD% --network rinkeby --method addMinter --args %NEW_OWNER% || goto :error
rem call npx oz send-tx --to %POOL_TOKEN_CURVEFY_SBTC% --network rinkeby --method addMinter --args %NEW_OWNER% || goto :error
goto :done

:removeCurrentRoles
echo REMOVE ROLES FORM OLD OWNER
echo REMOVE MODULE ROLES
call npx oz send-tx --to %MODULE_ACCESS% --network rinkeby --method renounceWhitelistAdmin || goto :error
call npx oz send-tx --to %MODULE_SAVINGS% --network rinkeby --method renounceCapper || goto :error
call npx oz send-tx --to %MODULE_STAKING% --network rinkeby --method renounceCapper || goto :error
echo REMOVE PROTOCOL ROLES
call npx oz send-tx --to %PROTOCOL_COMPOUND_DAI% --network rinkeby --method renounceDefiOperator || goto :error
call npx oz send-tx --to %PROTOCOL_COMPOUND_USDC% --network rinkeby --method renounceDefiOperator || goto :error
call npx oz send-tx --to %PROTOCOL_CURVEFY_Y% --network rinkeby --method renounceDefiOperator || goto :error
call npx oz send-tx --to %PROTOCOL_CURVEFY_SUSD% --network rinkeby --method renounceDefiOperator || goto :error
rem call npx oz send-tx --to %PROTOCOL_CURVEFY_BUSD% --network rinkeby --method renounceDefiOperator || goto :error
rem call npx oz send-tx --to %PROTOCOL_CURVEFY_SBTC% --network rinkeby --method renounceDefiOperator || goto :error
echo REMOVE POOL_TOKEN ROLES
call npx oz send-tx --to %POOL_TOKEN_COMPOUND_DAI% --network rinkeby --method renounceMinter || goto :error
call npx oz send-tx --to %POOL_TOKEN_COMPOUND_USDC% --network rinkeby --method renounceMinter || goto :error
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_Y% --network rinkeby --method renounceMinter || goto :error
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_SUSD% --network rinkeby --method renounceMinter || goto :error
rem call npx oz send-tx --to %POOL_TOKEN_CURVEFY_BUSD% --network rinkeby --method renounceMinter || goto :error
rem call npx oz send-tx --to %POOL_TOKEN_CURVEFY_SBTC% --network rinkeby --method renounceMinter || goto :error
goto :done

:transferOwnership
echo TRANSFER OWNERSHIP
echo TRANSFER MODULE OWNERSHIP
call npx oz send-tx --to %MODULE_POOL% --network rinkeby --method transferOwnership --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %MODULE_ACCESS% --network rinkeby --method transferOwnership --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %MODULE_SAVINGS% --network rinkeby --method transferOwnership --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %MODULE_STAKING% --network rinkeby --method transferOwnership --args %NEW_OWNER% || goto :error
echo TRANSFER PROTOCOL OWNERSHIP
call npx oz send-tx --to %PROTOCOL_COMPOUND_DAI% --network rinkeby --method transferOwnership --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %PROTOCOL_COMPOUND_USDC% --network rinkeby --method transferOwnership --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %PROTOCOL_CURVEFY_Y% --network rinkeby --method transferOwnership --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %PROTOCOL_CURVEFY_SUSD% --network rinkeby --method transferOwnership --args %NEW_OWNER% || goto :error
rem call npx oz send-tx --to %PROTOCOL_CURVEFY_BUSD% --network rinkeby --method transferOwnership --args %NEW_OWNER%
rem call npx oz send-tx --to %PROTOCOL_CURVEFY_SBTC% --network rinkeby --method transferOwnership --args %NEW_OWNER%
echo TRANSFER POOL_TOKEN OWNERSHIP
call npx oz send-tx --to %POOL_TOKEN_COMPOUND_DAI% --network rinkeby --method transferOwnership --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %POOL_TOKEN_COMPOUND_USDC% --network rinkeby --method transferOwnership --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_Y% --network rinkeby --method transferOwnership --args %NEW_OWNER% || goto :error
call npx oz send-tx --to %POOL_TOKEN_CURVEFY_SUSD% --network rinkeby --method transferOwnership --args %NEW_OWNER% || goto :error
rem call npx oz send-tx --to %POOL_TOKEN_CURVEFY_BUSD% --network rinkeby --method transferOwnership --args %NEW_OWNER% || goto :error
rem call npx oz send-tx --to %POOL_TOKEN_CURVEFY_SBTC% --network rinkeby --method transferOwnership --args %NEW_OWNER% || goto :error

:transferUpgradeAdmin
echo TRANSFER UPGRADE ADMIN OWNERSHIP TO %NEW_OWNER%
call npx oz set-admin %NEW_OWNER% --network rinkeby
goto :done

:error
exit /b %errorlevel%

:done
echo DONE