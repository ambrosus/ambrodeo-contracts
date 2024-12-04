// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;
import "@openzeppelin/contracts/access/Ownable.sol";

contract ProxyERC20 is Ownable(tx.origin) {
    bytes32 private constant IMPLEMENTATION_SLOT =
        keccak256("proxy.implementation.address");

    constructor(
        address _implementation,
        string memory name_,
        string memory symbol_,
        address account_,
        uint256 value_
    ) {
        _setImplementation(_implementation);
        (bool success, ) = _getImplementation().delegatecall(
            abi.encodeWithSignature(
                "init(string,string,address,uint256)",
                name_,
                symbol_,
                account_,
                value_
            )
        );
        require(success, "Init failed");
    }

    function _setImplementation(address _implementation) private {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, _implementation)
        }
    }

    function _getImplementation() public view returns (address implementation) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            implementation := sload(slot)
        }
    }

    function _delegate() private {
        address impl = _getImplementation();
        require(impl != address(0), "Implementation not set");

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    fallback() external payable {
        _delegate();
    }

    receive() external payable {
        _delegate();
    }
}
