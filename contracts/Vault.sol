// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;
import "@pancakeswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@pancakeswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/lib/contracts/libraries/Babylonian.sol";
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

contract Vault is ERC20, IVault, Ownable, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    
    address public override pool;
    uint256 public immutable FEE = 250;
    uint256 public immutable REMAINING_AMOUNT = 9500;
    uint256 public immutable MINIMUM_LIQUIDITY = 10 ** 3;
    address public constant masterchefV3 = 0x556B9306565093C855AEA9AE92A594704c2Cd59e;
    address public immutable cake = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address public immutable positionManager = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;
    address public immutable WETH = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant router = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4;
    address public immutable treasury0 = 0x723a2e7E926A8AFc5871B8962728Cb464f698A54;
    address public immutable treasury1 = 0x723a2e7E926A8AFc5871B8962728Cb464f698A54;
    uint24  public immutable override fee;
    int24   public immutable override tickLower;
    int24   public immutable override tickUpper;
    uint256 public override tokenId;
    address public override token0;
    address public override token1;
    //address[] public route;

    constructor(
        string memory _name,
        string memory _symbol,
        address _pool
        //address[] memory _route,
    ) ERC20(_name, _symbol,18) {
        tickLower = TickMath.MIN_TICK;
        tickUpper = TickMath.MAX_TICK;
        pool = _pool;
        fee = IPancakeV3Pool(pool).fee();
        token0 = IPancakeV3Pool(pool).token0();
        token1 = IPancakeV3Pool(pool).token1();
        IERC20(token0).safeApprove(
                router,
                uint256(type(uint256).max)
            );
        IERC20(token1).safeApprove(
                router,
                uint256(type(uint256).max)
            );
        IERC20(token0).safeApprove(
                masterchefV3,
                uint256(type(uint256).max)
            );
        IERC20(token1).safeApprove(
                masterchefV3,
                uint256(type(uint256).max)
            );        
        // for (uint256 i; i < _approveToken.length; ++i) {
        //     IERC20(_approveToken[i]).safeApprove(
        //         router,
        //         uint256(type(uint256).max)
        //     );
        // }
        //route = _route;
        _pause();
    }

    function initializeVault(
        uint256 amount0,
        uint256 amount1,
        uint256 amount0Min,
        uint256 amount1Min
    ) external payable onlyOwner {
        console.log(token0);
        console.log(token1);
        pay(token0, amount0);
        pay(token1, amount1);
        //console.log(IERC20(token0).balanceOf(address(this)));
        //IWETH(WETH).deposit{value:msg.value}();
        console.log(IERC20(WETH).balanceOf(address(this)));
        // IERC20(token0).transfer(positionManager,amount0Desired);
        // positionManager.transfer(msg.value);
        // (bool success, ) = positionManager.call{value: msg.value}("");
        //require(success, "ETH transfer failed");
        IERC20(token0).approve(positionManager,amount0);
        IERC20(token1).approve(positionManager,amount1);

        // INonfungiblePositionManager.MintParams
        //     memory params = INonfungiblePositionManager.MintParams({
        //         token0: token0,
        //         token1: token1,
        //         fee: fee,
        //         tickLower: TickMath.MIN_TICK,
        //         tickUpper: TickMath.MAX_TICK,
        //         amount0Desired: amount0,
        //         amount1Desired: amount1,
        //         amount0Min: 0,
        //         amount1Min: 0,
        //         recipient: address(this),
        //         deadline: block.timestamp+100
        //     });

        // (
        //     uint256 _tokenId,
        //     ,
        //     uint256 amount0,
        //     uint256 amount1
        // ) = INonfungiblePositionManager(positionManager).mint(
        //         params
        //     );
        console.log("fee",fee);
        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                // By using TickMath.MIN_TICK and TickMath.MAX_TICK, 
                // we are providing liquidity across the whole range of the pool. 
                // Not recommended in production.
                tickLower: -58200,//TickMath.MIN_TICK,
                tickUpper: -44200,//TickMath.MAX_TICK,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });

        // Note that the pool defined by DAI/USDC and fee tier 0.01% must 
        // already be created and initialized in order to mint
        (uint256 _tokenId,, uint256 _amount0,uint256 _amount1) = INonfungiblePositionManager(positionManager)
            .mint{value:msg.value}(params);
        tokenId = _tokenId;
        INonfungiblePositionManager(positionManager).approve(masterchefV3,_tokenId);    
        INonfungiblePositionManager(positionManager).transferFrom(
            address(this),
            masterchefV3,
            _tokenId
        );
        uint256 shareAmount = calculateshareAmount(_amount0, _amount1);
        _mint(msg.sender, shareAmount);
        
        _unpause();
    }

    function addLiquidity(
        uint256 amount0,
        uint256 amount1,
        uint256 amount0Min,
        uint256 amount1Min,
        address recipient
    ) public payable override whenNotPaused returns (uint256 shareAmount) {
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

    function addLiquiditySingle(address tokenIn, uint256 amountIn,uint256 amountOutMin) external payable{
        require(tokenIn==token1||tokenIn==token0,"token Not supported");
        pay(tokenIn,amountIn);
        (uint256 res0, uint256 res1) = Liquidity.getAmountsForLiquidity(
            pool,
            positionManager,
            tokenId,
            tickLower,
            tickUpper
        );
        bool isInputA = token0 == tokenIn;
        uint256 amountToSwap = isInputA
            ? Swap.calculateSwapInAmount(res0, amountIn, fee)
            : Swap.calculateSwapInAmount(res1, amountIn, fee);
        Swap.singleSwap(
            tokenIn,
            token0 == tokenIn?token1:token0,
            amountToSwap,
            amountOutMin,
            fee,
            router
        );
        uint256 amount0 = IERC20(token0).balanceOf(address(this));
        uint256 amount1 = IERC20(token1).balanceOf(address(this));
        addLiquidity(
            amount0,
            amount1,
            (amount0 * 100) / 10_000,
            (amount1 * 100) / 10_000,
            msg.sender
        );

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
        _burn(msg.sender, uint256(amount));
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
            amount0Max: uint128(type(uint128).max),
            amount1Max: uint128(type(uint128).max)
        });

        (amount0, amount1) = IMCV3(masterchefV3).collectTo(collectParams,recipient);
    }

    function harvest(
        uint256 amountOut0,
        uint256 amountOut1,
        bytes calldata _route
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
                _route,
                router
            ); //route cake-to-lp1/lp0
            _arrangeAddliquidityObject(
                abi.decode(_route[20:40], (address)),
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
        uint256 supply = totalSupply;
        if (supply == 0) {
            share = Babylonian.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_SHARE tokens
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
    function onERC721Received(
        address ,
        address,
        uint _tokId,
        bytes calldata
    ) external returns (bytes4) {
        console.log("!!!!!!!!!!!!!");
        //_createDeposit(operator, _tokenId);
        return this.onERC721Received.selector;
    }
    fallback() external payable{
        console.log("3333");
    }
    receive() external payable{

    }
}
