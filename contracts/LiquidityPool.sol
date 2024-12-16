// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract LiquidityPool is ReentrancyGuard, AccessControl, Pausable {
    using SafeERC20 for IERC20;

    bytes32 public constant STRATEGY_ROLE = keccak256("STRATEGY_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    struct PoolInfo {
        IERC20 token0;
        IERC20 token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalSupply;
        uint24 fee;
        address strategy;
        uint256 lastUpdateTime;
    }

    struct UserInfo {
        uint256 lpTokens;
        uint256 token0Deposited;
        uint256 token1Deposited;
        uint256 lastDepositTime;
    }

    PoolInfo public poolInfo;
    mapping(address => UserInfo) public userInfo;
    
    uint256 public constant MIN_LIQUIDITY = 1000;
    uint256 public constant MAX_FEE = 10000; // 100%
    uint256 public withdrawalDelay = 24 hours;

    event LiquidityAdded(
        address indexed user,
        uint256 amount0,
        uint256 amount1,
        uint256 lpTokens
    );

    event LiquidityRemoved(
        address indexed user,
        uint256 amount0,
        uint256 amount1,
        uint256 lpTokens
    );

    event StrategyUpdated(
        address indexed oldStrategy,
        address indexed newStrategy
    );

    event FeeUpdated(uint24 oldFee, uint24 newFee);

    constructor(
        address _token0,
        address _token1,
        uint24 _fee
    ) {
        require(_token0 != address(0) && _token1 != address(0), "Invalid tokens");
        require(_fee <= MAX_FEE, "Fee too high");

        poolInfo.token0 = IERC20(_token0);
        poolInfo.token1 = IERC20(_token1);
        poolInfo.fee = _fee;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);
    }

    function addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    ) external nonReentrant whenNotPaused returns (uint256 lpTokens) {
        require(amount0Desired > 0 && amount1Desired > 0, "Invalid amounts");
        require(to != address(0), "Invalid recipient");

        (uint256 amount0, uint256 amount1) = _calculateLiquidityAmounts(
            amount0Desired,
            amount1Desired,
            amount0Min,
            amount1Min
        );

        poolInfo.token0.safeTransferFrom(msg.sender, address(this), amount0);
        poolInfo.token1.safeTransferFrom(msg.sender, address(this), amount1);

        lpTokens = _mintLPTokens(amount0, amount1, to);

        emit LiquidityAdded(to, amount0, amount1, lpTokens);
    }

    function removeLiquidity(
        uint256 lpTokens,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        require(lpTokens > 0, "Invalid LP tokens");
        require(to != address(0), "Invalid recipient");

        UserInfo storage user = userInfo[msg.sender];
        require(user.lpTokens >= lpTokens, "Insufficient LP tokens");
        require(
            block.timestamp >= user.lastDepositTime + withdrawalDelay,
            "Withdrawal delay"
        );

        (amount0, amount1) = _calculateWithdrawalAmounts(lpTokens);
        require(amount0 >= amount0Min, "Insufficient token0 output");
        require(amount1 >= amount1Min, "Insufficient token1 output");

        _burnLPTokens(lpTokens, msg.sender);

        poolInfo.token0.safeTransfer(to, amount0);
        poolInfo.token1.safeTransfer(to, amount1);

        emit LiquidityRemoved(msg.sender, amount0, amount1, lpTokens);
    }

    function updateStrategy(address newStrategy)
        external
        onlyRole(MANAGER_ROLE)
    {
        require(newStrategy != address(0), "Invalid strategy");
        address oldStrategy = poolInfo.strategy;
        poolInfo.strategy = newStrategy;

        emit StrategyUpdated(oldStrategy, newStrategy);
    }

    function updateFee(uint24 newFee) external onlyRole(MANAGER_ROLE) {
        require(newFee <= MAX_FEE, "Fee too high");
        uint24 oldFee = poolInfo.fee;
        poolInfo.fee = newFee;

        emit FeeUpdated(oldFee, newFee);
    }

    function pause() external onlyRole(MANAGER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(MANAGER_ROLE) {
        _unpause();
    }

    function _calculateLiquidityAmounts(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) internal view returns (uint256 amount0, uint256 amount1) {
        if (poolInfo.reserve0 == 0 && poolInfo.reserve1 == 0) {
            amount0 = amount0Desired;
            amount1 = amount1Desired;
        } else {
            uint256 amount1Optimal = (amount0Desired * poolInfo.reserve1) /
                poolInfo.reserve0;
            if (amount1Optimal <= amount1Desired) {
                require(amount1Optimal >= amount1Min, "Insufficient token1");
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = (amount1Desired * poolInfo.reserve0) /
                    poolInfo.reserve1;
                require(amount0Optimal <= amount0Desired, "Excessive token0");
                require(amount0Optimal >= amount0Min, "Insufficient token0");
                amount0 = amount0Optimal;
                amount1 = amount1Desired;
            }
        }
    }

    function _calculateWithdrawalAmounts(uint256 lpTokens)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        amount0 = (lpTokens * poolInfo.reserve0) / poolInfo.totalSupply;
        amount1 = (lpTokens * poolInfo.reserve1) / poolInfo.totalSupply;
    }

    function _mintLPTokens(
        uint256 amount0,
        uint256 amount1,
        address to
    ) internal returns (uint256 lpTokens) {
        if (poolInfo.totalSupply == 0) {
            lpTokens = Math.sqrt(amount0 * amount1) - MIN_LIQUIDITY;
            _mint(address(1), MIN_LIQUIDITY); // Burn address
        } else {
            lpTokens = Math.min(
                (amount0 * poolInfo.totalSupply) / poolInfo.reserve0,
                (amount1 * poolInfo.totalSupply) / poolInfo.reserve1
            );
        }

        require(lpTokens > 0, "Insufficient LP tokens");

        _mint(to, lpTokens);
        userInfo[to].lpTokens += lpTokens;
        userInfo[to].token0Deposited += amount0;
        userInfo[to].token1Deposited += amount1;
        userInfo[to].lastDepositTime = block.timestamp;

        poolInfo.reserve0 += amount0;
        poolInfo.reserve1 += amount1;
        poolInfo.totalSupply += lpTokens;
        poolInfo.lastUpdateTime = block.timestamp;
    }

    function _burnLPTokens(uint256 lpTokens, address from) internal {
        _burn(from, lpTokens);
        userInfo[from].lpTokens -= lpTokens;
        poolInfo.totalSupply -= lpTokens;
    }
}

library Math {
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
