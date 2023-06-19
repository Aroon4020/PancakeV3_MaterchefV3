// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@pancakeswap/v3-core/contracts/interfaces/IPancakeV3Pool.sol";
import "@pancakeswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@pancakeswap/v3-core/contracts/libraries/TickMath.sol";
import "./interfaces/common/IMCV3.sol";
import "./interfaces/IVault.sol";
contract Vault is ERC20, IVault{
    using SafeMath for uint256;

    int24 public override tickLower;
    int24 public override tickUpper;
    address public override pool;
    address public masterchefV3;
    uint24 public override fee;
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    constructor(int24 _tickLower, int24 _tickUpper, address _pool,address _masterchefV3,uint24 _fee)ERC20("CFLOW","CF"){
        tickLower = _tickLower;
        tickUpper = _tickUpper;
        pool = _pool;
        masterchefV3 = _masterchefV3;
        fee = _fee;
    }



    function addLiquidity(uint256 amount0, uint256 amount1, uint256 amount0Min, uint256 amount1Min, address recipient) external payable override returns(uint256 shareAmount){
        
        IMCV3.IncreaseLiquidityParams memory increaseLiquidityParams  = IMCV3.IncreaseLiquidityParams({
            tokenId:0,
            amount0Desired:amount0,
            amount1Desired:amount1,
            amount0Min:amount0Min,
            amount1Min:amount1Min,
            deadline:block.timestamp
        });
        IMCV3(masterchefV3).increaseLiquidity(increaseLiquidityParams);
        shareAmount = calculateshareAmount(amount0,amount1);
        _mint(recipient,shareAmount);
    }

    function removeLiquidity(uint256 amount, uint256 amount0Min,uint256 amount1Min, address recipient) external override returns(uint256 amount0,uint256 amount1){
         IMCV3.DecreaseLiquidityParams memory decreaseLiquidityParams = IMCV3.DecreaseLiquidityParams({
            tokenId:0,
            liquidity:0,
            amount0Min:amount0Min,
            amount1Min:amount1Min,
            deadline:block.timestamp
        });

        (amount0,  amount1) = IMCV3(masterchefV3).decreaseLiquidity(decreaseLiquidityParams);

        IMCV3.CollectParams memory collectParams = IMCV3.CollectParams({
            tokenId:0,
            recipient:recipient,
            amount0Max: uint128(amount0),
            amount1Max: uint128(amount1)
        });

        (amount0,  amount1) = IMCV3(masterchefV3).collect(collectParams);

    }

    function harvest() external {

    }


    function calculateshareAmount(uint256 amount0,uint256 amount1) internal returns(uint256 share){
        uint256 supply = totalSupply();
        if(supply==0){
            _mint(address(0),MINIMUM_LIQUIDITY);
        }
        (uint160 sqrtPriceX96,,,,,,) = IPancakeV3Pool(pool).slot0();
        (uint256 res0,uint256 res1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                IPancakeV3Pool(pool).liquidity()
            );
        share = Math.min(amount0.mul(supply) / res0, amount1.mul(supply) / res1);

    }
   //l = userShare =  totliq*usershareInamount%
}