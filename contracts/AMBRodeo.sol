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
        bool royaltyLock;
        uint40 createdAt;
        uint balance;
        uint maxSupply;
        uint balanceToDex;
        uint royaltyPercent;
        uint royalty;
        uint128[] curvePoints;
    }

    struct Settings {
        uint64 maxCurvePoints;
        bool createToken;
        address tokenImplemetation;
        address dex;
        uint balanceToDex;
        uint128 createFee;
        uint128 exchangeFeePercent;
    }

    struct CreateTokenParams {
        string name;
        string symbol;
        uint maxSupply;
        uint royaltyPercent;
        uint128[] curvePoints;
        bytes data;
    }

    uint32 public constant PERCENT_FACOTR = 100000;
    mapping(address => Token) public tokens;
    address[] public list;
    Settings public settings;
    uint public internalBalance;

    error AMBRodeo__TokenCreatePayment(uint required, uint value);
    error AMBRodeo__TokenCreationParams(string reason);
    error AMBRodeo__Custom(string reason);
    error AMBRodeo__NotActive();

    event CreateToken(address indexed token, bytes data);
    event TokenToDex(address indexed token, uint tokens, uint balance);
    event Swap(
        address indexed from,
        address indexed to,
        uint burn,
        uint mint,
        uint fee
    );
    event TokenTrade(
        address indexed token,
        address indexed account,
        uint input,
        uint output,
        uint fee,
        bool isMint
    );
    event GasCompensation(
        address indexed account,
        uint gas,
        uint gasprice,
        bool success
    );

    function initialize(Settings calldata _settings) public initializer {
        __Ownable_init(msg.sender);
        settings = _settings;
        AMBRodeoToken token = new AMBRodeoToken();
        token.init("default", "default");
        settings.tokenImplemetation = address(token);
    }

    function changeOwner(address token, address newOwner) external onlyOwner {
        AMBRodeoToken(token).transferOwnership(newOwner);
    }

    function upgradeSettings(Settings calldata _settings) external onlyOwner {
        settings = _settings;
    }

    function setTokenImplemetation(address token) external onlyOwner {
        settings.tokenImplemetation = token;
    }

    function setDex(address dex) external onlyOwner {
        settings.dex = dex;
    }

    function setBalanceToDex(uint balanceToDex) external onlyOwner {
        settings.balanceToDex = balanceToDex;
    }

    function setCreateFee(uint128 createFee) external onlyOwner {
        settings.createFee = createFee;
    }

    function setExchangeFee(uint32 exchangeFeePercent) external onlyOwner {
        if (exchangeFeePercent < PERCENT_FACOTR)
            settings.exchangeFeePercent = exchangeFeePercent;
    }

    function setCreateToken(bool createToken_) external onlyOwner {
        settings.createToken = createToken_;
    }

    function setActiveToken(address token, bool active_) external onlyOwner {
        tokens[token].active = active_;
    }

    function setToDexCustom(
        address token,
        uint balanceToDex
    ) external onlyOwner {
        tokens[token].balanceToDex = balanceToDex;
    }

    function getBalance() external view returns (uint) {
        return address(this).balance;
    }

    function tokensCount() external view returns (uint) {
        return list.length;
    }

    function transferInternalBalance(
        address to,
        uint128 amount
    ) external onlyOwner {
        if (amount < internalBalance) payable(to).transfer(amount);
    }

    function validateTokenParams(
        CreateTokenParams calldata params
    ) internal view {
        if (bytes(params.name).length == 0)
            revert AMBRodeo__TokenCreationParams("name");
        if (bytes(params.symbol).length == 0)
            revert AMBRodeo__TokenCreationParams("symbol");
        if (params.maxSupply == 0)
            revert AMBRodeo__TokenCreationParams("maxSupply");
        if (params.royaltyPercent >= 100000)
            revert AMBRodeo__TokenCreationParams("royaltyPercent");

        if (
            params.curvePoints.length == 0 ||
            params.curvePoints.length > settings.maxCurvePoints ||
            params.curvePoints[0] == 0
        ) revert AMBRodeo__TokenCreationParams("curvePoints");

        for (uint32 i = 1; i < params.curvePoints.length; i++) {
            if (params.curvePoints[i - 1] > params.curvePoints[i])
                revert AMBRodeo__TokenCreationParams("curvePoints");
        }
    }

    function takeRoyalty(address token, uint amount) internal returns (uint) {
        uint amount_ = (amount / PERCENT_FACOTR) * tokens[token].royaltyPercent;
        tokens[token].royalty += amount_;
        return amount - amount_;
    }

    function takeExchangeFee(uint amount) internal returns (uint) {
        uint amount_ = (amount / PERCENT_FACOTR) * settings.exchangeFeePercent;
        internalBalance += amount_;
        return amount - amount_;
    }

    function calculateMint(
        address token,
        uint amountIn
    ) public view returns (uint amountOut) {
        require(amountIn > 0, "AmountIn must be greater than 0");
        uint totalSupply = AMBRodeoToken(token).totalSupply();
        Token storage token_ = tokens[token];
        uint stepSize = token_.maxSupply / token_.curvePoints.length;

        while (true) {
            uint step = totalSupply / stepSize;
            uint remain = ((step + 1) * stepSize) - totalSupply;

            if (step == token_.curvePoints.length)
                revert AMBRodeo__Custom("There is not enough reserve");
            if (remain == 0) {
                remain = stepSize;
            }

            if (amountIn / token_.curvePoints[step] < remain) {
                amountOut += amountIn / token_.curvePoints[step];
                totalSupply += amountIn / token_.curvePoints[step];
                if (token_.maxSupply < totalSupply)
                    revert AMBRodeo__Custom("There is not enough reserve");
                break;
            }

            totalSupply += remain;
            amountIn -= remain * token_.curvePoints[step];
            amountOut += remain;
            if (token_.maxSupply < totalSupply)
                revert AMBRodeo__Custom("Max supply limit");
            if (amountIn == 0) break;
        }
    }

    function calculateBurn(
        address token,
        uint amountIn
    ) public view returns (uint amountOut) {
        require(amountIn > 0, "AmountIn must be greater than 0");
        uint totalSupply = AMBRodeoToken(token).totalSupply();
        Token storage token_ = tokens[token];
        uint stepSize = token_.maxSupply / token_.curvePoints.length;

        while (true) {
            uint step = totalSupply / stepSize;
            uint remain = stepSize - (((step + 1) * stepSize) - totalSupply);

            if (remain == 0) {
                if (step == 0)
                    revert AMBRodeo__Custom("There is not enough reserve");
                remain = stepSize;
                step--;
            }
            if (amountIn < remain) remain = amountIn;

            totalSupply -= remain;
            amountIn -= remain;
            amountOut += remain * token_.curvePoints[step];
            if (amountIn == 0) break;
        }
    }

    function createToken(CreateTokenParams calldata params) public payable {
        if (!settings.createToken) revert AMBRodeo__NotActive();
        if (msg.value < settings.createFee)
            revert AMBRodeo__TokenCreatePayment(settings.createFee, msg.value);

        validateTokenParams(params);
        AMBRodeoToken token = AMBRodeoToken(
            Clones.clone(settings.tokenImplemetation)
        );
        token.init(params.name, params.symbol);

        tokens[address(token)] = Token({
            creator: msg.sender,
            active: true,
            royaltyLock: true,
            createdAt: uint40(block.timestamp),
            balance: 0,
            maxSupply: params.maxSupply,
            balanceToDex: settings.balanceToDex,
            royaltyPercent: params.royaltyPercent,
            royalty: 0,
            curvePoints: params.curvePoints
        });
        list.push(address(token));

        internalBalance += settings.createFee;
        uint valueExcludeFee = msg.value - settings.createFee;

        if (valueExcludeFee > 0) {
            uint amountMint = calculateMint(address(token), valueExcludeFee);
            AMBRodeoToken(token).mint(msg.sender, amountMint);
            tokens[address(token)].balance += valueExcludeFee;
        }

        emit CreateToken(address(token), params.data);
    }

    function mint(address token) public payable {
        uint valueExcludedFee = takeExchangeFee(msg.value);
        uint valueExcludedRoyalty = takeRoyalty(token, valueExcludedFee);
        if (!tokens[token].active) revert AMBRodeo__NotActive();

        uint amountMint = calculateMint(token, valueExcludedRoyalty);
        AMBRodeoToken(token).mint(msg.sender, amountMint);
        tokens[token].balance += valueExcludedRoyalty;

        checkToDex(token);

        emit TokenTrade(
            token,
            msg.sender,
            msg.value,
            amountMint,
            msg.value - valueExcludedFee,
            true
        );
    }

    function burn(address token, uint amountBurn) public {
        if (!tokens[token].active) revert AMBRodeo__NotActive();
        uint amount = calculateBurn(token, amountBurn);
        AMBRodeoToken(token).burn(msg.sender, amountBurn);
        uint amountExcludedFee = takeExchangeFee(amount);
        uint amountExcludedRoyalty = takeRoyalty(token, amountExcludedFee);
        tokens[token].balance -= amount;
        payable(msg.sender).transfer(amountExcludedRoyalty);

        emit TokenTrade(
            token,
            msg.sender,
            amountBurn,
            amountExcludedFee,
            amount - amountExcludedFee,
            false
        );
    }

    function swap(
        address tokenBurn,
        address tokenMint,
        uint amountBurn
    ) external {
        uint amount = calculateBurn(tokenBurn, amountBurn);
        tokens[tokenBurn].balance -= amount;
        AMBRodeoToken(tokenBurn).burn(msg.sender, amountBurn);
        uint amountExcludedFee = takeExchangeFee(amount);
        uint amountExcludedRoyaltyBurn = takeRoyalty(
            tokenBurn,
            amountExcludedFee
        );
        uint amountExcludedRoyaltyMint = takeRoyalty(
            tokenMint,
            amountExcludedRoyaltyBurn
        );

        tokens[tokenMint].balance += amountExcludedRoyaltyMint;
        uint amountMint = calculateMint(tokenMint, amountExcludedRoyaltyMint);
        AMBRodeoToken(tokenMint).mint(msg.sender, amountMint);

        checkToDex(tokenMint);

        emit Swap(
            tokenBurn,
            tokenMint,
            amountBurn,
            amountMint,
            amount - amountExcludedFee
        );
    }

    function checkToDex(address token) internal {
        if (
            tokens[token].balanceToDex != 0 &&
            tokens[token].balance >= tokens[token].balanceToDex &&
            tokens[token].active
        ) toDex(token);
    }

    function toDex(address token) internal {
        uint gas = gasleft();
        uint amount = tokens[token].balance /
            tokens[token].curvePoints[
                (AMBRodeoToken(token).totalSupply() /
                    (tokens[token].maxSupply /
                        tokens[token].curvePoints.length))
            ];

        AMBRodeoToken(token).mint(settings.dex, amount);
        payable(settings.dex).transfer(tokens[token].balance);

        emit TokenToDex(token, amount, tokens[token].balance);
        tokens[token].balance = 0;
        tokens[token].active = false;
        tokens[token].royaltyLock = false;

        gas -= gasleft();
        uint128 compensation = uint128(gas * tx.gasprice);
        if (internalBalance > compensation) {
            (bool success, ) = msg.sender.call{value: compensation}("");
            if (success) internalBalance -= compensation;
            emit GasCompensation(msg.sender, gas, tx.gasprice, success);
        }
    }

    function transferRoyalty(address token, uint amount) public {
        if (tokens[token].creator != msg.sender || tokens[token].royaltyLock)
            revert AMBRodeo__Custom("You do not have permission");
        if (tokens[token].royalty < amount)
            revert AMBRodeo__Custom("Insufficient funds");

        tokens[token].royalty -= amount;
        payable(msg.sender).transfer(amount);
    }

    function changeCreator(address token, address newCreator) public {
        if (tokens[token].creator != msg.sender)
            revert AMBRodeo__Custom("You do not have permission");
        tokens[token].creator = newCreator;
    }
}
