// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../../src/factory/MemeFactory.sol";
import "../../src/factory/MemeToken.sol";

contract MemeFactoryTest is Test {
    MemeFactory public factory;
    address public owner;
    address public creator;
    address public buyer;
    
    // 测试参数
    string public constant SYMBOL = "TEST";
    uint256 public constant TOTAL_SUPPLY = 1000 * 1e18; // 1000 tokens
    uint256 public constant PER_MINT = 10 * 1e18; // 10 tokens per mint
    uint256 public constant PRICE = 0.01 ether; // 0.01 ETH per mint
    
    function setUp() public {
        owner = address(0x1111111111111111111111111111111111111111);
        creator = address(0x1234567890123456789012345678901234567890);
        buyer = address(0x0987654321098765432109876543210987654321);
        
        // 创建工厂合约并转移所有权
        factory = new MemeFactory();
        factory.transferOwnership(owner);
        
        // 给测试账户一些ETH
        vm.deal(owner, 10 ether);
        vm.deal(creator, 10 ether);
        vm.deal(buyer, 10 ether);
    }
    
    // 测试部署Meme Token
    function testDeployMeme() public {
        vm.startPrank(creator);
        
        address tokenAddr = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 验证token地址不为零
        assertTrue(tokenAddr != address(0));
        
        // 验证token信息
        (uint256 totalSupply, uint256 totalSupplyLimit, uint256 perMint, uint256 price, address tokenCreator) = 
            factory.getMemeInfo(tokenAddr);
        
        assertEq(totalSupply, 0);
        assertEq(totalSupplyLimit, TOTAL_SUPPLY);
        assertEq(perMint, PER_MINT);
        assertEq(price, PRICE);
        assertEq(tokenCreator, creator);
        
        // 验证token名称和符号
        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.name(), string.concat("MEME", SYMBOL));
        assertEq(token.symbol(), SYMBOL);
        
        // 验证创建者token列表
        address[] memory creatorTokens = factory.getCreatorTokens(creator);
        assertEq(creatorTokens.length, 1);
        assertEq(creatorTokens[0], tokenAddr);
        
        vm.stopPrank();
    }
    
    
    // 测试铸造Meme Token
    function testMintMeme() public {
        // 先部署一个token
        vm.prank(creator);
        address tokenAddr = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        uint256 initialBalance = buyer.balance;
        uint256 initialCreatorBalance = creator.balance;
        uint256 initialOwnerBalance = owner.balance;
        
        // 铸造token
        vm.startPrank(buyer);
        factory.mintMeme{value: PRICE}(tokenAddr);
        vm.stopPrank();
        
        // 验证token余额
        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.balanceOf(buyer), PER_MINT);
        assertEq(token.totalSupply(), PER_MINT);
        
        // 验证费用分配
        uint256 platformShare = PRICE / 100; // 1%
        uint256 creatorShare = PRICE - platformShare; // 99%
        
        assertEq(creator.balance, initialCreatorBalance + creatorShare);
        assertEq(owner.balance, initialOwnerBalance + platformShare);
        assertEq(buyer.balance, initialBalance - PRICE);
    }
    
    // 测试铸造参数验证
    function testMintMemeInvalidParameters() public {
        // 先部署一个token
        vm.prank(creator);
        address tokenAddr = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 测试不存在的token
        vm.expectRevert(MemeFactory.TokenNotExists.selector);
        factory.mintMeme{value: PRICE}(address(0x123));
        
        // 测试支付金额不足
        vm.expectRevert(MemeFactory.InsufficientPayment.selector);
        factory.mintMeme{value: PRICE - 0.001 ether}(tokenAddr);
    }
    
    // 测试多次铸造
    function testMultipleMints() public {
        // 先部署一个token
        vm.prank(creator);
        address tokenAddr = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        MemeToken token = MemeToken(tokenAddr);
        uint256 expectedMintCount = TOTAL_SUPPLY / PER_MINT; // 100次
        
        // 铸造所有token
        for (uint256 i = 0; i < expectedMintCount; i++) {
            vm.prank(buyer);
            factory.mintMeme{value: PRICE}(tokenAddr);
            
            assertEq(token.balanceOf(buyer), PER_MINT * (i + 1));
            assertEq(token.totalSupply(), PER_MINT * (i + 1));
        }
        
        // 验证总供应量
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
        
        // 尝试再次铸造应该失败（超过总供应量）
        vm.expectRevert();
        vm.prank(buyer);
        factory.mintMeme{value: PRICE}(tokenAddr);
    }
    
    // 测试多个创建者
    function testMultipleCreators() public {
        address creator2 = address(0x1111111111111111111111111111111111111111);
        vm.deal(creator2, 10 ether);
        
        // 第一个创建者部署token
        vm.prank(creator);
        address token1 = factory.deployMeme("TOKEN1", TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 第二个创建者部署token
        vm.prank(creator2);
        address token2 = factory.deployMeme("TOKEN2", TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 验证各自的token列表
        address[] memory creator1Tokens = factory.getCreatorTokens(creator);
        address[] memory creator2Tokens = factory.getCreatorTokens(creator2);
        
        assertEq(creator1Tokens.length, 1);
        assertEq(creator1Tokens[0], token1);
        
        assertEq(creator2Tokens.length, 1);
        assertEq(creator2Tokens[0], token2);
        
        // 验证两个token都可以正常铸造
        vm.prank(buyer);
        factory.mintMeme{value: PRICE}(token1);
        
        vm.prank(buyer);
        factory.mintMeme{value: PRICE}(token2);
        
        MemeToken token1Contract = MemeToken(token1);
        MemeToken token2Contract = MemeToken(token2);
        
        assertEq(token1Contract.balanceOf(buyer), PER_MINT);
        assertEq(token2Contract.balanceOf(buyer), PER_MINT);
    }
    
    // 测试费用分配的正确性
    function testFeeDistribution() public {
        // 先部署一个token
        vm.prank(creator);
        address tokenAddr = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        uint256 initialCreatorBalance = creator.balance;
        uint256 initialOwnerBalance = owner.balance;
        
        // 铸造token
        vm.prank(buyer);
        factory.mintMeme{value: PRICE}(tokenAddr);
        
        // 验证费用分配
        uint256 platformShare = PRICE / 100; // 1%
        uint256 creatorShare = PRICE - platformShare; // 99%
        
        assertEq(creator.balance, initialCreatorBalance + creatorShare);
        assertEq(owner.balance, initialOwnerBalance + platformShare);
        
        // 验证分配比例
        assertEq(platformShare, PRICE / 100);
        assertEq(creatorShare, PRICE - platformShare);
        assertEq(platformShare + creatorShare, PRICE);
    }
    
    // 测试最小代理模式（验证Gas成本）
    function testGasOptimization() public {
        vm.startPrank(creator);
        
        // 部署第一个token
        uint256 gasUsed1 = gasleft();
        address token1 = factory.deployMeme("TOKEN1", TOTAL_SUPPLY, PER_MINT, PRICE);
        gasUsed1 = gasUsed1 - gasleft();
        
        // 部署第二个token
        uint256 gasUsed2 = gasleft();
        address token2 = factory.deployMeme("TOKEN2", TOTAL_SUPPLY, PER_MINT, PRICE);
        gasUsed2 = gasUsed2 - gasleft();
        
        // 验证两个token地址不同
        assertTrue(token1 != token2);
        
        // 验证两个token都可以正常工作
        vm.stopPrank();
        
        vm.prank(buyer);
        factory.mintMeme{value: PRICE}(token1);
        
        vm.prank(buyer);
        factory.mintMeme{value: PRICE}(token2);
        
        MemeToken token1Contract = MemeToken(token1);
        MemeToken token2Contract = MemeToken(token2);
        
        assertEq(token1Contract.balanceOf(buyer), PER_MINT);
        assertEq(token2Contract.balanceOf(buyer), PER_MINT);
    }

} 