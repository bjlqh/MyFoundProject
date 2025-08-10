// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./LaunchPad.sol";

/**
 * TWAP价格预言机合约
 * 用于获取LaunchPad发行的Meme代币的时间加权平均价格
 */
contract TWAPOracle is Ownable, ReentrancyGuard {
    struct PriceObservation {
        uint256 timestamp;
        uint256 price;          // 价格 (ETH per token, scaled by 1e18)
        uint256 cumulativePrice; // 累积价格
    }
    
    struct TokenInfo {
        address token;
        bool isActive;
        uint256 observationCount;
        uint256 lastUpdateTime;
        mapping(uint256 => PriceObservation) observations;
    }
    
    LaunchPad public immutable launchPad;
    IUniswapV2Router public immutable uniswapRouter;
    
    // token address => TokenInfo
    mapping(address => TokenInfo) public tokenInfos;
    address[] public trackedTokens;
    
    uint256 public constant MIN_OBSERVATION_PERIOD = 1 hours;
    uint256 public constant MAX_OBSERVATIONS = 100;
    
    event PriceUpdated(
        address indexed token,
        uint256 price,
        uint256 timestamp,
        uint256 cumulativePrice
    );
    
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    
    error TokenNotTracked();
    error TokenAlreadyTracked();
    error InsufficientObservations();
    error InvalidTimeRange();
    error TokenNotValid();
    
    constructor(address _launchPad, address _uniswapRouter) {
        launchPad = LaunchPad(payable(_launchPad));
        uniswapRouter = IUniswapV2Router(_uniswapRouter);
    }
    
    /**
     * 添加要跟踪的代币
     */
    function addToken(address token) external onlyOwner {
        if (!launchPad.isValidToken(token)) revert TokenNotValid();
        if (tokenInfos[token].isActive) revert TokenAlreadyTracked();
        
        tokenInfos[token].token = token;
        tokenInfos[token].isActive = true;
        tokenInfos[token].lastUpdateTime = block.timestamp;
        trackedTokens.push(token);
        
        // 添加初始价格观察
        _updatePrice(token);
        
        emit TokenAdded(token);
    }
    
    /**
     * 移除跟踪的代币
     */
    function removeToken(address token) external onlyOwner {
        if (!tokenInfos[token].isActive) revert TokenNotTracked();
        
        tokenInfos[token].isActive = false;
        
        // 从数组中移除
        for (uint i = 0; i < trackedTokens.length; i++) {
            if (trackedTokens[i] == token) {
                trackedTokens[i] = trackedTokens[trackedTokens.length - 1];
                trackedTokens.pop();
                break;
            }
        }
        
        emit TokenRemoved(token);
    }
    
    /**
     * 更新代币价格（任何人都可以调用）
     */
    function updatePrice(address token) external nonReentrant {
        if (!tokenInfos[token].isActive) revert TokenNotTracked();
        _updatePrice(token);
    }
    
    /**
     * 批量更新所有跟踪代币的价格
     */
    function updateAllPrices() external nonReentrant {
        for (uint i = 0; i < trackedTokens.length; i++) {
            if (tokenInfos[trackedTokens[i]].isActive) {
                _updatePrice(trackedTokens[i]);
            }
        }
    }
    
    /**
     * 内部函数：更新价格
     */
    function _updatePrice(address token) internal {
        TokenInfo storage info = tokenInfos[token];
        
        // 获取当前价格
        uint256 currentPrice = _getCurrentPrice(token);
        if (currentPrice == 0) return; // 如果无法获取价格，跳过
        
        uint256 currentTime = block.timestamp;
        uint256 observationIndex = info.observationCount % MAX_OBSERVATIONS;
        
        // 计算累积价格
        uint256 cumulativePrice = 0;
        if (info.observationCount > 0) {
            uint256 lastIndex = (info.observationCount - 1) % MAX_OBSERVATIONS;
            PriceObservation storage lastObs = info.observations[lastIndex];
            uint256 timeDelta = currentTime - lastObs.timestamp;
            cumulativePrice = lastObs.cumulativePrice + (lastObs.price * timeDelta);
        }
        
        // 存储新的观察
        info.observations[observationIndex] = PriceObservation({
            timestamp: currentTime,
            price: currentPrice,
            cumulativePrice: cumulativePrice
        });
        
        info.observationCount++;
        info.lastUpdateTime = currentTime;
        
        emit PriceUpdated(token, currentPrice, currentTime, cumulativePrice);
    }
    
    /**
     * 获取当前即时价格
     */
    function _getCurrentPrice(address token) internal view returns (uint256) {
        // 检查是否有流动性
        if (!launchPad.hashUniswapLiquidity(token)) {
            return 0;
        }
        
        // 获取LaunchPad代币信息
        LaunchPadToken tokenContract = LaunchPadToken(token);
        (, , uint256 perMint, , ) = tokenContract.getMintInfo();
        
        // 通过Uniswap获取价格
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = uniswapRouter.WETH();
        
        try uniswapRouter.getAmountsOut(perMint, path) returns (uint[] memory amounts) {
            // 返回每个perMint代币需要的ETH数量
            return amounts[1];
        } catch {
            return 0;
        }
    }
    
    /**
     * 获取指定时间范围内的TWAP价格
     */
    function getTWAP(address token, uint256 timeWindow) external view returns (uint256) {
        if (!tokenInfos[token].isActive) revert TokenNotTracked();
        
        TokenInfo storage info = tokenInfos[token];
        if (info.observationCount < 2) revert InsufficientObservations();
        
        uint256 currentTime = block.timestamp;
        uint256 targetTime = currentTime - timeWindow;
        
        // 找到时间窗口内的观察点
        PriceObservation memory startObs;
        PriceObservation memory endObs;
        bool foundStart = false;
        bool foundEnd = false;
        
        // 获取最新的观察点作为结束点
        uint256 latestIndex = (info.observationCount - 1) % MAX_OBSERVATIONS;
        endObs = info.observations[latestIndex];
        foundEnd = true;
        
        // 寻找最接近目标时间的观察点
        uint256 searchCount = info.observationCount > MAX_OBSERVATIONS ? MAX_OBSERVATIONS : info.observationCount;
        
        for (uint256 i = 0; i < searchCount; i++) {
            uint256 index = (info.observationCount - 1 - i) % MAX_OBSERVATIONS;
            PriceObservation memory obs = info.observations[index];
            
            if (obs.timestamp <= targetTime) {
                startObs = obs;
                foundStart = true;
                break;
            }
        }
        
        if (!foundStart) {
            // 如果没有找到足够早的观察点，使用最早的观察点
            uint256 earliestIndex = info.observationCount > MAX_OBSERVATIONS ? 
                info.observationCount % MAX_OBSERVATIONS : 0;
            startObs = info.observations[earliestIndex];
        }
        
        // 计算TWAP
        if (endObs.timestamp <= startObs.timestamp) {
            return endObs.price; // 如果时间范围无效，返回最新价格
        }
        
        uint256 timeDelta = endObs.timestamp - startObs.timestamp;
        uint256 cumulativePriceDelta = endObs.cumulativePrice - startObs.cumulativePrice;
        
        return cumulativePriceDelta / timeDelta;
    }
    
    /**
     * 获取当前即时价格
     */
    function getCurrentPrice(address token) external view returns (uint256) {
        if (!tokenInfos[token].isActive) revert TokenNotTracked();
        return _getCurrentPrice(token);
    }
    
    /**
     * 获取代币的观察历史
     */
    function getObservations(address token, uint256 count) external view returns (
        uint256[] memory timestamps,
        uint256[] memory prices,
        uint256[] memory cumulativePrices
    ) {
        if (!tokenInfos[token].isActive) revert TokenNotTracked();
        
        TokenInfo storage info = tokenInfos[token];
        uint256 actualCount = count > info.observationCount ? info.observationCount : count;
        actualCount = actualCount > MAX_OBSERVATIONS ? MAX_OBSERVATIONS : actualCount;
        
        timestamps = new uint256[](actualCount);
        prices = new uint256[](actualCount);
        cumulativePrices = new uint256[](actualCount);
        
        for (uint256 i = 0; i < actualCount; i++) {
            uint256 index = (info.observationCount - actualCount + i) % MAX_OBSERVATIONS;
            PriceObservation memory obs = info.observations[index];
            timestamps[i] = obs.timestamp;
            prices[i] = obs.price;
            cumulativePrices[i] = obs.cumulativePrice;
        }
    }
    
    /**
     * 获取所有跟踪的代币
     */
    function getTrackedTokens() external view returns (address[] memory) {
        return trackedTokens;
    }
    
    /**
     * 获取代币信息
     */
    function getTokenInfo(address token) external view returns (
        bool isActive,
        uint256 observationCount,
        uint256 lastUpdateTime
    ) {
        TokenInfo storage info = tokenInfos[token];
        return (info.isActive, info.observationCount, info.lastUpdateTime);
    }
}