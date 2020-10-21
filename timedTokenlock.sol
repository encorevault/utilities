// SPDX-License-Identifier: GPL-3.0-only

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

contract TokenLock is Ownable{
    using SafeMath for uint256;
    address public lockedToken;
    uint256 public contractStartTime;
    
    constructor(address _token) public {
        lockedToken = _token;
        contractStartTime = block.timestamp;
    }
    
    function lockedTokens() public view returns (uint256) {
        IERC20 token = IERC20(lockedToken);
        return token.balanceOf(address(this));
    }
    
    function withdrawExtraTokens(address _token) public onlyOwner {
        require(_token != lockedToken, "Cannot withdraw locked token");
        IERC20 token = IERC20(_token);
        require(token.balanceOf(address(this))>0, "No balance");
        token.transfer(address(msg.sender), token.balanceOf(address(this)));
    }
    
    function timelockOngoing() public view returns (bool) {
        return contractStartTime.add(90 days) > block.timestamp;
    }
    
    function withdrawAfterTimelock() public onlyOwner {
        require(timelockOngoing() == false, "Timelock not over");
        IERC20 token = IERC20(lockedToken);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
}