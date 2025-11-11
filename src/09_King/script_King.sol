// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Mycontract.sol";

contract CounterScript is Script {
    address public addr;
    function run() external {
        vm.startBroadcast();
        addr = 0xcF378782D17d953529f201fF045047914F073aec;
        ForeverKing forever = new ForeverKing(addr);

        forever.Throne{value : 0.01 ether}();

        vm.stopBroadcast();
    }
}
