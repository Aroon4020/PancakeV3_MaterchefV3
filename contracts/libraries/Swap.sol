// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;
import "@pancakeswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "../interfaces/common/IV3SwapRouter.sol";
import "@uniswap/lib/contracts/libraries/Babylonian.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

library Swap {

    using SafeMath for uint256;
    function singleSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountToSwap,
        uint256 amountOutMinimum,
        uint24 fee,
        address router
    ) internal returns(uint256){
        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: address(this),
                amountIn: amountToSwap,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0 // No price limit
            });
        return IV3SwapRouter(router).exactInputSingle(params);
    }

    


    function calculateSwapInAmount(
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
                return Babylonian
                    .sqrt(reserveIn.mul(userIn.mul(3988000)+
                        reserveIn.mul(3988009)
                       )
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