// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./ERC20Initializable.sol";

contract AMBRodeoTokenImplementation is ERC20Initializable {
    bool private _initialized;

    function init(
        string calldata name_,
        string calldata symbol_,
        address account_,
        uint256 value_
    ) external {
        require(!_initialized, "Initialized");
        _initialized = true;
        _name = name_;
        _symbol = symbol_;
        _mint(account_, value_);
    }
}
