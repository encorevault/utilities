// SPDX-License-Identifier: GPL-3.0-only

//@1AndOnlyPika, EnCore
//
// Cloning this and using for your own purposes is a-ok, but could you at least be a 
// decent human and leave the credits at the top? Thanks in advance.


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

pragma solidity ^0.6.12;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IEncoreVault {
    function stakedTokens(uint256 _pid, address _user) external view returns (uint256);
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function massUpdatePools() external;
}

interface ITokenLockWithRelease {
    function releaseTokens() external returns (uint256);
}

contract TimelockVault is Ownable{
    using SafeMath for uint256;
    address public lockedToken;
    uint256 public contractStartTime;
    address public encoreVaultAddress;
    uint256 internal poolID;
    address public encoreAddress;
    uint256 public totalLPContributed;
    mapping(address => uint256) public LPContributed;
    bool public lockingCompleted = false;
    address public tokenLock;
    
    constructor(address _token, address _vault, uint256 _pid, address _encore) public {
        lockedToken = _token;
        encoreVaultAddress = _vault;
        contractStartTime = block.timestamp;
        poolID = _pid;
        encoreAddress = _encore;
        IERC20 token = IERC20(lockedToken);
        token.approve(encoreVaultAddress, 9999999999999999999999999999999999999999);
    }
    
    function withdrawExtraTokens(address _token) public onlyOwner {
        require(_token != lockedToken, "Cannot withdraw locked token");
        require(_token != encoreAddress, "Cannot withdraw ENCORE unless grace period is over");
        IERC20 token = IERC20(_token);
        require(token.balanceOf(address(this))>0, "No balance");
        token.transfer(address(msg.sender), token.balanceOf(address(this)));
    }
    
    function timelockOngoing() public view returns (bool) { // If the timelock deposit period is going on ot not
        return contractStartTime.add(3 days) > block.timestamp;
    }
    
    function setLockAddress(address _lock) public onlyOwner {
        tokenLock = _lock;
    }
    
    function lockperiodOngoing() public view returns (bool) { // If the locking period is going on or not
        return contractStartTime.add(48 days) > block.timestamp;
    }
    
    function devGracePeriod() public view returns (bool) { // The timer for the dev to drain the tokens
        return contractStartTime.add(51 days) < block.timestamp;
    }
    
    function emergencyDrainPeriod() public view returns (bool) { // 24 hours after the lock period ends, in the case rewards weren't able to be withdrawn
        return contractStartTime.add(49 days) < block.timestamp;
    }
    
    function lockTokens(uint256 _amount) public {
        require(timelockOngoing() == true, "Lock period over");
        IERC20 token = IERC20(lockedToken);
        token.transferFrom(msg.sender, address(this), _amount);
        totalLPContributed += _amount;
        LPContributed[msg.sender] += _amount;
    }
    
    function stakeLPTokens() public {
        require(timelockOngoing() == false, "Lock period not over");
        IEncoreVault vault = IEncoreVault(encoreVaultAddress);
        vault.deposit(poolID, totalLPContributed);
    }
    
    uint256 public totalLP;
    uint256 public LPPerUnit;
    uint256 public totalENCORE;
    uint256 public ENCOREPerUnit;
    function claimLPAndRewards() public {
        require(lockperiodOngoing() == false, "Timelock period not over");
        IERC20 token = IERC20(lockedToken);
        ITokenLockWithRelease locker = ITokenLockWithRelease(tokenLock);
        require(locker.releaseTokens() > 0, "No locked rewards");
        IEncoreVault vault = IEncoreVault(encoreVaultAddress);
        vault.massUpdatePools();
        vault.withdraw(poolID, totalLPContributed);
        totalLP = token.balanceOf(address(this));
        LPPerUnit  = totalLP.mul(1e18).div(totalLPContributed);
        IERC20 encore = IERC20(encoreAddress);
        totalENCORE = encore.balanceOf(address(this));
        ENCOREPerUnit = totalENCORE.mul(1e18).div(totalLPContributed);
        lockingCompleted = true;
    }
    
    function emergencyDrain() public onlyOwner {
        require(emergencyDrainPeriod() == true, "Emergency drain period not completed");
        require(lockingCompleted == false, "Locking has completed");
        IERC20(lockedToken).transfer(msg.sender, IERC20(lockedToken).balanceOf(address(this)));
        IERC20(encoreAddress).transfer(msg.sender, IERC20(encoreAddress).balanceOf(address(this)));
    }
    
    function claim() public {
        require(lockingCompleted == true, "Locking period not over");
        require(LPContributed[msg.sender] != 0, "Nothing to claim, move along");
        IERC20 token = IERC20(lockedToken);
        IERC20 encore = IERC20(encoreAddress);
        token.transfer(msg.sender, LPContributed[msg.sender].mul(LPPerUnit).div(1e18));
        encore.transfer(msg.sender, LPContributed[msg.sender].mul(ENCOREPerUnit).div(1e18));
        LPContributed[msg.sender] = 0;
    }
    
    function drain() public onlyOwner {
        require(devGracePeriod() == true, "Grace period not over");
        IERC20(lockedToken).transfer(msg.sender, IERC20(lockedToken).balanceOf(address(this)));
        IERC20(encoreAddress).transfer(msg.sender, IERC20(encoreAddress).balanceOf(address(this)));
    }
}