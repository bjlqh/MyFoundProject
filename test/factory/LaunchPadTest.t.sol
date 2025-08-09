// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../../src/factory/LaunchPadFactory.sol";
import "../../src/factory/LaunchPadToken.sol";

//简化的Mock Router
contract MockRouter {
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
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
    ) external pure returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        //模拟更便宜的Uniswap价格：卖出10e18代币可以得到0.05 ETH
        //这意味着买10e18代币只需要0.05 ETH,比mint价格(0.1 ETH)便宜
        amounts[1] = amountIn / 200; //10e18 / 200 = 0.05e18 = 0.05 ETH
    }

    function swapExactETHForTokens(
        uint amount,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts) {
        amounts = new uint[](2);
        amounts[0] = msg.value;
        // 保持与getAmountsOut一致的计算逻辑
        amounts[1] = msg.value / 200; // 与getAmountsOut保持一致
        
        // 模拟代币转移事件
        // 注意：在真实环境中，Uniswap会从流动性池转移代币给买家
        // 这里我们通过直接转移来模拟这个过程
        if (path.length > 1) {
            // 模拟从流动性池到接收者的代币转移
            LaunchPadToken token = LaunchPadToken(path[1]);
            // 由于LaunchPadToken的mint函数只能由factory调用，我们需要用其他方式模拟转移
            // 这里我们假设router已经有足够的代币余额来转移
            // 在真实测试中，我们应该预先给router分配一些代币
            
            // 为了简化测试，我们直接使用ERC20的transfer功能
            // 注意：这需要router事先拥有代币
            require(token.balanceOf(address(this)) >= amounts[1], "Insufficient router balance");
            token.transfer(to, amounts[1]);
        }

        return amounts;
    }
}

contract LaunchPadTest is Test {
    LaunchPadFactory public factory;
    MockRouter public router;

    address public owner = address(0x1);
    address public creator = address(0x2);
    address public buyer = address(0x3);

    // 定义Transfer事件用于测试验证
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        router = new MockRouter();
        factory = new LaunchPadFactory(address(router));
        factory.transferOwnership(owner);

        vm.deal(owner, 100 ether);
        vm.deal(creator, 100 ether);
        vm.deal(buyer, 100 ether);
        vm.deal(address(factory), 10 ether);
    }

    // 测试流动性添加
    function testLiquidityAddition() public {
        vm.prank(creator);
        uint totalSupplyLimit = 100e18;
        uint perMint = 10e18;
        uint price = 0.1 ether;
        address token = factory.createToken(
            "Meme",
            totalSupplyLimit,
            perMint,
            price
        );

        //购买所有代币(10次购买)
        for (uint i = 0; i < 10; i++) {
            address testBuyer = address(uint160(0x1000 + i));
            vm.deal(testBuyer, 1 ether);
            vm.prank(testBuyer);
            factory.buyToken{value: 0.1 ether}(token);
        }

        //验证流动性已添加
        assertTrue(factory.liquidityAdded(token));

        //验证代币总供应量增加(包含流动性代币)
        LaunchPadToken tokenContract = LaunchPadToken(token);
        assertTrue(tokenContract.totalSupply() > 100e18);
    }

    //购买代币
    function testBuyMeme() public {
        vm.prank(creator);
        uint totalSupplyLimit = 100e18;
        uint perMint = 10e18;
        uint price = 0.1 ether;
        address token = factory.createToken(
            "Meme",
            totalSupplyLimit,
            perMint,
            price
        );

        //购买所有代币触发流动性添加
        for (uint i = 0; i < 10; i++) {
            address testBuyer = address(uint160(0x2000 + i));
            vm.deal(testBuyer, 1 ether);
            vm.prank(testBuyer);
            factory.buyToken{value: 0.1 ether}(token);
        }

        assertTrue(factory.liquidityAdded(token));

        LaunchPadToken tokenContract = LaunchPadToken(token);
        uint initialTokenBalance = tokenContract.balanceOf(buyer);
        
        // 给MockRouter分配一些代币，模拟流动性池中的代币
        // 在真实环境中，这些代币来自流动性池
        uint256 routerTokenBalance = 1000000e18; // 给router足够的代币
        vm.prank(address(factory)); // 只有factory可以mint
        tokenContract.mintForLiquidity(address(router), routerTokenBalance);

        //计算预期的代币数量(基于当前流动性池状态)
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = token;
        uint[] memory amounts = router.getAmountsOut(0.05 ether, path);
        uint expectedTokens = amounts[1];

        //期望事件 - Transfer事件应该从代币合约发出
        // 在真实环境中，代币从流动性池(router)转移到买家
        vm.expectEmit(true, true, false, true, token);
        emit Transfer(address(router), buyer, expectedTokens);

        //执行buyMeme操作
        vm.prank(buyer);
        factory.buyMeme{value: 0.05 ether}(token);

        //验证代币余额变化
        uint finalTokenBalance = tokenContract.balanceOf(buyer);
        uint actualTokensReceived = finalTokenBalance - initialTokenBalance;

        console.log("Expected tokens from getAmountsOut:", expectedTokens);
        console.log("Actual tokens received:", actualTokensReceived);
        
        //验证实际收到的代币数量与预期一致
        assertEq(actualTokensReceived, expectedTokens, "Actual tokens should match expected from getAmountsOut");
    }

    // 测试获取Uniswap价格
    function testGetUniswapPrice() public {
        // 创建代币并完成销售
        vm.prank(creator);
        address token = factory.createToken(
            "Meme",
            100e18,
            10e18,
            0.1 ether
        );

        // 购买所有代币以触发流动性添加
        for (uint i = 0; i < 10; i++) {
            address testBuyer = address(uint160(0x3000 + i));
            vm.deal(testBuyer, 1 ether);
            vm.prank(testBuyer);
            factory.buyToken{value: 0.1 ether}(token);
        }

        //查看uniswap价格
        uint uniswapPrice = factory.getUniswapPrice(token);
        console.log("Uniswap price:", uniswapPrice);
        assertTrue(uniswapPrice > 0);

        //检查流动性状态
        assertTrue(factory.hashUniswapLiquidity(token));
    }
}
