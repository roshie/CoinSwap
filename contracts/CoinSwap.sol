
// SPDX-License-Identifier: MIT

// Stake, 
// Unstake, 
// issue rewards, 
// add allowed tokens, 
// get eth value

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract CoinSwap is Ownable {

    // token address -> staker's address -> amount he staked
    mapping(address => mapping(address => uint256)) public stakeBalance;
    // staker -> how many types of token he staked
    mapping(address => uint256) public uniqueTokensStaked;
    // map tokens to their priceFeed
    mapping(address => address) public tokenPriceFeed;

    address[] public stakers;
    address[] public allowedTokens;
    IERC20 public mangoToken;


    constructor(address _mangoTokenAddress) public {
        mangoToken = IERC20(_mangoTokenAddress);
    }

    // Set the Chainlink's price feed address -> to the token
    function setPriceFeedContract(address _token, address _priceFeed) public onlyOwner {
        tokenPriceFeed[_token] = _priceFeed;
    }

    // Reward the users with MGO tokens 
    // ( 1 ETH = $2000 USD == 2000 MGOs )
    function issueTokens() public onlyOwner {
        // Iterate through the stakers list
        for (uint256 stakersInx = 0; stakersInx < stakers.length; stakersInx++) {

            address recipient = stakers[stakersInx];
            // Get the Value of the recipient's amount present in stake (in USD)
            uint256 userHoldingAmount = getStakedValueOfUser(recipient);
            // Send reward 
            mangoToken.transfer(recipient, userHoldingAmount);
        }
    }

    // Get How much the User has been staked in total (returns in USD)
    function getStakedValueOfUser(address _user) public view returns (uint256) {
        uint256 totalValue = 0;
        // The user has to be staked atleast a min amount.
        require(uniqueTokensStaked[_user] > 0, "No Tokens Staked");
        for (uint256 allowedTokensInx = 0; allowedTokensInx < allowedTokens.length; allowedTokensInx++) {
            totalValue = totalValue + getUserSingleTokenValue(_user, allowedTokens[allowedTokensInx]);
        }
        return totalValue;
    }

    // Get How much the User has been staked on one token (returns in USD)
    function getUserSingleTokenValue(address _user, address _token) public view returns(uint256) {
        if(uniqueTokensStaked[_user] <= 0) {
            return 0;
        }  
        // Price of the token (eg. ETH) * staking balance of the user (eg. 5 ETH)   
        (uint256 price, uint256 decimals) = getTokenValue(_token);

        // stakingBal * price x 10 ^-decimals
        return (stakeBalance[_token][_user] * price/(10**decimals));
    }

    // Get the token's value using chainlink AggregatorV3 (in USD)
    function getTokenValue(address _token) public view returns(uint256, uint256) {
        // PriceFeedAddress
        address priceFeedAddress = tokenPriceFeed[_token];
        AggregatorV3Interface _pricefeed = AggregatorV3Interface(priceFeedAddress);
        (, int256 price, , ,) = _pricefeed.latestRoundData();
        uint256 decimals = uint256(_pricefeed.decimals());
        return (uint256(price), decimals);
    }

    // Stake Tokens
    function stakeTokens(uint256 _amount, address _token) public {
        // The conditions are
        // The amount must be greater than zero
        require(_amount > 0, "Amount must be more than 0");
        // Only valid tokens are allowed to stake
        require(tokenIsAlowed(_token), "Oops! This token is currently not allowed to stake.");
        
        // Get the amount from the user
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);

        // Update how many different tokens does a user hold.
        updateUniqueTokenStaked(msg.sender, _token);
        stakeBalance[_token][msg.sender] = stakeBalance[_token][msg.sender] + _amount; 
        if (uniqueTokensStaked[msg.sender] == 1) {
            stakers.push(msg.sender);
        }
    }

    // Update how many different tokens does a user hold.
    function updateUniqueTokenStaked(address _user, address _token) internal {
        if (stakeBalance[_token][_user] <=0 ) {
            uniqueTokensStaked[_user] = uniqueTokensStaked[_user] + 1;
        }
    }

    // Add allowed tokens 
    function addAllowedTokens(address _token) public onlyOwner {
        allowedTokens.push(_token);
    }

    // Check whether the token is allowed or not.
    function tokenIsAlowed(address _token) public returns (bool) {
        for(uint256 allowedTokensInx=0; allowedTokensInx < allowedTokens.length; allowedTokensInx++) {
            if (allowedTokens[allowedTokensInx] == _token)
                return true;
        }
        return false;
    }

    // Unstake Tokens
    function unstakeTokens(address _token) public {
        uint256 balance = stakeBalance[_token][msg.sender];
        require(balance > 0, "You need to have a balance to stake!");
        IERC20(_token).transfer(msg.sender, balance);
        stakeBalance[_token][msg.sender] = 0;
        uniqueTokensStaked[msg.sender] = uniqueTokensStaked[msg.sender] - 1;
    }
}