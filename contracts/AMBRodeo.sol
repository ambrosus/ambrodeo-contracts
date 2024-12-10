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
        uint balance;
        uint balanceToDex;
        address creator;
        uint128 totalSupply;
        uint128[] stepPrice;
        bool active;
    }

    uint32 public constant MAX_STEPS = 1000;
    mapping(address => Token) public tokens;
    address public tokenImplemetation;
    address public dex;
    address[] public tokensList;
    uint public balanceToDex;
    uint128 public createFee;
    uint128 public exchangeFee;
    uint128 public income;

    error AMBRodeo__InvalidTokenCreationParams(string reason);
    error AMBRodeo__InvalidInitializeToken();
    error AMBRodeo__TokenNotExist(address token);
    error AMBRodeo__TokenNotActive(address token);
    error AMBRodeo__TokenTransferError(address token);
    error AMBRodeo__NotEnoughPayment();
    error AMBRodeo__NotEnoughIncom();
    error AMBRodeo__TransferToDexError(
        address token,
        uint tokenBalance,
        uint balance
    );
    error AMBRodeo__BurnTokensError(
        address token,
        uint tokenBalance,
        uint amount
    );

    event CreateToken(
        address indexed token,
        address indexed account,
        string indexed name,
        string symbol,
        uint totalSupply,
        string imageUrl,
        uint value,
        uint128[] stepPrice
    );
    event ChangeOwner(address indexed token, address indexed to);
    event TokenTrade(
        address indexed token,
        address indexed account,
        uint input,
        uint output,
        uint reserveTokens,
        uint balanceToken,
        bool isBuy
    );

    event TransferToDex(address indexed token, uint tokenBalance, uint balance);
    event ChangeBalanceToDexForToken(address indexed token, uint newBalance);
    event GasCompensation(
        address to,
        uint256 gas,
        uint256 price,
        uint256 compensation,
        bool success
    );

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
        if (msg.value != createFee) revert AMBRodeo__NotEnoughPayment();
        income += createFee;

        validateParams(params);
        AMBRodeoToken token = AMBRodeoToken(Clones.clone(tokenImplemetation));
        token.init(
            params.name,
            params.symbol,
            address(this),
            params.totalSupply
        );

        tokens[address(token)] = Token(
            0,
            balanceToDex,
            msg.sender,
            params.totalSupply,
            params.stepPrice,
            true
        );
        tokensList.push(address(token));

        emit CreateToken(
            address(token),
            msg.sender,
            params.name,
            params.symbol,
            params.totalSupply,
            params.imageUrl,
            msg.value,
            params.stepPrice
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
        if (input < exchangeFee) revert AMBRodeo__NotEnoughPayment();
        income += exchangeFee;
        return input - exchangeFee;
    }

    function buy(address token) public payable {
        uint value = incomeExchange(msg.value);
        if (!tokens[token].active) revert AMBRodeo__TokenNotActive(token);
        uint tokenBalance = IERC20(token).balanceOf(address(this));
        uint amountOut = calculateBuy(
            value,
            tokenBalance,
            tokens[token].totalSupply,
            tokens[token].stepPrice
        );

        if (!IERC20(token).transfer(msg.sender, amountOut))
            revert AMBRodeo__TokenTransferError(token);
        tokens[token].balance += value;

        if (
            tokens[token].balanceToDex != 0 &&
            tokens[token].balance >= tokens[token].balanceToDex
        ) toDex(token);
        emit TokenTrade(
            token,
            msg.sender,
            msg.value,
            amountOut,
            IERC20(token).balanceOf(address(this)),
            tokens[token].balance,
            true
        );
    }

    function sell(address token, uint amountIn) public {
        if (!tokens[token].active) revert AMBRodeo__TokenNotActive(token);
        uint tokenBalance = IERC20(token).balanceOf(address(this));
        uint amountOut = calculateSell(
            amountIn,
            tokenBalance,
            tokens[token].totalSupply,
            tokens[token].stepPrice
        );
        if (!IERC20(token).transferFrom(msg.sender, address(this), amountIn))
            revert AMBRodeo__TokenTransferError(token);

        amountOut = incomeExchange(amountOut);
        payable(msg.sender).transfer(amountOut);
        tokens[token].balance -= amountOut;
        emit TokenTrade(
            token,
            msg.sender,
            amountIn,
            amountOut,
            IERC20(token).balanceOf(address(this)),
            tokens[token].balance,
            false
        );
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function setCreateFee(uint128 amount) public onlyOwner {
        createFee = amount;
    }

    function setExchangeFee(uint128 amount) public onlyOwner {
        exchangeFee = amount;
    }

    function transferIncome(address to, uint128 amount) public onlyOwner {
        if (amount > income) revert AMBRodeo__NotEnoughIncom();
        payable(to).transfer(amount);
    }

    function setDex(address dex_) public onlyOwner {
        dex = dex_;
    }

    function setBalanceToDex(uint balance) public onlyOwner {
        balanceToDex = balance;
    }

    function toDex(address token) internal {
        uint256 gas = gasleft();
        uint tokenBalance = IERC20(token).balanceOf(address(this));
        if (
            tokenBalance == 0 ||
            tokens[token].balance < tokens[token].balanceToDex ||
            !tokens[token].active
        )
            revert AMBRodeo__TransferToDexError(
                token,
                tokenBalance,
                tokens[token].balance
            );

        uint stepSize = tokens[token].totalSupply /
            tokens[token].stepPrice.length;
        uint curentStep = (tokens[token].totalSupply -
            IERC20(token).balanceOf(address(this))) / stepSize;
        uint amount = tokens[token].balance /
            tokens[token].stepPrice[curentStep];

        if (!AMBRodeoToken(token).burn(tokenBalance - amount))
            revert AMBRodeo__BurnTokensError(token, tokenBalance, amount);

        if (!IERC20(token).transfer(dex, amount))
            revert AMBRodeo__TransferToDexError(
                token,
                amount,
                tokens[token].balance
            );
        payable(dex).transfer(tokens[token].balance);

        tokens[token].balance = 0;
        tokens[token].active = false;
        emit TransferToDex(token, amount, tokens[token].balance);
        gas -= gasleft();
        uint128 compensation = uint128(gas * tx.gasprice);
        if (income > compensation) {
            (bool success, ) = msg.sender.call{value: compensation}("");
            if (success) income -= compensation;
            emit GasCompensation(
                msg.sender,
                gas,
                tx.gasprice,
                compensation,
                success
            );
        }
    }

    function setBalanceToDexCustom(
        address token,
        uint newBalance
    ) external onlyOwner {
        if (!tokens[token].active) revert AMBRodeo__TokenNotActive(token);
        tokens[token].balanceToDex = newBalance;
        emit ChangeBalanceToDexForToken(token, newBalance);
    }
}
