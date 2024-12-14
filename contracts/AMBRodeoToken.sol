// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC20Initializable.sol";

contract AMBRodeoToken is ERC20Initializable, Ownable(msg.sender) {
    bool private _initialized;

    function init(string calldata name, string calldata symbol) external {
        require(!_initialized, "Initialized");
        _initialized = true;
        _name = name;
        _symbol = symbol;
        _transferOwnership(msg.sender);
    }

    function burn(address account, uint amount) external onlyOwner {
        _burn(account, amount);
    }

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }
}
