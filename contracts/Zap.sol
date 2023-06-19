// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

pragma abicoder v2;

import "@pancakeswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@pancakeswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@pancakeswap/v3-core/contracts/interfaces/IPancakeV3Pool.sol";
import "@pancakeswap/v3-core/contracts/libraries/FullMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/lib/contracts/libraries/Babylonian.sol";
import "@pancakeswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@pancakeswap/v3-core/contracts/libraries/TickMath.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IZap.sol";
import "hardhat/console.sol";

contract Zap is IZap {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    ISwapRouter private swapRouter =
        ISwapRouter(0x1b81D678ffb9C0263b24A97847620C99d213eB14);
    INonfungiblePositionManager private positionManager =
        INonfungiblePositionManager(0x46A15B0b27311cedF172AB29E4f4766fbE7F4364);

    function zapInSingle(
        address vault,
        address token0In,
        uint256 amountIn,
        address token1,
        uint256 amountOutMin
    ) external payable override {
        IERC20(token0In).transferFrom(msg.sender, address(this), amountIn);
        IPancakeV3Pool pool = IPancakeV3Pool(IVault(vault).pool());
        (uint256 res0, uint256 res1) = getAmountsForLiquidity(
            pool,
            IVault(vault)
        );
        bool isInputA = pool.token0() == token0In;
        uint256 amountToSwap = isInputA
            ? _calculateSwapInAmount(res0, amountIn, pool.fee())
            : _calculateSwapInAmount(res1, amountIn, pool.fee());
        uint256 amount1 = swap(
            token0In,
            token1,
            pool.fee(),
            amountToSwap,
            amountOutMin
        );
        uint256 amount0 = IERC20(token0In).balanceOf(address(this));
        IERC20(token0In).safeApprove(vault, amount0);
        IERC20(token1).safeApprove(vault, amount1);
        uint256 shareAmount = IVault(vault).addLiquidity{value: address(this).balance}(
            amount0,
            amount1,
            (amount0 * 100) / 10_000,
            (amount1 * 100) / 10_000,
            msg.sender
        );
        Deposited(msg.sender,vault,amount0,amount1, shareAmount);
    }

    function zapInDual(
        address vault,
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1
    ) external payable override {
        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);
        IERC20(token0).safeApprove(vault, amount0);
        IERC20(token1).safeApprove(vault, amount1);
        uint256 shareAmount = IVault(vault).addLiquidity{value: msg.value}(
            amount0,
            amount1,
            (amount0 * 100) / 10_000,
            (amount1 * 100) / 10_000,
            msg.sender
        );
        Deposited(msg.sender,vault,amount0,amount1, shareAmount);
    }

    function zapOut(
        address vault,
        uint256 amount,
        uint256 amount0Min,
        uint256 amount1Min
    ) external override {
        require(vault != address(0), "Zero Address");
        require(amount > 0, "Zero Amount");
        IERC20(vault).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(vault).safeApprove(vault, amount);
        (uint256 amount0,uint256 amount1) = IVault(vault).removeLiquidity(
            amount,
            amount0Min,
            amount1Min,
            msg.sender
        );

        Withdrawn(msg.sender,vault,amount0,amount1);
    }

    function zapOutAndSwap(
        address vault,
        uint256 amount,
        address desiredToken,
        uint256 desiredTokenOutMin
    ) external override {
        require(
            vault != address(0) && desiredToken != address(0),
            "Zero Address"
        );
        require(amount > 0 && desiredTokenOutMin > 0, "Zero Amount");
        IERC20(vault).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(vault).safeApprove(vault, amount);
        (uint256 amount0,uint256 amount1) = IVault(vault).removeLiquidity(amount, 0, 0, msg.sender);
        IPancakeV3Pool pool = IPancakeV3Pool(IVault(vault).pool());
        address token0 = pool.token0();
        address token1 = pool.token1();
        address swapToken = token1 == desiredToken ? token0 : token1;
        uint256 amountOut = swap(
            swapToken,
            desiredToken,
            pool.fee(),
            IERC20(swapToken).balanceOf(address(this)),
            desiredTokenOutMin
        );
        IERC20(desiredToken).safeTransfer(msg.sender, amountOut);
        Withdrawn(msg.sender,vault,amount0,amount1);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountToSwap,
        uint256 amountOutMinimum
    ) public returns (uint256 amountOut) {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: address(this), // Send the output tokens to this contract
                deadline: block.timestamp,
                amountIn: amountToSwap,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0 // No price limit
            });
        return swapRouter.exactInputSingle{value: amountToSwap}(params);
    }

    function _calculateSwapInAmount(
        //0.01% Fee
        uint256 reserveIn,
        uint256 userIn,
        uint24 fee
    ) private pure returns (uint256) {
        if (fee == 100) {
            return
                Babylonian
                    .sqrt(
                        reserveIn.mul(3999600) +
                            reserveIn.mul(userIn.mul(3999600))
                    )
                    .sub(reserveIn.mul(2000)) / 2000;
        } else if (fee == 500) {
            return
                Babylonian
                    .sqrt(
                        reserveIn.mul(3998000) +
                            reserveIn.mul(userIn.mul(3998000))
                    )
                    .sub(reserveIn.mul(2000)) / 1999;
        } else if (fee == 2500) {
            return
                Babylonian
                    .sqrt(
                        reserveIn.mul(3988009) +
                            reserveIn.mul(userIn.mul(3988000))
                    )
                    .sub(reserveIn.mul(1997)) / 1994;
        } else if (fee == 10000) {
            return
                Babylonian
                    .sqrt(
                        reserveIn.mul(3960100) +
                            reserveIn.mul(userIn.mul(3960000))
                    )
                    .sub(reserveIn.mul(1990)) / 1980;
        } else {
            revert("invalid fee");
        }
    }

    // function _calculateSwapInAmount1(//0.05
    //     uint256 reserveIn,
    //     uint256 userIn
    // ) private pure returns (uint256) {
    //     return
    //         Babylonian
    //             .sqrt(
    //                 reserveIn.mul(3998000)+reserveIn.mul(userIn.mul(3998000))
    //             )
    //             .sub(reserveIn.mul(2000)) / 1999;//3980000
    // }

    // function _calculateSwapInAmount2(//0.25%
    //     uint256 reserveIn,
    //     uint256 userIn
    // ) private pure returns (uint256) {
    //     return
    //         Babylonian
    //             .sqrt(
    //                reserveIn.mul(3988009) + reserveIn.mul(userIn.mul(3988000))
    //             )
    //             .sub(reserveIn.mul(1997)) / 1994;
    // }

    // function _calculateSwapInAmount3(//1%
    //     uint256 reserveIn,
    //     uint256 userIn
    // ) private pure returns (uint256) {
    //     return
    //         Babylonian
    //             .sqrt(
    //                 reserveIn.mul(3960100) + reserveIn.mul(userIn.mul(3960000))
    //             )
    //             .sub(reserveIn.mul(1990)) / 1980;//3980000
    // }

    function getAmountsForLiquidity(
        IPancakeV3Pool pool,
        IVault vault
    ) internal returns (uint256, uint256) {
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        return
            LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(vault.tickLower()),
                TickMath.getSqrtRatioAtTick(vault.tickUpper()),
                pool.liquidity()
            );
    }
}
