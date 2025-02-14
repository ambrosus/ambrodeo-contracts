// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./AMBRodeoToken.sol";

contract AMBRodeo is Initializable, OwnableUpgradeable {
    struct Token {
        address creator;
        bool active;
        uint256 balance;
        uint256 virtualLiquidity;
        uint256 virtualToken;
    }

    struct Settings {
        bool createToken;
        address tokenImplemetation;
        address dex;
        uint256 balanceToDex;
        uint256 createFee;
        uint256 exchangeFee;
        uint256 toDexFee;
        uint256 totalSupply;
        uint256 virtualLiquidity;
        uint256 virtualToken;
        bool initLiquidity;
    }

    uint256 public constant PERCENT_FACTOR = 100000;
    Settings public settings;
    mapping(address => Token) public tokens;
    address[] public list;
    uint256 public internalBalance;

    error AMBRodeoError(string reason);
    error AMBRodeoErrorCreateFee(uint256, uint256);

    event CreateToken(
        address token,
        address account,
        string name,
        string symbol,
        uint256 totalSupply,
        bytes data
    );

    event TokenTrade(
        address indexed token,
        address indexed account,
        uint256 amountIn,
        uint256 excludeFee,
        uint256 amountOut,
        uint256 liquidity,
        uint256 balanceToDex,
        bool isBuy
    );

    event LiquidityTrade(
        address token,
        uint256 liquidity,
        uint256 virtualLiquidity,
        uint256 tokenBlanace,
        uint256 virtualToken
    );

    event TransferToDex(
        address indexed token,
        uint tokenBalance,
        uint balance,
        uint liquidity
    );

    event GasCompensation(
        address indexed to,
        uint256 gas,
        uint256 price,
        uint256 compensation,
        bool success
    );

    function initialize(Settings calldata _settings) external initializer {
        __Ownable_init(msg.sender);
        settings = _settings;
        AMBRodeoToken tokenImplementation = new AMBRodeoToken();
        tokenImplementation.init("default", "default", 0);
        settings.tokenImplemetation = address(tokenImplementation);
    }

    function setTokenImplemetation(
        address tokenImplementation
    ) external onlyOwner {
        settings.tokenImplemetation = tokenImplementation;
    }

    function setCreateToken() external onlyOwner {
        if (settings.createToken) {
            settings.createToken = false;
            return;
        }
        settings.createToken = true;
    }

    function transferInternalBalance(
        address to,
        uint256 amount
    ) external onlyOwner {
        if (amount <= internalBalance) {
            payable(to).transfer(amount);
            internalBalance -= amount;
        }
    }

    function setVirtualLiquidity(uint256 amount) external onlyOwner {
        settings.virtualLiquidity = amount;
    }

    function setInitLiquidity() external onlyOwner {
        if (settings.initLiquidity) {
            settings.initLiquidity = false;
            return;
        }
        settings.initLiquidity = true;
    }

    function setDex(address dex) external onlyOwner {
        settings.dex = dex;
    }

    function setBalanceToDex(uint256 amount) external onlyOwner {
        settings.balanceToDex = amount;
    }

    function setCreateFee(uint256 amount) external onlyOwner {
        settings.createFee = amount;
    }

    function setExchangeFee(uint256 amount) external onlyOwner {
        settings.exchangeFee = amount;
    }

    function setTotalSupply(uint256 amount) external onlyOwner {
        settings.totalSupply = amount;
    }

    function setVirtualToken(uint256 amount) external onlyOwner {
        settings.virtualToken = amount;
    }

    function excludeExchangeFee(uint256 input) internal returns (uint256) {
        uint256 amount = uint256(
            (input / PERCENT_FACTOR) * settings.exchangeFee
        );
        internalBalance += amount;
        return input - amount;
    }

    function tokenChangeOwner(
        address token,
        address newOwner
    ) external onlyOwner {
        AMBRodeoToken(token).transferOwnership(newOwner);
    }

    function setActiveToken(address token) external onlyOwner {
        if (tokens[token].active) {
            tokens[token].active = false;
            return;
        }
        tokens[token].active = true;
    }

    function createToken(
        uint256 amount,
        string calldata name,
        string calldata symbol,
        bytes calldata data
    ) external payable {
        if (bytes(name).length == 0) revert AMBRodeoError("Short token name");
        if (bytes(symbol).length == 0)
            revert AMBRodeoError("Short token symbol");
        if (!settings.createToken)
            revert AMBRodeoError("Tokens create disabled");
        if (msg.value < settings.createFee)
            revert AMBRodeoErrorCreateFee(settings.createFee, msg.value);

        if (settings.totalSupply == 0 || settings.virtualLiquidity == 0)
            revert AMBRodeoError("Settings error");

        AMBRodeoToken token = AMBRodeoToken(
            Clones.clone(settings.tokenImplemetation)
        );
        token.init(name, symbol, settings.totalSupply);

        tokens[address(token)] = Token({
            creator: msg.sender,
            active: true,
            balance: settings.virtualLiquidity,
            virtualLiquidity: settings.virtualLiquidity,
            virtualToken: settings.virtualToken
        });
        list.push(address(token));

        // if (msg.value > settings.createFee)
        //     payable(msg.sender).transfer(msg.value - settings.createFee);
        internalBalance += settings.createFee;
        emit CreateToken(
            address(token),
            msg.sender,
            name,
            symbol,
            settings.totalSupply,
            data
        );

        if (msg.value > settings.createFee) {
            uint256 amountIn = msg.value - settings.createFee;
            (uint256 amountOut, uint256 newReserveCoin) = calculateBuy(
                address(token),
                amountIn
            );

            if (
                tokens[address(token)].virtualLiquidity == 1 &&
                settings.initLiquidity
            ) {
                amountOut = amount;
                newReserveCoin = msg.value - settings.createFee;
            }

            tokens[address(token)].balance = newReserveCoin;
            if (!IERC20(token).transfer(msg.sender, amountOut))
                revert AMBRodeoError("Transfer token failed");

            if (
                settings.balanceToDex != 0 &&
                tokens[address(token)].balance >= settings.balanceToDex
            ) toDex(address(token));

            emit TokenTrade(
                address(token),
                msg.sender,
                msg.value,
                amountIn,
                amountOut,
                tokens[address(token)].balance -
                    tokens[address(token)].virtualLiquidity,
                settings.balanceToDex,
                true
            );
        }
        emit LiquidityTrade(
            address(token),
            tokens[address(token)].balance,
            tokens[address(token)].virtualLiquidity,
            IERC20(token).balanceOf(address(this)),
            tokens[address(token)].virtualToken
        );
    }

    function calculateBuy(
        address token,
        uint256 amountCoinIn
    ) public view returns (uint256 amountTokenOut, uint256 newReserveCoin) {
        require(amountCoinIn > 0, "Amount must be greater than 0");
        uint256 reserveToken = (IERC20(token).balanceOf(address(this)) +
            tokens[token].virtualToken);
        uint256 k = tokens[token].balance * reserveToken;
        newReserveCoin = tokens[token].balance + amountCoinIn;
        uint256 newReserveToken = k / newReserveCoin;
        amountTokenOut = reserveToken - newReserveToken;
    }

    function calculateSell(
        address token,
        uint256 amountTokenIn
    ) public view returns (uint256 amountCoinOut, uint256 newReserveCoin) {
        require(amountTokenIn > 0, "Amount must be greater than 0");
        uint256 reserveToken = (IERC20(token).balanceOf(address(this)) +
            tokens[token].virtualToken);
        uint256 k = tokens[token].balance * reserveToken;
        uint256 newReserveToken = reserveToken + amountTokenIn;
        newReserveCoin = k / newReserveToken;
        amountCoinOut = tokens[token].balance - newReserveCoin;
    }

    function buy(address token) public payable {
        uint256 amountIn = excludeExchangeFee(msg.value);

        if (
            settings.balanceToDex <
            (tokens[token].balance - tokens[token].virtualLiquidity) + amountIn
        ) {
            uint256 excess = ((tokens[token].balance -
                tokens[token].virtualLiquidity) + amountIn) -
                settings.balanceToDex;

            (bool success, ) = msg.sender.call{value: excess}("");
            if (!success) revert AMBRodeoError("Transfer excess failed");
            amountIn -= excess;
        }

        if (!tokens[token].active) revert AMBRodeoError("Token not active");
        (uint256 amountOut, uint256 newReserveCoin) = calculateBuy(
            token,
            amountIn
        );
        tokens[token].balance = newReserveCoin;
        if (!IERC20(token).transfer(msg.sender, amountOut))
            revert AMBRodeoError("Transfer token failed");

        emit TokenTrade(
            token,
            msg.sender,
            msg.value,
            amountIn,
            amountOut,
            tokens[token].balance - tokens[token].virtualLiquidity,
            settings.balanceToDex,
            true
        );
        emit LiquidityTrade(
            token,
            tokens[token].balance,
            tokens[token].virtualLiquidity,
            IERC20(token).balanceOf(address(this)),
            tokens[token].virtualToken
        );
        if (
            settings.balanceToDex != 0 &&
            (tokens[token].balance - tokens[token].virtualLiquidity) >=
            settings.balanceToDex
        ) toDex(token);
    }

    function sell(address token, uint256 amount) public {
        if (!tokens[token].active) revert AMBRodeoError("Token not active");
        (uint256 amountOut, uint256 newReserveCoin) = calculateSell(
            token,
            amount
        );
        tokens[token].balance = newReserveCoin;
        uint256 amountOutExcludeFee = excludeExchangeFee(amountOut);
        if (!IERC20(token).transferFrom(msg.sender, address(this), amount))
            revert AMBRodeoError("Transfer token failed");

        payable(msg.sender).transfer(amountOutExcludeFee);
        emit TokenTrade(
            token,
            msg.sender,
            amount,
            amountOutExcludeFee,
            amountOut,
            tokens[token].balance - tokens[token].virtualLiquidity,
            settings.balanceToDex,
            false
        );
        emit LiquidityTrade(
            token,
            tokens[token].balance,
            tokens[token].virtualLiquidity,
            IERC20(token).balanceOf(address(this)),
            tokens[token].virtualToken
        );
    }

    function toDex(address token) internal {
        uint256 gas = gasleft();
        excludeInternalLiquidity(token);
        uint256 amount = IERC20(token).balanceOf(address(this));
        IERC20(token).approve(settings.dex, amount);
        (bool success, bytes memory data) = settings.dex.call{
            value: tokens[token].balance
        }(
            abi.encodeWithSignature(
                "addLiquidityAMB(address,uint256,uint256,uint256,address,uint256)",
                token,
                amount,
                amount,
                tokens[token].balance,
                address(this),
                block.timestamp
            )
        );
        if (!success) revert AMBRodeoError("Transfer liquidity to dex failed");

        (uint256 amountToken, uint256 amountAMB, uint256 liquidity) = abi
            .decode(data, (uint256, uint256, uint256));
        tokens[token].balance = 0;
        tokens[token].active = false;
        emit TransferToDex(token, amountToken, amountAMB, liquidity);

        gas -= gasleft();
        uint128 compensation = uint128(gas * tx.gasprice);
        if (internalBalance > compensation) {
            (bool success1, ) = msg.sender.call{value: compensation}("");
            if (success1) internalBalance -= compensation;
            emit GasCompensation(
                msg.sender,
                gas,
                tx.gasprice,
                compensation,
                success1
            );
        }
    }

    function excludeInternalLiquidity(address token) internal {
        (uint256 amountOut, ) = calculateBuy(token, 1e8);

        tokens[token].balance -= tokens[token].virtualLiquidity;
        excludeToDexFee(token);

        uint256 amount = (tokens[token].balance / 1e8) * amountOut;
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        if (amount > tokenBalance) {
            AMBRodeoToken(token).mint(amount - tokenBalance);
        } else if (amount < tokenBalance) {
            AMBRodeoToken(token).burn(tokenBalance - amount);
        }
    }

    function excludeToDexFee(address token) internal {
        tokens[token].balance -= settings.toDexFee;
        internalBalance += settings.toDexFee;
    }

    function getCreateFee() public view returns (uint256) {
        return settings.createFee;
    }

    function getExchangeFee() public view returns (uint256) {
        return settings.exchangeFee;
    }

    function getBalanceToDex() public view returns (uint256) {
        return settings.balanceToDex;
    }

    function getTotalSupply() public view returns (uint256) {
        return settings.totalSupply;
    }

    function getTokenSales(address token) public view returns (uint256) {
        return
            IERC20(token).totalSupply() -
            IERC20(token).balanceOf(address(this));
    }
}
