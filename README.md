# Delphi


# DCA Pool
VARS

uint256 periodTimestamp – purchase period delta
uint256 nextBuyTimestamp – next purchase time
uint256 globalPeriodBuyAmount – global purchase amount for the period 
uint256 deadline - exchange protocol deadline
uint256 protocolMaxFee - maximum pool fee 
uint256 feeFoundation - basis for fee calculation

address router – exchange protocol address
address tokenToSell (USDC) – token to sell address 

Distribution[] distributions – distribution array
address[] distributionTokens – tokens to buy array 
mapping(uint256 => Account) _accountOf – accounts mapping
mapping(uint256 => uint256) removeAfterDistribution – mapping of amounts to adjust globalPeriodBuyAmount;
mapping(address => TokenData) public tokenDataOf – mapping of tokens data 

Strategies strategy - strategy from enum (enum Strategies {ONE, ALL});


STRUCTS

Account
mapping(address => uint256) balance – balances of all user tokens;
uint256 buyAmount – amount to buy during period;
uint256 nextDistributionIndex – next distribution index in which account would participate if minimum balance threshold is passed.
uint256 lastRemovalPointIndex – distribution index after which a certain amount should be excluded from `globalPeriodBuyAmount`

Distribution
address tokenAddress - token address;
uint256 amountIn – amount in tokenToSell, which was used to buy assets;
uint256 amountOut – amount of tokens (wBTC, wETH, ...) received from exchange protocol;

TokenData
uint256 decimals – token decimal;
address pool - pool address;
address protocol - address of the protocol interacting with the pool;
address poolToken – pool token address;


DEPOSIT


User sets up amount (amount of tokens for deposit) and buyAmount (amount of tokens to sell during period). 
After approval, tokens are transferred from user account. .
If user is interacting with the pool for the first time and don’t have an authentication token than ERC721 token is created with all the parameters in it. Any further account interactions are done via token identificator. 
Balance is set == amount.
buyAmount is set.
globalPeriodBuyAmount is increased by amount
removalPoint index is calculated and saved in the removeAfterDistribution mapping. This index shows when and which amount should be excluded from globalPeriodBuyAmount. It is stored in lastRemovalPointIndex.
nextDistributionIndex is set.
Tokens (amount) are sent to Savings Pool.


If the user already had an identification token (erc721), then call _claimDistributions().
Account balance increases. 
Excluding removeAfterDistribution from lastRemovalPointIndex.
Recalculating globalPeriodBuyAmount by removing previous у buyAmount and adding new one.
Calculating new removalPoint and saving it in removeAfterDistribution.
Tokens (amount) are sent to Savings pool. 

WITHDRAW

User sets up an amount (amount of tokens for topping up the balance) and token (token address for withdrawal).
Calling _claimDistributions().
Getting tokenId (ERC721)
Make parameters recalculation.
If (token == tokenToSell), then checking whether there is enough funds on the balance.
Decreasing balance by amount.
Clearing removeAfterDistribution.
Calculating new removalPoint and saving it in removeAfterDistribution.
Changing token to the corresponding token in the SavingsPool and creating  yield distribution for tokenToSell. (getting all yield with withdrawal).
Transfering tokenToSell to the user.



If (token != tokenToSell), then check whether there is enough funds on the balance.
Changing token to the corresponding token in the and create yield distribution for this token. (getting all yield with withdrawal). 
Decreasing balance by amount.
Transfering token to the user.


PURCHASE

Checking (now >= nextBuyTimestamp).
Calculating buyAmount. Dividing globalPeriodBuyAmount by the number of tokens in distributionTokens array.
Withdrawing tokenToSell (USDC) from SavingsPool and creating yield distribution for tokenToSell. (getting all yield with withdrawal).
Making Approve
Starting the cycle for all tokens in distributionTokens.
On each cycle step calling _swapAndCreateDistribution() with UniswapV2 parameters.
Updating nextBuyTimestamp 
Deleting data from removeAfterDistribution connected to last distribution index from globalPeriodBuyAmount


_CLAIM DISTRIBUTIONS

Getting tokenId (ERC721).
Starting the cycle for distribution array with the initial index equal to accountOf[tokenId].nextDistributionIndex.
Calculating splitBuyAmount: _accountOf[tokenId].buyAmount / distributionTokens.length
At the each step of the cycle checking whether tokenToSell balance of account is lower than splitBuyAmount.
Calculating (amount), how much account can claim from accrued distributions. Using the following proportion: 
buyAmount * amountOut / amountIn
, whereas  buyAmount - purchasing amount of user for the period
, amountIn – joint amount to purchase from all users 
, amountOut – amount of tokens received during distribution after exchanging.
Decreasing tokenToSell balance of the account by buyAmount.
Increasing token balance (specific cycle step) by amount received earlier.
Fixing nextDistributionIndex.

* In case when distribution token == tokenToSell, following the algorithm from above + recalculating removeAfterDistribution for the user (same as deposit()).

_SWAP AND CREATE DISTRIBUTION
When swapping, we deposit token bought to the SavingsPool.
Creating distribution on the projection (pool token) of the token bought.





























