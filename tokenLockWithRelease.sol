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

contract TokenLockWithRelease is Ownable{
    using SafeMath for uint256;
    address public lockedToken;
    address public distributor;
    
    constructor(address _token, address _dist) public {
        lockedToken = _token;
        distributor = _dist;
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
    
    function releaseTokens() public returns (uint256) {
        require(msg.sender == distributor, "Only the distributor may call this");
        IERC20 token = IERC20(lockedToken);
        uint256 toTransfer = token.balanceOf(address(this));
        token.transfer(distributor, toTransfer);
        return toTransfer;
    }
}