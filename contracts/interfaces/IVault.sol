// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;
pragma abicoder v2;
interface IVault {

    event Deposited(
        address user,
        address vault,
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1,
        uint256 lpAmount
    );

    event Withdrawn(
        address user,
        address vault,
        uint256 amount0,
        uint256 amount1
    );

    event Fees(uint256 t0,uint256 t1);
    function zapInSingle(address tokenIn, uint256 amountIn,uint256 amountOutMin) external payable returns (uint256 shareAmount);
    function zapInDual(uint256 amount0, uint256 amount1, uint256 amount0Min, uint256 amount1Min) external payable returns(uint256 shareAmount);
    function zapOut(uint128 amount, uint256 amount0Min,uint256 amount1Min) external returns(uint256 amount0,uint256 amount1);
    function zapOutAndSwap(uint128 amount,
        uint256 amount0Min,
        uint256 amount1Min,
        address desiredToken,
        uint256 amountOutMin) external;
    function harvest(uint256 amountOut,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 amountOut1,
        bytes calldata _route) external;
    function pauseAndWithdrawNFT() external;
    function unpauseAndDepositNFT() external; 
    function pauseVault() external;
    function unpauseVault() external;
    function emergencyExit(uint128 amount,
        uint256 amount0Min,
        uint256 amount1Min) external;
    
    
}