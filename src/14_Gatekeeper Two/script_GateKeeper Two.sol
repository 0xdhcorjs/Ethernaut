// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Mycontract.sol";


contract CounterScript is Script {
    address public addr;
    function run() external {
        vm.startBroadcast();
        addr = 0xa7757Ec7140bffD24bDa548830fe956C9E982590;
        Attack atk = new Attack(addr);
        vm.stopBroadcast();
    }
}