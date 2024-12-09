// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./AMBRodeoToken.sol";

contract AMBRodeo is Initializable, OwnableUpgradeable {
    struct Params {
        string name;
        string symbol;
        uint128 totalSupply;
        uint128[] stepPrice;
        string imageUrl;
    }
    struct Token {
        address creator;
        uint128 totalSupply;
        uint128[] stepPrice;
    }

    uint32 constant MAX_STEPS = 1000;
    address public tokenImplemetation;
    mapping(address => Token) public tokens;
    address[] public tokensList;
    uint128 public createPrice;
    uint128 public exchangePrice;
    uint128 public income;

    error AMBRodeo__InvalidTokenCreationParams(string reason);
    error AMBRodeo__InvalidInitializeToken();
    error AMBRodeo__TokenNotExist(address token);
    error AMBRodeo__TokenTransferError(address token);
    error AMBRodeo__NotEnoughPayment();

    event CreateToken(
        address indexed token,
        address indexed account,
        string indexed name,
        string symbol,
        uint totalSupply,
        string imageUrl,
        uint value
    );
    event ChangeOwner(address token, address to);
    event BuyTokens(address token, address account, uint input, uint output);
    event SellTokens(address token, address account, uint input, uint output);

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        AMBRodeoToken token = new AMBRodeoToken();
        token.init("default", "default", address(this), 0);
        tokenImplemetation = address(token);
    }

    function setTokenImplemetation(address token) external onlyOwner {
        tokenImplemetation = token;
    }

    function validateParams(Params calldata params) internal pure {
        if (bytes(params.name).length == 0)
            revert AMBRodeo__InvalidTokenCreationParams("name");
        if (bytes(params.symbol).length == 0)
            revert AMBRodeo__InvalidTokenCreationParams("symbol");
        if (bytes(params.symbol).length == 0)
            revert AMBRodeo__InvalidTokenCreationParams("imageUrl");
        if (params.totalSupply == 0)
            revert AMBRodeo__InvalidTokenCreationParams("totalSupply");
        if (params.stepPrice.length == 0 || params.stepPrice.length > MAX_STEPS)
            revert AMBRodeo__InvalidTokenCreationParams("stepPrice");

        if (params.stepPrice[0] == 0) {
            revert AMBRodeo__InvalidTokenCreationParams("stepPrice");
        }

        uint128 tmp;
        for (uint32 i = 0; i < params.stepPrice.length; i++) {
            if (tmp > params.stepPrice[i])
                revert AMBRodeo__InvalidTokenCreationParams("stepPrice");
            tmp = params.stepPrice[i];
        }
    }

    function createToken(Params calldata params) public payable {
        if (msg.value != createPrice) revert AMBRodeo__NotEnoughPayment();
        income += createPrice;

        validateParams(params);
        AMBRodeoToken token = AMBRodeoToken(Clones.clone(tokenImplemetation));
        token.init(
            params.name,
            params.symbol,
            address(this),
            params.totalSupply
        );

        tokens[address(token)] = Token(
            msg.sender,
            params.totalSupply,
            params.stepPrice
        );
        tokensList.push(address(token));

        emit CreateToken(
            address(token),
            msg.sender,
            params.name,
            params.symbol,
            params.totalSupply,
            params.imageUrl,
            msg.value
        );
    }

    function tokensCount() external view returns (uint) {
        return tokensList.length;
    }

    function getStepPrice(
        address token
    ) external view returns (uint128[] memory) {
        return tokens[token].stepPrice;
    }

    function changeOwner(address token, address newOwner) external onlyOwner {
        if (tokens[token].creator != address(0)) {
            AMBRodeoToken(token).transferOwnership(newOwner);
            emit ChangeOwner(token, newOwner);
        } else {
            revert AMBRodeo__TokenNotExist(token);
        }
    }

    function transmitToken(address token, address to) public onlyOwner {
        if (tokens[token].creator != address(0)) {
            if (
                !IERC20(token).transfer(
                    address(to),
                    IERC20(token).balanceOf(address(this))
                )
            ) revert AMBRodeo__TokenTransferError(token);
        } else {
            revert AMBRodeo__TokenNotExist(token);
        }
    }

    function calculateBuy(
        uint amountIn,
        uint reserve,
        uint totalSupply,
        uint128[] memory steps
    ) public pure returns (uint amountOut) {
        require(amountIn > 0, "AmountIn must be greater than 0");
        uint limit = reserve;
        uint stepSize = totalSupply / steps.length;
        uint step = (totalSupply - reserve) / stepSize;

        while (true) {
            uint remain = (reserve % stepSize);
            if (remain == 0) {
                if (step == steps.length) revert("There is not enough reserve");
                remain = stepSize;
            }

            if ((amountIn / steps[step]) < remain) {
                amountOut += amountIn / steps[step];
                require(limit >= amountOut, "There is not enough reserve");
                break;
            }
            amountIn -= remain * steps[step];
            amountOut += remain;
            reserve -= remain;
            if (amountIn == 0) break;
            if (limit <= amountOut) revert("There is not enough reserve");
            step++;
        }
    }

    function calculateSell(
        uint amountIn,
        uint reserve,
        uint totalSupply,
        uint128[] memory steps
    ) public pure returns (uint amountOut) {
        require(amountIn > 0, "AmountIn must be greater than 0");
        uint stepSize = totalSupply / steps.length;
        uint step = (totalSupply - reserve) / stepSize;

        while (true) {
            uint remain = stepSize - (reserve % stepSize);
            if (remain == stepSize) {
                if (step == 0) revert("There is not enough reserve");
                remain = stepSize;
                step--;
            }

            if (amountIn < remain) remain = amountIn;
            amountIn -= remain;
            amountOut += remain * steps[step];
            reserve += remain;
            if (amountIn == 0) break;
            if (reserve >= totalSupply) revert("There is not enough reserve");
        }
    }

    function incomeExchange(uint input) internal returns (uint) {
        if (input < exchangePrice) revert AMBRodeo__NotEnoughPayment();
        income += exchangePrice;
        return input - exchangePrice;
    }

    function buy(address token) public payable {
        uint value = incomeExchange(msg.value);
        Token memory token1 = tokens[token];
        if (token1.totalSupply == 0) revert AMBRodeo__TokenNotExist(token);
        uint tokenBalance = IERC20(token).balanceOf(address(this));
        uint amountOut = calculateBuy(
            value,
            tokenBalance,
            token1.totalSupply,
            token1.stepPrice
        );

        if (!IERC20(token).transfer(msg.sender, amountOut))
            revert AMBRodeo__TokenTransferError(token);
        emit BuyTokens(token, msg.sender, msg.value, amountOut);
    }

    function sell(address token, uint amountIn) public {
        Token memory token1 = tokens[token];
        if (token1.totalSupply == 0) revert AMBRodeo__TokenNotExist(token);
        uint tokenBalance = IERC20(token).balanceOf(address(this));
        uint amountOut = calculateSell(
            amountIn,
            tokenBalance,
            token1.totalSupply,
            token1.stepPrice
        );
        if (!IERC20(token).transferFrom(msg.sender, address(this), amountIn))
            revert AMBRodeo__TokenTransferError(token);

        amountOut = incomeExchange(amountOut);
        payable(msg.sender).transfer(amountOut);
        emit SellTokens(token, msg.sender, amountIn, amountOut);
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function setCreatePrice(uint128 amount) public onlyOwner {
        createPrice = amount;
    }

    function setExchangePrice(uint128 amount) public onlyOwner {
        exchangePrice = amount;
    }
}