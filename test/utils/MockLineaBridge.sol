// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.22;

contract MockLineaBridge {
    address private _sender;

    function sender() external view returns (address) {
        return _sender;
    }

    function claimMessage(
        address from,
        address to,
        uint256,
        uint256 value,
        address payable,
        bytes calldata data,
        uint256
    ) external {
        _sender = from;

        (bool success,) = to.call{value: value}(data);

        if (!success) {
            assembly {
                if returndatasize() {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }

            revert("relayMessage failed");
        }
    }
}
