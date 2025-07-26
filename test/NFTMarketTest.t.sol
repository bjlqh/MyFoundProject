// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "../src/MyERC721.sol";
import "../src/NFTMarket.sol";

contract NFTMarketTest is Test {
    MyToken token;
    MyERC721 nft;
    NFTMarket market;

    address tokenOwner = address(0x100);
    address u1 = address(0x1);
    address u2 = address(0x2);

    function setUp() public {
        vm.prank(tokenOwner);
        token = new MyToken("MockToken", "MTK");
        nft = new MyERC721("MockNFT", "MNFT");
        market = new NFTMarket(address(token), address(nft), address(0x12345678));

        vm.startPrank(tokenOwner);
        token.transfer(u1, 50 ether);
        token.transfer(u2, 50 ether);
        vm.stopPrank();

        //铸造
        nft.mint(u1, "1");
        nft.mint(u2, "2");

        //授权
        vm.prank(u1);
        nft.approve(address(market), 1); //授权合约可以转移token为1的nft
        vm.prank(u2);
        nft.approve(address(market), 2); //授权合约可以转移token为2的nft

        vm.prank(u1);
        token.approve(address(market), 50 ether);
        vm.prank(u2);
        token.approve(address(market), 50 ether);
    }

    //上架成功
    function testListSuccess() public {
        vm.prank(u1);
        market.list(1, 10 ether);
        (address seller, uint price) = market.listings(1);
        assertEq(seller, u1);
        assertEq(price, 10 ether);
    }

    // 非持有者上架
    function testListNotOwner() public {
        vm.prank(u2);
        vm.expectRevert(NFTMarket.NotOwner.selector);
        market.list(1, 10 ether);
    }

    // 价格为0
    function testListInvalidPrice() public {
        vm.prank(u1);
        vm.expectRevert(NFTMarket.InvalidPrice.selector);
        market.list(1, 0);
    }

    // 购买成功
    function testBuySuccess() public {
        vm.prank(u1);
        market.list(1, 10 ether);

        vm.prank(u2);
        market.buyNFT(1, 10 ether);
        // 检查NFT所有者
        assertEq(nft.ownerOf(1), u2);
        // Market合约不再持有NFT
        (address seller, ) = market.listings(1);
        assertEq(seller, address(0));
    }

    // 自己买自己
    function testBuySelf() public {
        vm.prank(u1);
        market.list(1, 10 ether);

        vm.prank(u1);
        vm.expectRevert(NFTMarket.CannotBuyOwn.selector);
        market.buyNFT(1, 10 ether);
    }

    // 重复购买
    function testBuyTwice() public {
        vm.prank(u1);
        market.list(1, 10 ether);

        // 第一次购买成功
        vm.prank(u2);
        market.buyNFT(1, 10 ether);
        assertEq(nft.ownerOf(1), u2);

        // 第二次购买应该revert
        vm.prank(u2);
        vm.expectRevert(NFTMarket.NotListed.selector);
        market.buyNFT(1, 10 ether);
    }

    // 支付不足
    function testBuyInsufficientFunds() public {
        vm.prank(u1);
        market.list(1, 100 ether);

        vm.prank(u2);
        vm.expectRevert(NFTMarket.InSufficientFunds.selector);
        market.buyNFT(1, 100 ether);
    }

    // 支付金额不正确
    function testBuyInvalidPrice() public {
        vm.prank(u1);
        market.list(1, 10 ether);

        vm.prank(u2);
        vm.expectRevert(NFTMarket.InvalidPayment.selector);
        market.buyNFT(1, 100 ether);
    }

    // 事件断言
    function testListEvent() public {
        vm.prank(u1);
        vm.expectEmit(true, true, true, true);
        emit NFTMarket.Listed(address(nft), 1, u1, 10 ether);
        market.list(1, 10 ether);
    }

    function testBuyEvent() public {
        vm.prank(u1);
        market.list(1, 10 ether);

        vm.prank(u2);
        vm.expectEmit(true, true, true, true);
        emit NFTMarket.Bought(address(nft), 1, u2, u1, 10 ether);
        market.buyNFT(1, 10 ether);
    }

    // 模糊测试
    function testFuzzListAndBuy(uint price) public {
        price = uint(bound(price, 1 ether, 50 ether));
        vm.prank(u1);
        market.list(1, price);

        vm.prank(u2);
        market.buyNFT(1, price);

        assertEq(nft.ownerOf(1), u2);
    }
}
