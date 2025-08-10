// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../../src/launchpad/LaunchPad.sol";
import "../../src/launchpad/LaunchPadToken.sol";
import "../../src/launchpad/TWAPOracle.sol";

// 增强的Mock Router，支持动态价格变化
contract EnhancedMockRouter {
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    
    // 存储每个代币的价格倍数（相对于基础价格）
    mapping(address => uint256) public priceMultipliers;
    
    constructor() {
        // 默认价格倍数为100（即1.00倍）
    }
    
    // 设置代币的价格倍数（100 = 1.00倍，150 = 1.50倍）
    function setPriceMultiplier(address token, uint256 multiplier) external {
        priceMultipliers[token] = multiplier;
    }
    
    function addLiquidityETH(
        address,
        uint amountTokenDesired,
        uint,
        uint,
        address ,
        uint
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity)
    {
        return (amountTokenDesired, msg.value, 1000);
    }

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        
        if (path.length > 1) {
            address token = path[0];
            uint256 multiplier = priceMultipliers[token];
            if (multiplier == 0) multiplier = 100; // 默认1.00倍
            
            // 基础价格：卖出10e18代币可以得到0.05 ETH
            // 根据价格倍数调整
            amounts[1] = (amountIn * multiplier) / (200 * 100); // 除以200是基础比率，除以100是倍数标准化
        }
    }

    function swapExactETHForTokens(
        uint,
        address[] calldata path,
        address to,
        uint
    ) external payable returns (uint[] memory amounts) {
        amounts = new uint[](2);
        amounts[0] = msg.value;
        
        if (path.length > 1) {
            address token = path[1];
            uint256 multiplier = priceMultipliers[token];
            if (multiplier == 0) multiplier = 100;
            
            // 计算可以买到的代币数量
            amounts[1] = (msg.value * 200 * 100) / multiplier;
            
            // 模拟代币转移
            LaunchPadToken tokenContract = LaunchPadToken(token);
            require(tokenContract.balanceOf(address(this)) >= amounts[1], "Insufficient router balance");
            tokenContract.transfer(to, amounts[1]);
        }
        
        return amounts;
    }
}

