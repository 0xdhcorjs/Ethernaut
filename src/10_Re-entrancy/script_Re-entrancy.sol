// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Mycontract.sol";

contract CounterScript is Script {
    address public addr;
    function run() external {
        vm.startBroadcast();
        addr = 0x86eAEBe3e3A1c6ab7Aa45f3b1DbdA67fFA9Ec354;
        Attack att = new Attack(addr);

        att.attack{value : 0.001 ether}();

        vm.stopBroadcast();
    }
}
