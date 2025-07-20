// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";

import "../src/MyToken.sol";
import "../src/MyERC721.sol";
import "../../src/NFTMarket.sol";

contract MarketHandler is Test {
    NFTMarket market;
    MyToken token;
    MyERC721 nft;
    address[] users;

    constructor(NFTMarket _market, MyToken _token, MyERC721 _nft, address[] memory _users) {
        market = _market;
        token = _token;
        nft = _nft;
        users = _users;
    }

    function list(uint tokenId, uint price, uint userIdx) public {
        address user = users[userIdx % users.length];
        vm.startPrank(user);
        try market.list(tokenId, price) {} catch {}
        vm.stopPrank();
    }

    function buyNFT(uint tokenId, uint price, uint userIdx) public {
        address user = users[userIdx % users.length];
        vm.startPrank(user);
        try market.buyNFT(tokenId, price) {} catch {}
        vm.stopPrank();
    }
}

contract NFTMarketInvariantTest is StdInvariant, Test {
    MyToken token;
    MyERC721 nft;
    NFTMarket market;
    address u1 = address(0x1);
    address u2 = address(0x2);
    MarketHandler handler;

    function setUp() public {
        token = new MyToken("MockToken", "MTK");
        nft = new MyERC721("MockNFT", "MNFT");
        market = new NFTMarket(address(token), address(nft));

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

        address[] memory users = new address[](2);
        users[0] = u1;
        users[1] = u2;
        
        //暴露 list、buyNFT 等方法，注册给 Foundry，让 Foundry 自动调用这些方法
        handler = new MarketHandler(market, token, nft, users);
        targetContract(address(handler));
    }

    //不变性测试：买家支付后，NFTMarket 合约不应该token持仓
    function invariant_marketHasNoTokenBalance() public view {
        assertEq(token.balanceOf(address(market)), 0);
    }
}
