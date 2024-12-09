// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC20Initializable.sol";

contract AMBRodeoToken is ERC20Initializable, Ownable(msg.sender) {
    bool private _initialized;

    function init(
        string calldata name,
        string calldata symbol,
        address account,
        uint256 totalSupply
    ) external {
        require(!_initialized, "Initialized");
        _initialized = true;
        _name = name;
        _symbol = symbol;
        _mint(account, totalSupply);
        _transferOwnership(msg.sender);
    }

    function burn(uint256 amount) public onlyOwner returns (bool) {
        if (balanceOf(msg.sender) <= amount) return false;
        _burn(msg.sender, amount);
        return true;
    }

    function mint(uint256 amount) public onlyOwner {
        _mint(msg.sender, amount);
    }
}
