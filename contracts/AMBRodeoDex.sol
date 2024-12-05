// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract AMBRodeoDex is Initializable, OwnableUpgradeable, PausableUpgradeable {
    mapping(address => uint256) public liquidity;
    address public factory;
    uint256 public initLiquidity;
    uint256 public fee;
    uint256 public feePool;

    event Buy(
        address indexed token,
        address indexed user,
        uint256 amountIn,
        uint256 amountOut
    );

    event Sell(
        address indexed token,
        address indexed user,
        uint256 amountIn,
        uint256 amountOut
    );

    event InitLiquidity(
        address indexed token,
        address indexed user,
        uint256 initLiquidity
    );

    event ChangeFee(uint256 fee);
    event TransferFee(address indexed account, uint256 value);
    event TransferToken(address indexed token, address indexed account);

    function initialize(
        uint256 initLiquidity_,
        uint256 fee_
    ) public initializer {
        __Ownable_init(msg.sender);
        initLiquidity = initLiquidity_;
        fee = fee_;
    }

    function setFactory(address factory_) external onlyOwner {
        factory = factory_;
    }

    function changeFee(uint256 fee_) external onlyOwner {
        fee = fee_;
        emit ChangeFee(fee);
    }

    function transferFee(address account, uint256 value) external onlyOwner {
        require(value <= feePool, "Doesn't have coins");
        payable(account).transfer(value);
        feePool -= value;
        emit TransferFee(account, value);
    }

    function transferToken(address token, address account) external onlyOwner {
        require(liquidity[token] > initLiquidity, "Token not have liquidity");
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        uint256 amountOut = swapIntoOut(
            initLiquidity,
            liquidity[token],
            tokenBalance
        );
        require(
            IERC20(token).transfer(address(0), amountOut),
            "Transfer failed"
        );
        require(
            IERC20(token).transfer(account, tokenBalance - amountOut),
            "Transfer failed"
        );

        payable(account).transfer(liquidity[token] - initLiquidity);
        liquidity[token] = 0;
        delete liquidity[token];

        emit TransferToken(token, account);
    }

    function swapIntoOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256) {
        require(amountIn > 0, "AmountIn must be greater than 0");
        require(
            reserveIn > 0 && reserveOut > 0,
            "Reserves must be greater than 0"
        );

        uint256 amountInK = amountIn * 1000;
        uint256 numerator = amountInK * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInK;
        return numerator / denominator;
    }

    function buy(address token) external payable whenNotPaused {
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        require(msg.value > 0, "Amount must be greater than 0");
        uint256 netAmountIn = (msg.value * (1000 - fee)) / 1000;

        uint256 amountOut = swapIntoOut(
            netAmountIn,
            liquidity[token],
            tokenBalance
        );
        require(amountOut < tokenBalance, "Doesn't have tokens");

        require(
            IERC20(token).transfer(tx.origin, amountOut),
            "Transfer failed"
        );

        liquidity[token] += netAmountIn;
        feePool += msg.value - netAmountIn;
        emit Buy(token, tx.origin, netAmountIn, amountOut);
    }

    function sell(address token, uint256 amountIn) external whenNotPaused {
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        uint256 amountOut = swapIntoOut(
            amountIn,
            tokenBalance,
            liquidity[token]
        );
        require(amountOut < liquidity[token], "Doesn't have coins");
        require(
            IERC20(token).transferFrom(msg.sender, address(this), amountIn),
            "Transfer failed"
        );

        uint256 netAmountOut = (amountOut * (1000 - fee)) / 1000;
        feePool += amountOut - netAmountOut;

        payable(msg.sender).transfer(netAmountOut);

        liquidity[token] -= amountOut;
        emit Sell(token, msg.sender, amountIn, netAmountOut);
    }

    function initLiquidityToken(address token) external payable whenNotPaused {
        if (msg.sender == factory) {
            liquidity[token] += initLiquidity;
            emit InitLiquidity(token, msg.sender, initLiquidity);
        }
    }

    function setPause(bool isPause) external onlyOwner {
        if (isPause) {
            _pause();
        } else {
            _unpause();
        }
    }
}
