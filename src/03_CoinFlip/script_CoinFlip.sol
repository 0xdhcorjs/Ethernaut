// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import "../src/Mycontract.sol";

contract CounterScript is Script {
    function run() external {
        vm.startBroadcast();

        Attack Flip = new Attack(0xcE15dA800136f96eeb2d15ACAcB1e711568f1E8A);
        
        Flip.attack();

        vm.stopBroadcast();
    }
}
