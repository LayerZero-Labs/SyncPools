// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.22;

contract MockModeBridge {
    address private _sender;

    function xDomainMessageSender() external view returns (address) {
        return _sender;
    }

    function relayMessage(uint256, address sender, address target, uint256 value, uint256, bytes memory message)
        external
        payable
    {
        _sender = sender;

        (bool success,) = target.call{value: value}(message);

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
