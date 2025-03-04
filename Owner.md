# AMBRodeo Contract - OnlyOwner Methods Documentation

The `AMBRodeo` contract includes several administrative functions that can only be executed by the contract owner. These functions allow the owner to configure the contract settings, manage tokens, and control internal balances.

## Functions

### `setTokenImplemetation(address tokenImplementation)`
**Description:**
Updates the address of the token implementation contract.

**Parameters:**
- `tokenImplementation (address)`: The new token implementation address.

**Access Control:**
- Can only be called by the contract owner.

---

### `setCreateToken()`
**Description:**
Toggles the ability to create new tokens.

**Access Control:**
- Can only be called by the contract owner.

---

### `transferInternalBalance(address to, uint256 amount)`
**Description:**
Transfers a specified amount from the contract's internal balance to a given address.

**Parameters:**
- `to (address)`: The recipient address.
- `amount (uint256)`: The amount to transfer.

**Access Control:**
- Can only be called by the contract owner.

---

### `setVirtualLiquidity(uint256 amount)`
**Description:**
Updates the virtual liquidity setting.

**Parameters:**
- `amount (uint256)`: The new virtual liquidity amount.

**Access Control:**
- Can only be called by the contract owner.

---

### `setInitLiquidity()`
**Description:**
Toggles the initial liquidity setting.

**Access Control:**
- Can only be called by the contract owner.

---

### `setDex(address dex)`
**Description:**
Sets the decentralized exchange (DEX) address.

**Parameters:**
- `dex (address)`: The new DEX address.

**Access Control:**
- Can only be called by the contract owner.

---

### `setBalanceToDex(uint256 amount)`
**Description:**
Sets the threshold balance required before transferring tokens to the DEX.

**Parameters:**
- `amount (uint256)`: The balance threshold.

**Access Control:**
- Can only be called by the contract owner.

---

### `setCreateFee(uint256 amount)`
**Description:**
Sets the fee required to create a new token.

**Parameters:**
- `amount (uint256)`: The new creation fee.

**Access Control:**
- Can only be called by the contract owner.

---

### `setExchangeFee(uint256 amount)`
**Description:**
Sets the exchange fee for token transactions.

**Parameters:**
- `amount (uint256)`: The new exchange fee.

**Access Control:**
- Can only be called by the contract owner.

---

### `setTotalSupply(uint256 amount)`
**Description:**
Sets the total supply of tokens.

**Parameters:**
- `amount (uint256)`: The new total supply.

**Access Control:**
- Can only be called by the contract owner.

---

### `tokenChangeOwner(address token, address newOwner)`
**Description:**
Transfers ownership of a specified token to a new owner.

**Parameters:**
- `token (address)`: The token contract address.
- `newOwner (address)`: The new owner address.

**Access Control:**
- Can only be called by the contract owner.

---

### `setActiveToken(address token)`
**Description:**
Toggles the active status of a specified token.

**Parameters:**
- `token (address)`: The token contract address.

**Access Control:**
- Can only be called by the contract owner.

---

### `setVirtualToken(uint256 amount)`
**Description:**
Updates the virtual token setting.

**Parameters:**
- `amount (uint256)`: The new virtual token amount.

**Access Control:**
- Can only be called by the contract owner.

---

### `setToDexFee(uint256 amount)`
**Description:**
Sets the fee required to dex a token.

**Parameters:**
- `amount (uint256)`: The new creation fee.

**Access Control:**
- Can only be called by the contract owner.

---

### `setLimitOwnerBuy(uint256 amount)`
**Description:**
Sets the limit required to owner buy a token.

**Parameters:**
- `amount (uint256)`: The new limit.

**Access Control:**
- Can only be called by the contract owner.
