// SPDX-License-Identifier: GPL-3.0-only

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

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

contract FeeSplit is Ownable {
    using SafeMath for uint256;
    
    address public tokenAddress;
    address public burnAddress;
    constructor(address _tokenAddress, address _burnAddress) public {
        tokenAddress = _tokenAddress;
        burnAddress = _burnAddress;
    }
    uint256 public totalCollectedSinceStart;
    uint256 internal _balance;
    uint256 internal burnAmount;
    function withdrawFeesWithBurn() public {
        IERC20 token = IERC20(tokenAddress);
        _balance = token.balanceOf(address(this));
        burnAmount = _balance.mul(500).div(1000);
        require(token.balanceOf(burnAddress) < 9000e18, "Burn cap reached");
        require(token.balanceOf(burnAddress).add(burnAmount) <= 9000e18, "Additional burn will exceed cap");
        token.transfer(burnAddress, burnAmount);
        token.transfer(address(0x856A4619fA7519D53E6F3a94260F55de62B83EEb), _balance.mul(225).div(1000)); // @1AndOnlyPika (45% devfee)
        token.transfer(address(0x68b59573Da735e4e75F8A687908b6f3bEd7CB6fa), _balance.mul(150).div(1000)); // Iron (30% devfee)
        token.transfer(address(0xE35E342cd9F2021518D2cd53068e183FfA69eeb2), _balance.mul(125).div(1000)); // Jared Grey (25% devee)
        totalCollectedSinceStart = totalCollectedSinceStart.add(_balance);
    }
    
    function withdrawFees() public {
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(burnAddress) == 9000e18, "Cannot bypass burn unless cap reached");
        _balance = token.balanceOf(address(this));
        token.transfer(address(0x856A4619fA7519D53E6F3a94260F55de62B83EEb), _balance.mul(45).div(100)); // @1AndOnlyPika (45% devfee)
        token.transfer(address(0x68b59573Da735e4e75F8A687908b6f3bEd7CB6fa), _balance.mul(30).div(100)); // Iron (30% devfee)
        token.transfer(address(0xE35E342cd9F2021518D2cd53068e183FfA69eeb2), _balance.mul(25).div(100)); // Jared Grey (25% devee)
        totalCollectedSinceStart = totalCollectedSinceStart.add(_balance);
    }
    
    uint256 internal toForceBurn = 9000e18;
    function forceBurnToFillGap() public onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        toForceBurn = toForceBurn.sub(token.balanceOf(burnAddress));
        token.transfer(burnAddress, toForceBurn);
        totalCollectedSinceStart = totalCollectedSinceStart.add(toForceBurn);
    }
    
    function withdrawExtraTokens(address _token) public onlyOwner {
        require(_token != tokenAddress, "Cannot withdraw managed token");
        IERC20 extratoken = IERC20(_token);
        extratoken.transfer(address(msg.sender), extratoken.balanceOf(address(this)));
    }
}