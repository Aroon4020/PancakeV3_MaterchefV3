// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;
import "@pancakeswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@pancakeswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@pancakeswap/v3-core/contracts/interfaces/IPancakeV3Pool.sol";
import "@pancakeswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@pancakeswap/v3-core/contracts/libraries/TickMath.sol";
import "./interfaces/common/IMCV3.sol";
import "./interfaces/IVault.sol";

import "./libraries/Swap.sol";

import "./libraries/Liquidity.sol";

contract Vault is ERC20, IVault, Ownable, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    int24 public override tickLower;
    int24 public override tickUpper;
    address public override pool;
    address public masterchefV3;
    address public cake;
    address public router;
    uint24 public override fee;
    address treasury0;
    address treasury1;
    uint256 public constant FEE = 250;
    uint256 public constant REMAINING_AMOUNT = 9500;
    uint public constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 public override tokenId;
    address public positionManager = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;
    address WETH;
    address public override token0;
    address public override token1;

    constructor(
        int24 _tickLower,
        int24 _tickUpper,
        address _pool,
        address _masterchefV3,
        uint24 _fee
    ) ERC20("CFLOW", "CF") {
        tickLower = _tickLower;
        tickUpper = _tickUpper;
        pool = _pool;
        masterchefV3 = _masterchefV3;
        fee = _fee;
        _pause();
    }

    function initializeVault(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) external payable onlyOwner {
        pay(token0, amount0Desired);
        pay(token1, amount1Desired);
        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                recipient: address(this),
                deadline: block.timestamp
            });

        (
            uint256 _tokenId,
            ,
            uint256 amount0,
            uint256 amount1
        ) = INonfungiblePositionManager(positionManager).mint{value: msg.value}(
                params
            );
        INonfungiblePositionManager(positionManager).transferFrom(
            address(this),
            masterchefV3,
            _tokenId
        );
        calculateshareAmount(amount0, amount1);
        _unpause();
        tokenId = _tokenId;
    }

    function addLiquidity(
        uint256 amount0,
        uint256 amount1,
        uint256 amount0Min,
        uint256 amount1Min,
        address recipient
    ) external payable override whenNotPaused returns (uint256 shareAmount) {
        pay(token0, amount0);
        pay(token1, amount1);
        IMCV3.IncreaseLiquidityParams memory increaseLiquidityParams = IMCV3
            .IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                deadline: block.timestamp
            });
        IMCV3(masterchefV3).increaseLiquidity(increaseLiquidityParams);
        shareAmount = calculateshareAmount(amount0, amount1);
        _mint(recipient, shareAmount);
    }

    function removeLiquidity(
        uint128 amount,
        uint256 amount0Min,
        uint256 amount1Min,
        address recipient
    )
        external
        override
        whenNotPaused
        returns (uint256 amount0, uint256 amount1)
    {
        IMCV3.DecreaseLiquidityParams memory decreaseLiquidityParams = IMCV3
            .DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: calculateWithdrawShare(amount),
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                deadline: block.timestamp
            });

        (amount0, amount1) = IMCV3(masterchefV3).decreaseLiquidity(
            decreaseLiquidityParams
        );

        IMCV3.CollectParams memory collectParams = IMCV3.CollectParams({
            tokenId: tokenId,
            recipient: recipient,
            amount0Max: uint128(amount0),
            amount1Max: uint128(amount1)
        });

        (amount0, amount1) = IMCV3(masterchefV3).collect(collectParams);
        _burn(msg.sender, uint256(amount));
    }

    function harvest(
        uint256 amountOut0,
        uint256 amountOut1,
        bytes calldata route
    ) external override whenNotPaused {
        IMCV3(masterchefV3).harvest(tokenId, address(this));
        address _cake = cake;
        address lpToken0 = token0;
        address lpToken1 = token1;
        require(
            IERC20(_cake).balanceOf(address(this)) > 0,
            "Zero Harvest Amount"
        );
        if (_cake != lpToken0 && _cake != lpToken1) {
            Swap.batchSwap(
                IERC20(_cake).balanceOf(address(this)),
                amountOut0,
                route,
                router
            ); //route cake-to-lp1/lp0
            _arrangeAddliquidityObject(
                abi.decode(route[20:40], (address)),
                lpToken0,
                lpToken1,
                amountOut1
            );
        } else {
            _arrangeAddliquidityObject(cake, lpToken0, lpToken1, amountOut1);
        }

        IMCV3.IncreaseLiquidityParams memory increaseLiquidityParams = IMCV3
            .IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: IERC20(lpToken0).balanceOf(address(this)),
                amount1Desired: IERC20(lpToken1).balanceOf(address(this)),
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });
        IMCV3(masterchefV3).increaseLiquidity(increaseLiquidityParams);
    }

    function pauseAndWithdrawNFT() external override whenNotPaused onlyOwner {
        _pause();
        IMCV3(masterchefV3).withdraw(tokenId, address(this));
    }

    function unpauseAndDepositNFT() external override whenPaused onlyOwner {
        _unpause();
        INonfungiblePositionManager(positionManager).transferFrom(
            address(this),
            masterchefV3,
            tokenId
        );
    }

    function emergencyExit(
        uint128 amount,
        uint256 amount0Min,
        uint256 amount1Min,
        address recipient
    ) external override whenPaused {
        //uint128 liquidity =  calculateWithdrawShare(amount);
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory decreaseLiquidityParams = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: calculateWithdrawShare(amount),
                    amount0Min: amount0Min,
                    amount1Min: amount1Min,
                    deadline: block.timestamp
                });

        (uint256 amount0, uint256 amount1) = INonfungiblePositionManager(
            positionManager
        ).decreaseLiquidity(decreaseLiquidityParams);

        INonfungiblePositionManager.CollectParams
            memory collectParams = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: recipient,
                amount0Max: uint128(amount0),
                amount1Max: uint128(amount1)
            });

        (amount0, amount1) = INonfungiblePositionManager(positionManager)
            .collect(collectParams);
    }

    function pauseVault() external override onlyOwner {
        _pause();
    }

    function unpauseVault() external override onlyOwner {
        _unpause();
    }

    function _arrangeAddliquidityObject(
        address tokenIn,
        address _token0,
        address _token1,
        uint256 amountOut1
    ) internal {
        (uint256 res0, uint256 res1) = Liquidity.getAmountsForLiquidity(
            pool,
            positionManager,
            tokenId,
            tickLower,
            tickUpper
        );
        uint24 _fee = fee;
        _token0 == tokenIn
            ? Swap.singleSwap(
                _token0,
                _token1,
                Swap.calculateSwapInAmount(
                    res0,
                    _chargeFees(
                        tokenIn,
                        IERC20(tokenIn).balanceOf(address(this))
                    ),
                    _fee
                ),
                amountOut1,
                _fee,
                router
            )
            : Swap.singleSwap(
                token1,
                token0,
                Swap.calculateSwapInAmount(
                    res1,
                    _chargeFees(
                        tokenIn,
                        IERC20(tokenIn).balanceOf(address(this))
                    ),
                    _fee
                ),
                amountOut1,
                _fee,
                router
            );
    }

    function calculateWithdrawShare(
        uint128 amount
    ) internal view returns (uint128 liquidityShare) {
        (, , , , , , , uint128 liquidity, , , , ) = INonfungiblePositionManager(
            positionManager
        ).positions(tokenId);
        liquidityShare = liquidity * (amount / 1e20);
    }

    function calculateshareAmount(
        uint256 amount0,
        uint256 amount1
    ) internal returns (uint256 share) {
        uint256 supply = totalSupply();
        if (supply == 0) {
            _mint(address(0), MINIMUM_LIQUIDITY);
        }
        (uint256 res0, uint256 res1) = Liquidity.getAmountsForLiquidity(
            pool,
            positionManager,
            tokenId,
            tickLower,
            tickUpper
        );
        share = Math.min(
            amount0.mul(supply) / res0,
            amount1.mul(supply) / res1
        );
    }

    function _chargeFees(
        address token,
        uint256 amount
    ) internal returns (uint256) {
        (uint256 t0, uint256 t1, uint256 remainingAmount) = calculate(amount);
        IERC20(token).safeTransfer(treasury0, t0);
        IERC20(token).safeTransfer(treasury1, t1);
        //emit Fees(t0, t1);
        return remainingAmount;
    }

    function calculate(
        uint256 amount
    ) internal pure returns (uint256, uint256, uint256) {
        require((amount * FEE) >= 10_000);
        return (
            (amount * FEE) / 10_000,
            (amount * FEE) / 10_000,
            (amount * REMAINING_AMOUNT) / 10_000
        );
    }

    function pay(address _token, uint256 _amount) internal {
        if (_token == WETH && msg.value > 0) {
            require(msg.value == _amount, "Inconsistent Amount");
        } else {
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        }
    }
}
