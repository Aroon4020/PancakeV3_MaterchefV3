// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;
pragma abicoder v2;
interface IVault {
    function addLiquidity(uint256 amount0, uint256 amount1, uint256 amount0Min, uint256 amount1Min, address recipient) external payable returns(uint256 shareAmount);
    function removeLiquidity(uint128 amount, uint256 amount0Min,uint256 amount1Min, address recipient) external returns(uint256 amount0,uint256 amount1);
    function harvest(uint256 amountOut0, uint256 amountOut1,bytes calldata route) external;
    function pauseAndWithdrawNFT() external;
    function unpauseAndDepositNFT() external; 
    function pauseVault() external;
    function unpauseVault() external;
    function emergencyExit(uint128 amount,
        uint256 amount0Min,
        uint256 amount1Min,
        address recipient) external;
    function pool()external returns(address);
    function fee() external returns(uint24);
    function tickLower() external returns(int24);
    function tickUpper() external returns(int24);
    function tokenId() external returns(uint256);
    function token0() external returns(address);
    function token1() external returns(address); 

}