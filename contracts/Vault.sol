// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;
import "@pancakeswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@pancakeswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/lib/contracts/libraries/Babylonian.sol";

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@pancakeswap/v3-core/contracts/interfaces/IPancakeV3Pool.sol";
import "@pancakeswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@pancakeswap/v3-core/contracts/libraries/TickMath.sol";
import "./interfaces/common/IMCV3.sol";

import "./interfaces/common/IWETH.sol";
import "./interfaces/IVault.sol";
import "./libraries/Liquidity.sol";
import "./libraries/Swap.sol";

import "./vaultToken/ERC20.sol";
import "hardhat/console.sol";

contract Vault is ERC20, IVault, Ownable, Pausable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable pool;
    uint256 public immutable FEE = 250;
    uint256 public immutable REMAINING_AMOUNT = 9500;
    uint256 public immutable MINIMUM_LIQUIDITY = 10 ** 18;
    address public constant masterchefV3 =
        0x556B9306565093C855AEA9AE92A594704c2Cd59e;
    address public immutable cake = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address public immutable positionManager =
        0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;
    address public immutable WETH = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant router = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4;
    address public immutable treasury0 =
        0x723a2e7E926A8AFc5871B8962728Cb464f698A54;
    address public immutable treasury1 =
        0x723a2e7E926A8AFc5871B8962728Cb464f698A54;
    uint24 public immutable fee;
    int24 public immutable tickLower;
    int24 public immutable tickUpper;
    uint256 public tokenId;
    address public immutable token0;
    address public immutable token1;

    constructor(
        string memory _name,
        string memory _symbol,
        address _pool
    ) ERC20(_name, _symbol, 18) {
        tickLower = TickMath.MIN_TICK;
        tickUpper = TickMath.MAX_TICK;
        pool = _pool;
        fee = IPancakeV3Pool(_pool).fee();
        token0 = IPancakeV3Pool(_pool).token0();
        token1 = IPancakeV3Pool(_pool).token1();
        _pause();
    }

    receive() external payable {}

    function onERC721Received(
        address,
        address _from,
        uint256 _tokenId,
        bytes calldata
    ) external {}

    fallback() external{

    }

    function initializeVault(
        uint256 amount0,
        uint256 amount1,
        uint256 amount0Min,
        uint256 amount1Min
    ) external payable onlyOwner {
        address _token0 = token0;
        address _token1 = token1;
        address _cake = cake;
        address _NFTPostionManager = positionManager;
        address _masterchefV3 = masterchefV3;
        pay(_token0, amount0);
        pay(_token1, amount1);
        IERC20(_token0).safeApprove(_NFTPostionManager, amount0);
        IERC20(_token1).safeApprove(_NFTPostionManager, amount1);
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager
            .MintParams({
                token0: _token0,
                token1: _token1,
                fee: fee,
                tickLower: -58200, //TickMath.MIN_TICK,
                tickUpper: -44200, //TickMath.MAX_TICK,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                recipient: address(this),
                deadline: block.timestamp
            });
        (
            uint256 _tokenId,
            ,
            uint256 _amount0,
            uint256 _amount1
        ) = INonfungiblePositionManager(_NFTPostionManager).mint(params);
        tokenId = _tokenId;
        INonfungiblePositionManager(_NFTPostionManager).approve(
            _masterchefV3,
            _tokenId
        );
        INonfungiblePositionManager(_NFTPostionManager).safeTransferFrom(
            address(this),
            _masterchefV3,
            _tokenId
        );
        if (_token0 != _cake && _token1 != _cake)
            IERC20(_cake).safeApprove(router, uint256(type(uint256).max));

        uint256 token0Left = amount0 - _amount0;
        uint256 token1Left = amount1 - _amount1;
        if (token0Left > 0) refund(_token0, token0Left);
        if (token1Left > 0) refund(_token1, token1Left);
        IERC20(_token0).safeApprove(router, uint256(type(uint256).max));
        IERC20(_token1).safeApprove(router, uint256(type(uint256).max));
        IERC20(_token0).safeApprove(masterchefV3, uint256(type(uint256).max));
        IERC20(_token1).safeApprove(masterchefV3, uint256(type(uint256).max));
        uint256 shareAmount = calculateshareAmount(_amount0, _amount1);
        _mint(msg.sender, shareAmount);
        _unpause();
        
    }

    function zapInDual(
        uint256 amount0,
        uint256 amount1,
        uint256 amount0Min,
        uint256 amount1Min
    ) public payable override whenNotPaused nonReentrant returns (uint256 shareAmount) {
        pay(token0, amount0);
        pay(token1, amount1);
        (uint256 _amount0, uint256 _amount1) = _addLiquidity(
            amount0,
            amount1,
            amount0Min,
            amount1Min
        );
        shareAmount = calculateshareAmount(_amount0, _amount1);
        _mint(msg.sender, shareAmount);
    }

    function zapInSingle(
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin
    ) public payable override nonReentrant returns (uint256 shareAmount) {
        require(tokenIn == token1 || tokenIn == token0, "token Not supported");
        pay(tokenIn, amountIn);
        (uint256 amount0, uint256 amount1) = _getOptimalDualAssets(
            tokenIn,
            amountIn,
            amountOutMin
        );
        (uint256 _amount0, uint256 _amount1) = _addLiquidity(
            amount0,
            amount1,
            (amount0 * 100) / 10_000,
            (amount1 * 100) / 10_000
        );

        shareAmount = calculateshareAmount(_amount0, _amount1);
        _mint(msg.sender, shareAmount);
    }

    function zapOut(
        uint128 amount,
        uint256 amount0Min,
        uint256 amount1Min
    ) public override nonReentrant returns (uint256 amount0, uint256 amount1) {
        _burn(msg.sender, uint256(amount));
        (amount0, amount1) = _removeLiquidity(amount, amount0Min, amount1Min);
        refund(token0, amount0);
        refund(token1, amount1);
    }

    function zapOutAndSwap(
        uint128 amount,
        uint256 amount0Min,
        uint256 amount1Min,
        address desiredToken,
        uint256 amountOutMin
    ) public override nonReentrant {
        _burn(msg.sender, uint256(amount));
        (uint256 _amount0, uint256 _amount1) = _removeLiquidity(
            amount,
            amount0Min,
            amount1Min
        );
        //refactoring required!!!!
        require(
            desiredToken == token0 || desiredToken == token1,
            "token not supported"
        );
        address swapToken = token1 == desiredToken ? token0 : token1;
        uint256 amountToSwap = swapToken == token0 ? _amount0 : _amount1;
        uint256 remainingAmount = amountToSwap == _amount0
            ? _amount1
            : _amount0;
        refund(
            desiredToken,
            swap(swapToken, desiredToken, amountToSwap, amountOutMin) +
                remainingAmount
        );
    }

    function harvest(
        uint256 amountOut,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 amountOut1,
        bytes calldata route
    ) external override nonReentrant {
        uint256 reward = IMCV3(masterchefV3).harvest(tokenId, address(this));
        address _cake = cake;
        address lpToken0 = token0;
        address lpToken1 = token1;
        require(reward > 0, "Zero Harvest Amount");
        if (_cake != lpToken0 && _cake != lpToken1) {
            Swap.batchSwap(reward, amountOut, route, router);
            _arrangeAddliquidityObject(
                abi.decode(route[20:40], (address)), //find correct one
                lpToken0,
                lpToken1,
                amountOut1
            );
        } else {
            _arrangeAddliquidityObject(_cake, lpToken0, lpToken1, amountOut1);
        }
        _addLiquidity(
            IERC20(lpToken0).balanceOf(address(this)),
            IERC20(lpToken1).balanceOf(address(this)),
            amount0Min,
            amount1Min
        );
    }

    function pauseAndWithdrawNFT() public override whenNotPaused nonReentrant onlyOwner {
        _pause();
        //why it fails!!!!!
        IMCV3(masterchefV3).withdraw(tokenId, address(this));
    }

    function unpauseAndDepositNFT() external override whenPaused nonReentrant onlyOwner {
        _unpause();
        address _NFTPositionManager = positionManager;
        address _masterchefV3 = masterchefV3;
        uint256 _tokenId = tokenId;

        INonfungiblePositionManager(_NFTPositionManager).approve(
            _masterchefV3,
            _tokenId
        );
        INonfungiblePositionManager(_NFTPositionManager).safeTransferFrom(
            address(this),
            _masterchefV3,
            _tokenId
        );
    }

    function emergencyExit(
        uint128 amount,
        uint256 amount0Min,
        uint256 amount1Min
    ) public override whenPaused nonReentrant {
        uint256 _tokenId = tokenId;
        address NFTPositionManager = positionManager;
        _burn(msg.sender, amount);

        INonfungiblePositionManager.DecreaseLiquidityParams
            memory decreaseLiquidityParams = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: _tokenId,
                    liquidity: calculateWithdrawShare(amount),
                    amount0Min: amount0Min,
                    amount1Min: amount1Min,
                    deadline: block.timestamp
                });

        (uint256 amount0, uint256 amount1) = INonfungiblePositionManager(
            NFTPositionManager
        ).decreaseLiquidity(decreaseLiquidityParams);

        INonfungiblePositionManager.CollectParams
            memory collectParams = INonfungiblePositionManager.CollectParams({
                tokenId: _tokenId,
                recipient: address(this),
                amount0Max: uint128(amount0),
                amount1Max: uint128(amount1)
            });

        (amount0, amount1) = INonfungiblePositionManager(NFTPositionManager)
            .collect(collectParams);

        refund(token0, amount0);
        refund(token1, amount1);
    }

    function pauseVault() public override onlyOwner {
        _pause();
    }

    function unpauseVault() public override onlyOwner {
        _unpause();
    }

    function _getOptimalDualAssets(
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin
    ) internal returns (uint256 amount0, uint256 amount1) {
        address _token0 = token0;
        uint24 _fee = fee;
        (uint256 res0, uint256 res1) = _getReservers();
        bool isInputA = _token0 == tokenIn;
        uint256 amountToSwap = isInputA
            ? Swap.calculateSwapInAmount(res0, amountIn, _fee)
            : Swap.calculateSwapInAmount(res1, amountIn, _fee);
        if (_token0 == tokenIn) {
            amount0 = amountIn - amountToSwap;
            amount1 = swap(tokenIn, token1, amountToSwap, amountOutMin);
        } else {
            amount0 = swap(tokenIn, _token0, amountToSwap, amountOutMin);
            amount1 = amountIn - amountToSwap;
        }
    }

    function _addLiquidity(
        uint256 amount0,
        uint256 amount1,
        uint256 amount0Min,
        uint256 amount1Min
    ) internal returns (uint256 _amount0, uint256 _amount1) {
        IMCV3.IncreaseLiquidityParams memory increaseLiquidityParams = IMCV3
            .IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                deadline: block.timestamp
            });
        (, _amount0, _amount1) = IMCV3(masterchefV3).increaseLiquidity(
            increaseLiquidityParams
        );
        uint256 token0Left = amount0 - _amount0;
        uint256 token1Left = amount1 - _amount1;
        if (token0Left > 0) refund(token0, token0Left);

        if (token1Left > 0) refund(token1, token1Left);
    }

    function _removeLiquidity(
        uint128 amount,
        uint256 amount0Min,
        uint256 amount1Min
    ) internal returns (uint256 amount0, uint256 amount1) {
        address _masterchefV3 = masterchefV3;
        IMCV3.DecreaseLiquidityParams memory decreaseLiquidityParams = IMCV3
            .DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: calculateWithdrawShare(amount),
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                deadline: block.timestamp
            });

        (amount0, amount1) = IMCV3(_masterchefV3).decreaseLiquidity(
            decreaseLiquidityParams
        );
        IMCV3.CollectParams memory collectParams = IMCV3.CollectParams({
            tokenId: tokenId,
            recipient: address(this),
            amount0Max: uint128(amount0),
            amount1Max: uint128(amount1)
        });
        (amount0, amount1) = IMCV3(_masterchefV3).collect(collectParams);
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
            ? swap(
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
                amountOut1
            )
            : swap(
                _token1,
                _token0,
                Swap.calculateSwapInAmount(
                    res1,
                    _chargeFees(
                        tokenIn,
                        IERC20(tokenIn).balanceOf(address(this))
                    ),
                    _fee
                ),
                amountOut1
            );
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) internal returns (uint256 amountOut) {
        amountOut = Swap.singleSwap(
            tokenIn,
            tokenOut,
            amountIn,
            amountOutMin,
            fee,
            router
        );
    }

    function calculateWithdrawShare(
        uint128 amount
    ) internal view returns (uint128 liquidityShare) {
        (, , , , , , , uint128 liquidity, , , , ) = INonfungiblePositionManager(
            positionManager
        ).positions(tokenId);
        liquidityShare = (liquidity * amount) / 1e20;
    }

    function calculateshareAmount(
        uint256 amount0,
        uint256 amount1
    ) internal returns (uint256 share) {
        uint256 supply = totalSupply;
        if (supply == 0) {
            share = Babylonian.sqrt(amount0.mul(amount1)).sub(
                MINIMUM_LIQUIDITY
            );
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_SHARE tokens
        } else {
            (uint256 res0, uint256 res1) = _getReservers();
            share = Math.min(
                amount0.mul(supply) / res0,
                amount1.mul(supply) / res1
            );
            //liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
    }

    function _chargeFees(
        address token,
        uint256 amount
    ) internal returns (uint256) {
        (uint256 t0, uint256 t1, uint256 remainingAmount) = _calculate(amount);
        IERC20(token).safeTransfer(treasury0, t0);
        IERC20(token).safeTransfer(treasury1, t1);
        emit Fees(t0, t1);
        return remainingAmount;
    }

    function _calculate(
        uint256 amount
    ) internal pure returns (uint256, uint256, uint256) {
        require((amount * FEE) >= 10_000);
        return (
            (amount * FEE) / 10_000,
            (amount * FEE) / 10_000,
            (amount * REMAINING_AMOUNT) / 10_000
        );
    }

    function _getReservers()
        internal
        view
        returns (uint256 res0, uint256 res1)
    {
        (res0, res1) = Liquidity.getAmountsForLiquidity(
            pool,
            positionManager,
            tokenId,
            tickLower,
            tickUpper
        );
    }

    function pay(address _token, uint256 _amount) internal {
        if (_token == WETH && msg.value > 0) {
            require(msg.value == _amount, "Inconsistent Amount");
            IWETH(WETH).deposit{value: _amount}();
        } else {
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        }
    }

    function refund(address _token, uint256 _amount) internal {
        if (_token == WETH && msg.value > 0) {
            IWETH(_token).withdraw(_amount);
            (bool success, ) = msg.sender.call{value: _amount}("");
            if (!success) revert();
        } else {
            IERC20(_token).safeTransfer(msg.sender, _amount);
        }
    }
}
