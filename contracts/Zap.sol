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
import "./libraries/Swap.sol";
import "./libraries/Liquidity.sol";

contract Zap is IZap {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address WETH;

    address public swapRouter = 0x1b81D678ffb9C0263b24A97847620C99d213eB14;
    address public positionManager = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;

    function zapInSingle(
        address vault,
        address token0In,
        uint256 amountIn,
        address token1,
        uint256 amountOutMin
    ) external payable override {
        pay(token0In, amountIn);
        (uint256 res0, uint256 res1) = Liquidity.getAmountsForLiquidity(
            IVault(vault).pool(),
            positionManager,
            IVault(vault).tokenId(),
            IVault(vault).tickLower(),
            IVault(vault).tickUpper()
        );
        uint24 fee = IVault(vault).fee();
        bool isInputA = IVault(vault).token0() == token0In;
        uint256 amountToSwap = isInputA
            ? Swap.calculateSwapInAmount(res0, amountIn, fee)
            : Swap.calculateSwapInAmount(res1, amountIn, fee);
        uint256 amount1 = Swap.singleSwap(
            token0In,
            token1,
            amountToSwap,
            amountOutMin,
            fee,
            swapRouter
        );
        uint256 amount0 = IERC20(token0In).balanceOf(address(this));
        IERC20(token0In).safeApprove(vault, amount0);
        IERC20(token1).safeApprove(vault, amount1);
        uint256 shareAmount = IVault(vault).addLiquidity{
            value: address(this).balance
        }(
            amount0,
            amount1,
            (amount0 * 100) / 10_000,
            (amount1 * 100) / 10_000,
            msg.sender
        );
        Deposited(msg.sender, vault, amount0, amount1, shareAmount);
    }

    function zapInDual(
        address vault,
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1
    ) external payable override {
        pay(token0, amount0);
        pay(token1, amount1);
        IERC20(token0).safeApprove(vault, amount0);
        IERC20(token1).safeApprove(vault, amount1);
        uint256 shareAmount = IVault(vault).addLiquidity{value: msg.value}(
            amount0,
            amount1,
            (amount0 * 100) / 10_000,
            (amount1 * 100) / 10_000,
            msg.sender
        );
        Deposited(msg.sender, vault, amount0, amount1, shareAmount);
    }

    function zapOut(
        address vault,
        uint128 amount,
        uint256 amount0Min,
        uint256 amount1Min
    ) external override {
        require(vault != address(0), "Zero Address");
        require(amount > 0, "Zero Amount");
        pay(vault, amount);
        IERC20(vault).safeApprove(vault, amount);
        (uint256 amount0, uint256 amount1) = IVault(vault).removeLiquidity(
            amount,
            amount0Min,
            amount1Min,
            msg.sender
        );
        Withdrawn(msg.sender, vault, amount0, amount1);
    }

    function zapOutAndSwap(
        address vault,
        uint128 amount,
        address desiredToken,
        uint256 amountOut0Min,
        uint256 amountOut1Min,
        uint256 desiredTokenOutMin
    ) external override {
        pay(vault, amount);
        (uint256 amount0, uint256 amount1) = IVault(vault).removeLiquidity(
            amount,
            amountOut0Min,
            amountOut1Min,
            address(this)
        );
        //address token0 = IVault(vault).token0();
        address token1 = IVault(vault).token1();
        address swapToken = token1 == desiredToken ? IVault(vault).token0() : token1;
        uint256 amountOut = Swap.singleSwap(
            swapToken,
            desiredToken,
            IERC20(swapToken).balanceOf(address(this)),
            desiredTokenOutMin,
            IVault(vault).fee(),
            swapRouter
        );
        IERC20(desiredToken).safeTransfer(msg.sender, amountOut);
        Withdrawn(msg.sender, vault, amount0, amount1);
    }

    function pay(address _token, uint256 _amount) internal {
        if (_token == WETH && msg.value > 0) {
            require(msg.value == _amount, "Inconsistent Amount");
        } else {
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        }
    }
}
