
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Magicnum.sol";

contract DeployTinyRuntime is Script {
    function run() external {
        vm.startBroadcast();

        bytes memory initCode = hex"602a60405260206040f3"; // runtime code
        Deployer deployer = new Deployer();

        address solver = deployer.deploy(initCode); // ← 배포된 주소 받아오기

        MagicNum magicNum = MagicNum(0x06bAc357645b0041910F101BEF2FFA6929ae4DCe);
        magicNum.setSolver(solver); // 설정 완료

        console2.log("Tiny contract deployed at:", solver);

        vm.stopBroadcast();
    }
}
