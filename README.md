# AMBRodeo Smart Contract

## Overview
The **AMBRodeo** smart contract is a decentralized platform for token creation, trading, and management. It leverages OpenZeppelin's `Clones` library for creating minimal proxy clones and provides a scalable and modular infrastructure for managing custom tokens with unique parameters such as step pricing.

## Features
- **Token Creation**: Enables users to create new tokens with customizable parameters.
- **Token Trading**: Supports buying and selling tokens using a step-based pricing model.
- **Income Management**: Collects fees for token creation and trading, allowing the owner to manage platform income.
- **Proxy Cloning**: Uses minimal proxy clones to create lightweight, efficient token implementations.
- **Admin Controls**: Provides administrative functions for managing fees, balances, and token states.

---

## Contract Details

### Structs
- `Params`:
  - `name`: Name of the token.
  - `symbol`: Symbol of the token.
  - `totalSupply`: Total supply of the token.
  - `stepPrice`: Array defining price steps for the token.
  - `data`: Additional metadata for the token.
- `Token`:
  - `balance`: AMB balance associated with the token.
  - `balanceToDex`: AMB balance threshold for transfer to the DEX.
  - `creator`: Address of the token creator.
  - `totalSupply`: Total supply of the token.
  - `stepPrice`: Array defining price steps for the token.
  - `active`: Token active status.

### Constants
- `PERCENT_FACOTR`: (100,000) Used for percentage calculations.
- `MAX_STEPS`: (1,000) Maximum number of steps allowed for step-based pricing.

### Variables
- `tokens`: Mapping of token addresses to `Token` structs.
- `tokenImplemetation`: Address of the token implementation contract.
- `dex`: Address of the DEX.
- `tokensList`: Array of all created token addresses.
- `balanceToDex`: Global AMB balance threshold for DEX transfer.
- `createFee`: Fee for creating a new token.
- `exchangeFeePercent`: Percentage fee for token exchanges.
- `income`: Total collected income.

---

## Functions

### Initialization
- `initialize()`: Initializes the contract, sets up the default token implementation, and assigns ownership.

### Token Creation
- `createToken(Params calldata params)`: Creates a new token using the specified parameters and emits the `CreateToken` event.

### Token Management
- `changeOwner(address token, address newOwner)`: Changes the ownership of a token.
- `activateToken(address token)`: Activates a token.
- `deactivateToken(address token)`: Deactivates a token.

### Trading
- `buy(address token)`: Allows users to purchase tokens using AMB.
- `sell(address token, uint amountIn)`: Allows users to sell tokens and receive AMB in return.
- `calculateBuy(uint amountIn, uint reserve, uint totalSupply, uint128[] memory steps)`: Calculates the number of tokens to be received when buying.
- `calculateSell(uint amountIn, uint reserve, uint totalSupply, uint128[] memory steps)`: Calculates the amount of AMB to be received when selling.

### Administrative Functions
- `setCreateFee(uint128 amount)`: Sets the fee for creating a new token.
- `setExchangeFee(uint32 exchangeFeePercent_)`: Sets the percentage fee for token exchanges.
- `transferIncome(address to, uint128 amount)`: Transfers a portion of the income to a specified address.
- `setDex(address dex_)`: Sets the DEX address.
- `setBalanceToDex(uint balance)`: Sets the global AMB balance threshold for DEX transfer.
- `setBalanceToDexCustom(address token, uint newBalance)`: Sets a custom balance threshold for a specific token.

---

## Events
- `CreateToken`: Emitted when a new token is created.
- `ChangeOwner`: Emitted when ownership of a token is transferred.
- `TokenTrade`: Emitted during token buy/sell transactions.
- `TransferToDex`: Emitted when tokens are transferred to the DEX.
- `ChangeBalanceToDexForToken`: Emitted when a token’s balance-to-DEX threshold is updated.
- `GasCompensation`: Emitted when gas compensation is processed.

---

## Errors
- `AMBRodeo__InvalidTokenCreationParams`: Raised for invalid token creation parameters.
- `AMBRodeo__InvalidInitializeToken`: Raised when token initialization fails.
- `AMBRodeo__TokenNotExist`: Raised when a specified token does not exist.
- `AMBRodeo__TokenNotActive`: Raised when a token is inactive during an operation.
- `AMBRodeo__TokenTransferError`: Raised when a token transfer fails.
- `AMBRodeo__NotEnoughPayment`: Raised when insufficient payment is provided.
- `AMBRodeo__NotEnoughIncom`: Raised when insufficient income is available for a transfer.
- `AMBRodeo__TransferToDexError`: Raised when transferring tokens to the DEX fails.
- `AMBRodeo__BurnTokensError`: Raised when token burning fails.

---

## Security Considerations
1. **Reentrancy**: Ensure that external calls (e.g., `transfer`) are properly guarded.
2. **Access Control**: Administrative functions are restricted to the owner.
3. **Validation**: All token parameters are validated before use.

---

## Deployment and Usage
1. Deploy the `AMBRodeo` contract.
2. Initialize the contract using `initialize()`.
3. Use `createToken()` to create new tokens.
4. Manage tokens and trading using the provided functions.

---

## License
This project is licensed under the MIT License.

---

## Dependencies
- OpenZeppelin Contracts (`@openzeppelin/contracts` and `@openzeppelin/contracts-upgradeable`).
