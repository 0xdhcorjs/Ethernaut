// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import "../src/Mycontract.sol";

contract CounterScript is Script {
    address public addr;
    function run() external {
        vm.startBroadcast();
        address addr = 0xdf4475E1d639C700D171105DCE103297aC15DE94;

        Attack Force = new Attack{ value : 0.0001 ether}(addr);
        Force.attack();
        vm.stopBroadcast();
    }
}
