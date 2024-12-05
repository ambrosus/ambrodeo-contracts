// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "./AMBRodeoTokenImplementation.sol";
import "./AMBRodeoTokenProxy.sol";

contract AMBRodeoTokenFactory is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    struct Token {
        string userName;
        string imageUrl;
    }
    address public dex;
    address tokenImplemetation;
    mapping(address => Token) public tokens;
    address[] public tokensList;
    uint256 public tokenCount;
    uint256 public totalSupply;
    uint256 public fee;

    event TokenDeployed(
        address indexed tokenAddress,
        address indexed user,
        string indexed name,
        string symbol,
        uint256 totalSupply
    );
    event ChangeFee(uint256 fee);
    event TransferFee(address indexed account, uint256 value);
    event DeleteTokenInfo(address indexed token);

    function initialize(
        address dex_,
        uint256 totalSupply_,
        uint256 fee_
    ) public initializer {
        __Ownable_init(msg.sender);
        dex = dex_;
        totalSupply = totalSupply_;
        fee = fee_;
        AMBRodeoTokenImplementation c = new AMBRodeoTokenImplementation();
        c.init("default", "default", address(c), 0);
        tokenImplemetation = address(c);
    }

    function setDex(address dex_) public onlyOwner {
        dex = dex_;
    }

    function changeFee(uint256 fee_) external onlyOwner {
        fee = fee_;
        emit ChangeFee(fee);
    }

    function transferFee(address account, uint256 value) external onlyOwner {
        require(value <= address(this).balance, "Doesn't have coins");
        payable(account).transfer(value);
        emit TransferFee(account, value);
    }

    function deleteTokenInfo(address token) external onlyOwner {
        delete tokens[token];
        emit DeleteTokenInfo(token);
    }

    function getImageToken(
        address token
    ) external view returns (string memory) {
        return tokens[token].imageUrl;
    }

    function getUserNameToken(
        address token
    ) external view returns (string memory) {
        return tokens[token].userName;
    }

    function deployToken(
        string calldata name,
        string calldata symbol,
        string calldata userName,
        string calldata imageUrl
    ) public payable whenNotPaused {
        require(msg.value >= fee);
        ProxyERC20 token = new ProxyERC20(
            tokenImplemetation,
            name,
            symbol,
            dex,
            totalSupply
        );

        (bool successInit, ) = dex.call(
            abi.encodeWithSignature("initLiquidityToken(address)", token)
        );
        require(successInit, "Init liquidity token failed");

        if (msg.value - fee > 0) {
            (bool successBuy, ) = dex.call{value: msg.value - fee}(
                abi.encodeWithSignature("buy(address)", token)
            );
            require(successBuy, "Buy token failed");
        }

        tokens[address(token)] = Token(userName, imageUrl);
        tokensList.push(address(token));
        tokenCount += 1;
        emit TokenDeployed(
            address(token),
            msg.sender,
            name,
            symbol,
            totalSupply
        );
    }

    function setPause(bool isPause) external onlyOwner {
        if (isPause) {
            _pause();
        } else {
            _unpause();
        }
    }
}
