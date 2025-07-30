# MyFoundProject
查看gas消耗
forge snapshot --match-path test/NFTMarketTest.t.sol
forge snapshot --match-path test/NFTMarketTest.t.sol --gas-report
forge test --match-contract NFTMarketTest --gas-report > ../file/gas_report_v1.md 2>&1


Permit2 deployed at: 0x0B306BF915C4d645ff596e518fAf3F9669b97016

安装Permit2 
forge install Uniswap/permit2   



测试输出
forge test --match-contract EIP721 -vv > logs/EIP721Test.log 2>&1


cast send 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853 "transfer(address,uint256)" 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 60000000000000000000 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --rpc-url http://127.0.0.1:8545


cast call 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 "listings(uint256)" 1 --rpc-url http://127.0.0.1:8545

## 部署

forge script script/DeployTokenBankPermit2Script.s.sol --rpc-url local --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80


forge script script/NFTMarket.s.sol --broadcast --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

## 检查
cast code 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 --rpc-url http://127.0.0.1:8545

cast code 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9 --rpc-url http://127.0.0.1:8545


## 测试
forge test --mp test/NFTMarketInvarientTest.t.sol
forge test --match-path test/NFTMarketInvarientTest.t.sol >> test.log 2>&1
forge test --match-path test/NFTMarketTest.t.sol >> test.log 2>&1



## Foundry
**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**


## Documentation

https://book.getfoundry.sh/