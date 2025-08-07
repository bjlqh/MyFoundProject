// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenVesting {
    IERC20 public token;
    address public beneficiary;
    address public owner;

    uint public constant CLIFF_DURATION = 365 days; //12个月
    uint public constant VESTING_DURATION = 1095 days; //36个月总期间(12个月cliff + 24个月线性释放)
    uint public constant TOTAL_AMOUNT = 1_000_000 * 1e18; //100万代币

    uint public startTime;
    uint public released;

    event TokensReleased(uint amount);

    modifier onlyBeneficiary() {
        require(msg.sender == beneficiary, "Not beneficiary");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _token, address _beneficiary) {
        token = IERC20(_token);
        beneficiary = _beneficiary;
        owner = msg.sender;
        startTime = block.timestamp;
    }

    function release() external onlyBeneficiary {
        uint releasable = releasableAmount();
        require(releasable > 0, "No tokens to release");
        released += releasable;
        require(token.transfer(beneficiary, releasable), "Transfer failed");
        emit TokensReleased(releasable);
    }

    function releasableAmount() public view returns (uint) {
        return vestedAmount() - released;
    }

    function vestedAmount() public view returns (uint) {
        if(block.timestamp < startTime + CLIFF_DURATION){
            return 0;       //Cliff期内不释放
        }
        if(block.timestamp >= startTime + VESTING_DURATION){
            return TOTAL_AMOUNT;    //全部释放
        }

        //线性释放：从cliff结束后开始计算
        uint timeFromCliff = block.timestamp - (startTime + CLIFF_DURATION);
        uint vestingTimeAfterCliff = VESTING_DURATION - CLIFF_DURATION;

        uint calculatedAmount = (TOTAL_AMOUNT * timeFromCliff) / vestingTimeAfterCliff;
        return calculatedAmount > TOTAL_AMOUNT ? TOTAL_AMOUNT : calculatedAmount;
    }

    function withdrawAll() external onlyOwner {
        bool success = token.transfer(owner, token.balanceOf(address(this)));
        require(success, "withdraw all failed");
    }
}
