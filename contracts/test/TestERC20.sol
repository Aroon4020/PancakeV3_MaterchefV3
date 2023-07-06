// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";
contract TESTERC20 is ERC20{
    constructor()  ERC20("TEST","test"){}

    function mint(uint256 amount) external{
        _mint(msg.sender,amount);
    }

}