contract TWAPOracleTest is Test {
    LaunchPad public launchPad;
    TWAPOracle public oracle;
    EnhancedMockRouter public router;
    
    address public owner = address(0x1);
    address public creator = address(0x2);
    address public buyer1 = address(0x3);
    address public buyer2 = address(0x4);
    address public buyer3 = address(0x5);
    
    address public memeToken;
    
    event PriceUpdated(
        address indexed token,
        uint256 price,
        uint256 timestamp,
        uint256 cumulativePrice
    );
    
    function setUp() public {
        // 设置账户
        vm.deal(owner, 100 ether);
        vm.deal(creator, 100 ether);
        vm.deal(buyer1, 100 ether);
        vm.deal(buyer2, 100 ether);
        vm.deal(buyer3, 100 ether);
        
        // 部署合约
        router = new EnhancedMockRouter();
        launchPad = new LaunchPad(address(router));
        oracle = new TWAPOracle(address(launchPad), address(router));
        
        launchPad.transferOwnership(owner);
        oracle.transferOwnership(owner);
        
        vm.deal(address(launchPad), 10 ether);
        
        // 创建Meme代币
        vm.prank(creator);
        memeToken = launchPad.createToken(
            "MEME",
            100e18,  // totalSupply
            10e18,   // perMint
            0.1 ether // price
        );
        
        // 购买所有代币以触发流动性添加
        for (uint i = 0; i < 10; i++) {
            address testBuyer = address(uint160(0x1000 + i));
            vm.deal(testBuyer, 1 ether);
            vm.prank(testBuyer);
            launchPad.buyToken{value: 0.1 ether}(memeToken);
        }
        
        // 确保流动性已添加
        assertTrue(launchPad.liquidityAdded(memeToken));
        
        // 给router分配代币用于交易
        LaunchPadToken tokenContract = LaunchPadToken(memeToken);
        vm.prank(address(launchPad));
        tokenContract.mintForLiquidity(address(router), 1000000e18);
        
        // 添加代币到预言机跟踪
        vm.prank(owner);
        oracle.addToken(memeToken);
    }
    
    function testBasicPriceTracking() public view {
        // 检查初始价格
        uint256 initialPrice = oracle.getCurrentPrice(memeToken);
        console.log("Initial price:", initialPrice);
        assertTrue(initialPrice > 0);
        
        // 检查代币信息
        (bool isActive, uint256 observationCount, uint256 lastUpdateTime) = oracle.getTokenInfo(memeToken);
        assertTrue(isActive);
        assertTrue(observationCount >= 1);
        assertTrue(lastUpdateTime > 0);
    }
    
    function testMultipleTransactionsWithTimeProgression() public {
        console.log(unicode"=== 开始TWAP测试：模拟不同时间的多个交易 ===");
        
        // 第一次交易 - 基础价格
        console.log(unicode"\n--- 第一次交易（T+0小时）---");
        router.setPriceMultiplier(memeToken, 100); // 1.00倍基础价格
        vm.prank(owner);
        oracle.updatePrice(memeToken);
        
        uint256 price1 = oracle.getCurrentPrice(memeToken);
        console.log(unicode"价格1:", price1);
        
        // 模拟1小时后的交易 - 价格上涨50%
        console.log(unicode"\n--- 第二次交易（T+1小时）---");
        vm.warp(block.timestamp + 1 hours);
        router.setPriceMultiplier(memeToken, 150); // 1.50倍基础价格
        
        vm.expectEmit(true, false, false, false);
        emit PriceUpdated(memeToken, 0, 0, 0); // 我们只关心事件被触发
        
        vm.prank(owner);
        oracle.updatePrice(memeToken);
        
        uint256 price2 = oracle.getCurrentPrice(memeToken);
        console.log(unicode"价格2:", price2);
        assertTrue(price2 > price1, unicode"价格应该上涨");
        
        // 模拟2小时后的交易 - 价格下跌到120%
        console.log(unicode"\n--- 第三次交易（T+3小时）---");
        vm.warp(block.timestamp + 2 hours);
        router.setPriceMultiplier(memeToken, 120); // 1.20倍基础价格
        
        vm.prank(owner);
        oracle.updatePrice(memeToken);
        
        uint256 price3 = oracle.getCurrentPrice(memeToken);
        console.log(unicode"价格3:", price3);
        assertTrue(price3 < price2, unicode"价格应该下跌");
        assertTrue(price3 > price1, unicode"价格仍应高于初始价格");
        
        // 模拟1小时后的交易 - 价格继续下跌到80%
        console.log(unicode"\n--- 第四次交易（T+4小时）---");
        vm.warp(block.timestamp + 1 hours);
        router.setPriceMultiplier(memeToken, 80); // 0.80倍基础价格
        
        vm.prank(owner);
        oracle.updatePrice(memeToken);
        
        uint256 price4 = oracle.getCurrentPrice(memeToken);
        console.log(unicode"价格4:", price4);
        assertTrue(price4 < price1, unicode"价格应该低于初始价格");
        
        // 获取不同时间窗口的TWAP
        console.log(unicode"\n--- TWAP计算结果 ---");
        
        uint256 twap1h = oracle.getTWAP(memeToken, 1 hours);
        uint256 twap2h = oracle.getTWAP(memeToken, 2 hours);
        uint256 twap4h = oracle.getTWAP(memeToken, 4 hours);
        
        console.log(unicode"1小时TWAP:", twap1h);
        console.log(unicode"2小时TWAP:", twap2h);
        console.log(unicode"4小时TWAP:", twap4h);
        
        // TWAP应该平滑价格波动
        assertTrue(twap1h > 0, unicode"1小时TWAP应该大于0");
        assertTrue(twap2h > 0, unicode"2小时TWAP应该大于0");
        assertTrue(twap4h > 0, unicode"4小时TWAP应该大于0");
        
        // 获取观察历史
        (uint256[] memory timestamps, uint256[] memory prices, uint256[] memory cumulativePrices) = 
            oracle.getObservations(memeToken, 10);
            
        console.log(unicode"\n--- 价格观察历史 ---");
        for (uint i = 0; i < timestamps.length; i++) {
            console.log(unicode"时间: ", timestamps[i]);
            console.log(unicode"价格: ", prices[i]); 
            console.log(unicode"累积价格: ", cumulativePrices[i]);
        }
    }
    
    function testSimulateRealTradingScenario() public {
        console.log(unicode"=== 模拟真实交易场景 ===");
        
        // 场景：代币刚上线，价格波动剧烈
        uint256[] memory priceMultipliers = new uint256[](8);
        priceMultipliers[0] = 100;  // 1.00x - 初始价格
        priceMultipliers[1] = 200;  // 2.00x - 炒作开始
        priceMultipliers[2] = 350;  // 3.50x - 达到峰值
        priceMultipliers[3] = 180;  // 1.80x - 回调
        priceMultipliers[4] = 250;  // 2.50x - 二次上涨
        priceMultipliers[5] = 120;  // 1.20x - 下跌
        priceMultipliers[6] = 90;   // 0.90x - 继续下跌
        priceMultipliers[7] = 110;  // 1.10x - 稳定
        
        uint256[] memory timeIntervals = new uint256[](8);
        timeIntervals[0] = 0;
        timeIntervals[1] = 30 minutes;
        timeIntervals[2] = 45 minutes;
        timeIntervals[3] = 1 hours;
        timeIntervals[4] = 30 minutes;
        timeIntervals[5] = 2 hours;
        timeIntervals[6] = 1 hours;
        timeIntervals[7] = 30 minutes;
        
        uint256 currentTime = block.timestamp;
        
        for (uint i = 0; i < priceMultipliers.length; i++) {
            if (i > 0) {
                vm.warp(currentTime + timeIntervals[i]);
                currentTime = block.timestamp;
            }
            
            router.setPriceMultiplier(memeToken, priceMultipliers[i]);
            vm.prank(owner);
            oracle.updatePrice(memeToken);
            
            uint256 currentPrice = oracle.getCurrentPrice(memeToken);
            console.log(unicode"时间点 %s, 价格倍数: %s, 实际价格: %s", i, priceMultipliers[i], currentPrice);
            
            // 模拟用户交易
            if (i % 2 == 0) {
                address trader = i == 0 ? buyer1 : (i == 2 ? buyer2 : buyer3);
                vm.prank(trader);
                try launchPad.buyMeme{value: 0.05 ether}(memeToken) {
                    console.log(unicode"交易成功 - 买家:", trader);
                } catch {
                    console.log(unicode"交易失败 - 价格不优惠");
                }
            }
        }
        
        // 计算不同时间窗口的TWAP
        console.log(unicode"\n--- 最终TWAP分析 ---");
        
        uint256 twap30min = oracle.getTWAP(memeToken, 30 minutes);
        uint256 twap1h = oracle.getTWAP(memeToken, 1 hours);
        uint256 twap2h = oracle.getTWAP(memeToken, 2 hours);
        uint256 twap6h = oracle.getTWAP(memeToken, 6 hours);
        
        console.log(unicode"30分钟TWAP:", twap30min);
        console.log(unicode"1小时TWAP:", twap1h);
        console.log(unicode"2小时TWAP:", twap2h);
        console.log(unicode"6小时TWAP:", twap6h);
        
        uint256 finalPrice = oracle.getCurrentPrice(memeToken);
        console.log(unicode"最终即时价格:", finalPrice);
        
        // 验证TWAP的平滑效果
        assertTrue(twap6h != finalPrice, unicode"长期TWAP应该与即时价格不同");
        assertTrue(twap30min > 0 && twap1h > 0 && twap2h > 0 && twap6h > 0, unicode"所有TWAP都应该大于0");
    }
    
    function testBatchPriceUpdate() public {
        // 创建第二个代币
        vm.prank(creator);
        address memeToken2 = launchPad.createToken(
            "MEME2",
            100e18,
            10e18,
            0.1 ether
        );
        
        // 购买所有代币以触发流动性添加
        for (uint i = 0; i < 10; i++) {
            address testBuyer = address(uint160(0x2000 + i));
            vm.deal(testBuyer, 1 ether);
            vm.prank(testBuyer);
            launchPad.buyToken{value: 0.1 ether}(memeToken2);
        }
        
        // 给router分配第二个代币
        LaunchPadToken tokenContract2 = LaunchPadToken(memeToken2);
        vm.prank(address(launchPad));
        tokenContract2.mintForLiquidity(address(router), 1000000e18);
        
        // 添加第二个代币到预言机
        vm.prank(owner);
        oracle.addToken(memeToken2);
        
        // 设置不同的价格
        router.setPriceMultiplier(memeToken, 120);
        router.setPriceMultiplier(memeToken2, 80);
        
        // 批量更新价格
        vm.prank(owner);
        oracle.updateAllPrices();
        
        // 验证两个代币的价格都被更新
        uint256 price1 = oracle.getCurrentPrice(memeToken);
        uint256 price2 = oracle.getCurrentPrice(memeToken2);
        
        console.log(unicode"代币1价格:", price1);
        console.log(unicode"代币2价格:", price2);
        
        assertTrue(price1 > 0, unicode"代币1价格应该大于0");
        assertTrue(price2 > 0, unicode"代币2价格应该大于0");
        
        // 验证跟踪的代币列表
        address[] memory trackedTokens = oracle.getTrackedTokens();
        assertEq(trackedTokens.length, 2, unicode"应该跟踪2个代币");
    }
    
    function testErrorCases() public {
        // 测试添加无效代币
        address invalidToken = address(0x999);
        vm.prank(owner);
        vm.expectRevert(TWAPOracle.TokenNotValid.selector);
        oracle.addToken(invalidToken);
        
        // 测试重复添加代币
        vm.prank(owner);
        vm.expectRevert(TWAPOracle.TokenAlreadyTracked.selector);
        oracle.addToken(memeToken);
        
        // 测试获取未跟踪代币的TWAP
        vm.expectRevert(TWAPOracle.TokenNotTracked.selector);
        oracle.getTWAP(invalidToken, 1 hours);
        
        // 测试观察数据不足时获取TWAP
        vm.prank(creator);
        address newToken = launchPad.createToken("NEW", 100e18, 10e18, 0.1 ether);
        
        // 购买代币触发流动性
        for (uint i = 0; i < 10; i++) {
            address testBuyer = address(uint160(0x3000 + i));
            vm.deal(testBuyer, 1 ether);
            vm.prank(testBuyer);
            launchPad.buyToken{value: 0.1 ether}(newToken);
        }
        
        vm.prank(owner);
        oracle.addToken(newToken);
        
        // 只有一个观察点，应该失败
        vm.expectRevert(TWAPOracle.InsufficientObservations.selector);
        oracle.getTWAP(newToken, 1 hours);
    }
}