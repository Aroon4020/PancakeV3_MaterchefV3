// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;
import "../interfaces/common/IV3SwapRouter.sol";
import "@uniswap/lib/contracts/libraries/Babylonian.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";
contract TestSwap {

    using SafeMath for uint256;
    function singleSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountToSwap,
        uint256 amountOutMinimum,
        uint24 fee,
        address router
    ) external payable {
        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: msg.sender,
                amountIn: amountToSwap,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0 // No price limit
            });
            console.log("###############3");
        IV3SwapRouter(router).exactInputSingle{value: msg.value}(params);
        //ISwapRouter(router).refundETH();
        (bool success,) = msg.sender.call{ value: address(this).balance }("");
        require(success, "refund failed");

    }

    // function batchSwap(
    //     uint256 amountToSwap,
    //     uint256 amountOutMinimum,
    //     bytes calldata route,
    //     address router
    // ) external payable returns (uint256 amountOut) {
    //     ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
    //         path:route,
    //         recipient: msg.sender, // Send the output tokens to this contract
    //         deadline: block.timestamp,
    //         amountIn: amountToSwap,
    //         amountOutMinimum: amountOutMinimum
    //     });
    //     return ISwapRouter(router).exactInput{value: amountToSwap}(params);
    // }


    function calculateSwapInAmount(
        //0.01% Fee
        uint256 reserveIn,
        uint256 userIn,
        uint24 _fee
    ) internal pure returns (uint256) {
        if (_fee == 100) {
            return
                Babylonian
                    .sqrt(
                        reserveIn.mul(3999600) +
                            reserveIn.mul(userIn.mul(3999600))
                    )
                    .sub(reserveIn.mul(2000)) / 2000;
        } else if (_fee == 500) {
            return
                Babylonian
                    .sqrt(
                        reserveIn.mul(3998000) +
                            reserveIn.mul(userIn.mul(3998000))
                    )
                    .sub(reserveIn.mul(2000)) / 1999;
        } else if (_fee == 2500) {
            return
                Babylonian
                    .sqrt(
                        reserveIn.mul(3988009) +
                            reserveIn.mul(userIn.mul(3988000))
                    )
                    .sub(reserveIn.mul(1997)) / 1994;
        } else if (_fee == 10000) {
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
    
}