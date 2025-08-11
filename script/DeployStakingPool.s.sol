// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/staking/StakingPool.sol";
import "../src/staking/Bank.sol";
import {MyToken} from "../src/MyToken.sol";

contract DeployStakingPool is Script {
    function run() external returns (StakingPool, Bank, MyToken) {
        vm.startBroadcast();

        Bank bank = new Bank();
        MyToken kkToken = new MyToken("KK Token", "KK", 0); // 不预铸造
        StakingPool stakingPool = new StakingPool(
            address(kkToken),
            address(bank)
        );

        // 将kkToken的所有权转移给StakingPool
        kkToken.transferOwnership(address(stakingPool));

        vm.stopBroadcast();
        return (stakingPool, bank, kkToken);
    }
}
