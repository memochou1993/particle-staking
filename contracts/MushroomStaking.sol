// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MushroomStaking is Ownable, ReentrancyGuard {
    address private _owner;
    uint256 constant MIN_REWARD_RATE = 365 * 10;
    uint256 constant MAX_REWARD_RATE = 365 * 12;
    uint256 public startTime;
    uint256 public stakeholderCount;
    mapping(address => Stakeholder) public stakeholders;

    struct Stakeholder {
        address addr;
        uint256 level;
        Stake[] stakes;
    }

    struct Stake {
        uint256 amount;
        uint256 rewardRate;
        uint256 claimed;
        uint256 lastClaimDate;
    }

    constructor() {
        _owner = msg.sender;
    }

    modifier onlyStakeholder() {
        require(isStakeholder(msg.sender), "caller is not the stakeholder");
        _;
    }

    modifier onlyOpened() {
        require(startTime > 0, "event is not opened yet");
        _;
    }

    modifier onlyStarted() {
        require(block.timestamp > startTime, "event is not started yet");
        _;
    }

    function setStartTime(uint256 _startTime)
        external
        onlyOwner
    {
        require(startTime == 0, "event has already opened");
        startTime = _startTime;
    }

    function contractBalance()
        external
        view
        returns (uint256)
    {
        return address(this).balance;
    }

    function stakesOf(address _stakeholder)
        external
        view
        onlyStakeholder
        returns (Stake[] memory)
    {
        return stakeholders[_stakeholder].stakes;
    }

    function rewardRateOf(address _stakeholder)
        external
        view
        onlyStakeholder
        returns (uint256)
    {
        return calculateRewardRate(stakeholders[_stakeholder].level);
    }

    function isStakeholder(address _stakeholder)
        public
        view
        returns (bool)
    {
        return stakeholders[_stakeholder].addr != address(0);
    }

    function deposit()
        public
        payable
        nonReentrant
        onlyOpened
    {
        if (!isStakeholder(msg.sender)) {
            stakeholders[msg.sender].addr = msg.sender;
            stakeholderCount++;
        }
        uint256 _fee = calculateFee(msg.value);
        uint256 _amount = msg.value - _fee;
        uint256 _rewardRate = calculateRewardRate(stakeholders[msg.sender].level);
        uint256 _lastClaimDate;
        if (block.timestamp < startTime) {
            _lastClaimDate = startTime;
        }
        stakeholders[msg.sender].stakes.push(Stake({
            amount: _amount,
            rewardRate: _rewardRate,
            claimed: 0,
            lastClaimDate: _lastClaimDate
        }));
        payable(_owner).transfer(_fee);
    }

    function claim()
        public
        payable
        nonReentrant
        onlyStakeholder
        onlyStarted
    {
        uint256 _totalRewards;
        uint256 _totalFees;
        for (uint256 i = 0; i < stakeholders[msg.sender].stakes.length; i++) {
            uint256 _reward = calculateReward(stakeholders[msg.sender].stakes[i]);
            uint256 _fee = calculateFee(_reward);
            stakeholders[msg.sender].stakes[i].claimed += _reward - _fee;
            stakeholders[msg.sender].stakes[i].lastClaimDate = block.timestamp;
            _totalRewards += _reward;
            _totalFees += _fee;
        }
        payable(msg.sender).transfer(_totalRewards - _totalFees);
        payable(_owner).transfer(_totalFees);
    }

    function calculateReward(Stake memory _stake)
        private
        view
        returns (uint256)
    {
        return (block.timestamp - _stake.lastClaimDate) * _stake.amount * _stake.rewardRate / 100 / 365 days;
    }

    function calculateRewardRate(uint256 _level)
        private
        pure
        returns (uint256)
    {
        uint256 _rewardRate = MIN_REWARD_RATE * (101 ** _level) / (100 ** _level);
        return min(_rewardRate, MAX_REWARD_RATE);
    }

    function calculateFee(uint256 _amount)
        private
        pure
        returns (uint256)
    {
        return _amount * 1 / 100;
    }

    function min(uint256 _a, uint256 _b)
        private
        pure
        returns (uint256)
    {
        return _a < _b ? _a : _b;
    }

    event Deposit(address indexed _stakeholder, uint256 _amount);
    event Claim(address indexed _stakeholder, uint256 _amount);
}