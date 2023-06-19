
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
interface IZap {

    event Deposited(
        address user,
        address vault,
        uint256 amount0,
        uint256 amount1,
        uint256 lpAmount
    );

    event Withdrawn(
        address user,
        address vault,
        uint256 amount0,
        uint256 amount1
    );
    
    function zapInSingle(
        address vault,
        address token0In,
        uint256 amountIn,
        address token1,
        uint256 amountOutMin
    ) external payable;

    function zapInDual(
        address vault,
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1
    ) external payable;

    function zapOut(
        address vault, 
        uint256 amount,
        uint256 amount0Min, 
        uint256 amount1Min
    ) external;

    function zapOutAndSwap(
        address vault,
        uint256 amount,
        address desiredToken,
        uint256 desiredTokenOutMin
    ) external;

}