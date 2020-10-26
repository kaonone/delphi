@echo off
rem === DEFINE MODULES ===
rem ==== External ====

rem ===== Tokens ====
SET EXT_TOKEN_DAI=0x6b175474e89094c44da98b954eedeac495271d0f
SET EXT_TOKEN_USDC=0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48
SET EXT_TOKEN_USDT=0xdAC17F958D2ee523a2206206994597C13D831ec7
SET EXT_TOKEN_TUSD=0x0000000000085d4780B73119b644AE5ecd22b376
SET EXT_TOKEN_SUSD=0x57Ab1ec28D129707052df4dF418D58a2D46d5f51
SET EXT_TOKEN_BUSD=0x4Fabb145d64652a948d72533023f6E7A623C7C53
SET EXT_TOKEN_AKRO=0x8ab7404063ec4dbcfd4598215992dc3f8ec853d7
SET EXT_TOKEN_ADEL=0x94d863173EE77439E4292284fF13fAD54b3BA182
SET EXT_TOKEN_WETH=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2

rem ===== Dexag ====
SET EXT_DEXAG_PROXY=0x2ef1298B41D6Ec5e071ebA9Fc8f0eCC53fd675fD

rem ===== Curve.Fi ====
SET EXT_CURVEFY_Y_DEPOSIT=0xbBC81d23Ea2c3ec7e56D39296F0cbB648873a5d3
SET EXT_CURVEFY_Y_MINTER=0xd061D61a4d941c39E5453435B6345Dc261C2fcE0
SET EXT_CURVEFY_Y_GAUGE=0xFA712EE4788C042e2B7BB55E6cb8ec569C4530c1

rem ==== Akropolis ====
SET MODULE_POOL=0x4C39b37f5F20a0695BFDC59cf10bd85a6c4B7c30
SET MODULE_ACCESS=0x5fFcf7da7BdC49CA8A2E7a542BD59dC38228Dd45

SET MODULE_VAULT_SAVINGS=0x5aDEbf51b01C08C875C9931aa9474CD60A2DB741
SET VAULT_PROTOCOL_CURVE=0x4215B8Ba7B12A8293fe7c9CEF897C5669A368fF8
SET STRATEGY_CURVE=0x72e8F9aa2fa78Ce2eF7cbEc97cB5c8E696Ebe593
SET POOL_TOKEN_VAULT_CURVE=0xD28a298fDe6Bb995A2a01293866916989e48507D

rem ==== Roles ====
SET VAULT_OPERATOR=0x509e16558F1fdc4733EFa73846Da891a29797E43


rem === GOTO REQUESTED OP===
if "%1" neq "" goto :%1
goto :done

rem === ACTIONS ===
:show
goto :done

:create
call truffle compile --all
call npx oz create VaultSavingsModule --network mainnet --init "initialize(address _pool)" --args %MODULE_POOL% --skip-compile
call npx oz create VaultProtocolCurveFi --network mainnet --init "initialize(address _pool, address[] memory tokens)" --args "%MODULE_POOL%,[%EXT_TOKEN_DAI%,%EXT_TOKEN_USDC%,%EXT_TOKEN_USDT%,%EXT_TOKEN_TUSD%]" --skip-compile
call npx oz create CurveFiStablecoinStrategy --network mainnet --init "initialize(address _pool, string memory _strategyId)" --args "%MODULE_POOL%,""CRV-DEXAG-DAI""" --skip-compile
call npx oz create PoolToken_Vault_CurveFi --network mainnet --init "initialize(address _pool)" --args %MODULE_POOL% --skip-compile
goto :done

:setup
rem call npx oz send-tx --to %MODULE_POOL% --network mainnet --method set --args "vault, %MODULE_VAULT_SAVINGS%, false"
call npx oz send-tx --to %STRATEGY_CURVE% --network mainnet --method setProtocol --args "%EXT_CURVEFY_Y_DEPOSIT%,%EXT_CURVEFY_Y_GAUGE%,%EXT_CURVEFY_Y_MINTER%,%EXT_DEXAG_PROXY%"
call npx oz send-tx --to %STRATEGY_CURVE% --network mainnet --method addDefiOperator --args %VAULT_PROTOCOL_CURVE%
call npx oz send-tx --to %STRATEGY_CURVE% --network mainnet --method addDefiOperator --args %MODULE_VAULT_SAVINGS%
call npx oz send-tx --to %VAULT_PROTOCOL_CURVE% --network mainnet --method addDefiOperator --args %MODULE_VAULT_SAVINGS%
call npx oz send-tx --to %VAULT_PROTOCOL_CURVE% --network mainnet --method registerStrategy --args %STRATEGY_CURVE%
call npx oz send-tx --to %VAULT_PROTOCOL_CURVE% --network mainnet --method setQuickWithdrawStrategy --args %STRATEGY_CURVE%
call npx oz send-tx --to %POOL_TOKEN_VAULT_CURVE% --network mainnet --method addMinter --args %MODULE_VAULT_SAVINGS%
call npx oz send-tx --to %POOL_TOKEN_VAULT_CURVE% --network mainnet --method addMinter --args %VAULT_PROTOCOL_CURVE%
call npx oz send-tx --to %MODULE_VAULT_SAVINGS% --network mainnet --method registerVault --args "%VAULT_PROTOCOL_CURVE%,%POOL_TOKEN_VAULT_CURVE%"
call npx oz send-tx --to %MODULE_VAULT_SAVINGS% --network mainnet --method setVaultRemainder --args "%VAULT_PROTOCOL_CURVE%,1000000,0"
call npx oz send-tx --to %MODULE_VAULT_SAVINGS% --network mainnet --method setVaultRemainder --args "%VAULT_PROTOCOL_CURVE%,1000000,1"
call npx oz send-tx --to %MODULE_VAULT_SAVINGS% --network mainnet --method setVaultRemainder --args "%VAULT_PROTOCOL_CURVE%,1000000,2"
call npx oz send-tx --to %MODULE_VAULT_SAVINGS% --network mainnet --method setVaultRemainder --args "%VAULT_PROTOCOL_CURVE%,1000000,3"
goto :done

:setupOperator
call npx oz send-tx --to %MODULE_VAULT_SAVINGS% --network mainnet --method addVaultOperator --args %VAULT_OPERATOR%
rem call npx oz send-tx --to %STRATEGY_CURVE% --network mainnet --method addDefiOperator --args %VAULT_OPERATOR%
goto :done

:done
echo DONE