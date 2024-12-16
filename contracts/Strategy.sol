// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ILiquidityPool {
    function poolInfo()
        external
        view
        returns (
            IERC20 token0,
            IERC20 token1,
            uint256 reserve0,
            uint256 reserve1,
            uint256 totalSupply,
            uint24 fee,
            address strategy,
            uint256 lastUpdateTime
        );
}

contract Strategy is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    struct StrategyParams {
        uint256 targetRatio;      // Target ratio between token0 and token1 (scaled by 1e18)
        uint256 rebalanceThreshold; // Threshold for rebalancing (scaled by 1e18)
        uint256 maxSlippage;      // Maximum allowed slippage (scaled by 1e18)
        uint256 minReturnPercent; // Minimum return required for a trade (scaled by 1e18)
    }

    struct StrategyState {
        uint256 lastRebalance;
        uint256 totalValue;
        uint256 performanceFee;
        bool emergency;
    }

    ILiquidityPool public liquidityPool;
    StrategyParams public params;
    StrategyState public state;

    event StrategyExecuted(
        address indexed executor,
        uint256 profit,
        uint256 fee
    );

    event ParamsUpdated(
        uint256 targetRatio,
        uint256 rebalanceThreshold,
        uint256 maxSlippage,
        uint256 minReturnPercent
    );

    event EmergencyStateSet(bool emergency);

    modifier notEmergency() {
        require(!state.emergency, "Strategy: emergency");
        _;
    }

    constructor(
        address _liquidityPool,
        uint256 _targetRatio,
        uint256 _rebalanceThreshold,
        uint256 _maxSlippage,
        uint256 _minReturnPercent
    ) {
        require(_liquidityPool != address(0), "Invalid pool");
        liquidityPool = ILiquidityPool(_liquidityPool);

        params = StrategyParams({
            targetRatio: _targetRatio,
            rebalanceThreshold: _rebalanceThreshold,
            maxSlippage: _maxSlippage,
            minReturnPercent: _minReturnPercent
        });

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);
    }

    function execute() external nonReentrant notEmergency onlyRole(EXECUTOR_ROLE) {
        (IERC20 token0, IERC20 token1, uint256 reserve0, uint256 reserve1, , , ,) = liquidityPool.poolInfo();
        
        uint256 initialValue = _calculateTotalValue(token0, token1, reserve0, reserve1);
        
        if (_shouldRebalance(reserve0, reserve1)) {
            _rebalance(token0, token1, reserve0, reserve1);
        }

        uint256 finalValue = _calculateTotalValue(token0, token1, reserve0, reserve1);
        require(finalValue >= initialValue, "Strategy: negative return");

        uint256 profit = finalValue - initialValue;
        uint256 fee = _calculateFee(profit);
        state.performanceFee += fee;
        state.totalValue = finalValue;
        state.lastRebalance = block.timestamp;

        emit StrategyExecuted(msg.sender, profit, fee);
    }

    function updateParams(
        uint256 _targetRatio,
        uint256 _rebalanceThreshold,
        uint256 _maxSlippage,
        uint256 _minReturnPercent
    ) external onlyRole(MANAGER_ROLE) {
        params.targetRatio = _targetRatio;
        params.rebalanceThreshold = _rebalanceThreshold;
        params.maxSlippage = _maxSlippage;
        params.minReturnPercent = _minReturnPercent;

        emit ParamsUpdated(
            _targetRatio,
            _rebalanceThreshold,
            _maxSlippage,
            _minReturnPercent
        );
    }

    function setEmergencyState(bool _emergency) external onlyRole(MANAGER_ROLE) {
        state.emergency = _emergency;
        emit EmergencyStateSet(_emergency);
    }

    function withdrawFees(address recipient) external onlyRole(MANAGER_ROLE) {
        require(recipient != address(0), "Invalid recipient");
        uint256 fees = state.performanceFee;
        state.performanceFee = 0;
        
        (IERC20 token0, IERC20 token1, , , , , ,) = liquidityPool.poolInfo();
        uint256 token0Fee = fees / 2;
        uint256 token1Fee = fees / 2;
        
        token0.safeTransfer(recipient, token0Fee);
        token1.safeTransfer(recipient, token1Fee);
    }

    function _shouldRebalance(uint256 reserve0, uint256 reserve1)
        internal
        view
        returns (bool)
    {
        uint256 currentRatio = (reserve0 * 1e18) / reserve1;
        uint256 ratioDiff = currentRatio > params.targetRatio
            ? currentRatio - params.targetRatio
            : params.targetRatio - currentRatio;

        return ratioDiff > params.rebalanceThreshold;
    }

    function _rebalance(
        IERC20 token0,
        IERC20 token1,
        uint256 reserve0,
        uint256 reserve1
    ) internal {
        uint256 currentRatio = (reserve0 * 1e18) / reserve1;
        
        if (currentRatio > params.targetRatio) {
            // Sell token0 for token1
            uint256 token0ToSell = _calculateSellAmount(
                reserve0,
                reserve1,
                currentRatio,
                params.targetRatio
            );
            _executeTrade(token0, token1, token0ToSell);
        } else {
            // Sell token1 for token0
            uint256 token1ToSell = _calculateSellAmount(
                reserve1,
                reserve0,
                1e18 * 1e18 / currentRatio,
                1e18 * 1e18 / params.targetRatio
            );
            _executeTrade(token1, token0, token1ToSell);
        }
    }

    function _calculateSellAmount(
        uint256 reserveSell,
        uint256 reserveBuy,
        uint256 currentRatio,
        uint256 targetRatio
    ) internal pure returns (uint256) {
        // Complex calculation to determine optimal trade size
        // This is a simplified version
        uint256 diff = currentRatio > targetRatio
            ? currentRatio - targetRatio
            : targetRatio - currentRatio;
        
        return (reserveSell * diff) / (currentRatio * 2);
    }

    function _executeTrade(
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn
    ) internal {
        // Implementation would connect to DEX or other trading venue
        // This is a placeholder for the actual trading logic
    }

    function _calculateTotalValue(
        IERC20 token0,
        IERC20 token1,
        uint256 reserve0,
        uint256 reserve1
    ) internal view returns (uint256) {
        // In practice, would need oracle prices
        // This is a simplified calculation
        return reserve0 + reserve1;
    }

    function _calculateFee(uint256 profit) internal pure returns (uint256) {
        return profit * 20 / 100; // 20% performance fee
    }
}
