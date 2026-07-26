// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ManhattanRWA
 * @notice Automated system for fractional property ownership and asset consolidation.
 * Target Asset: 721 5th Ave, Penthouse, New York, NY 10022 (Trump Tower Penthouse).
 * Enables public crowdsourcing of premium real estate via fractional tokens ("bricks").
 * Includes an enterprise-grade Call Option registry for structured liquidity events and asset buyback.
 */
contract ManhattanRWA {
    // Legal property address and economic configuration variables
    string public propertyAddress = "721 5th Ave, Penthouse, New York, NY 10022";
    uint256 public totalPropertyPriceUSD = 15000000; 
    uint256 public totalBricks = 15000;              
    uint256 public pricePerBrickWei = 0.001 ether;  
    
    // Asset buyback price (1.2x of nominal value — 20% premium net profit for investors)
    uint256 public buybackPricePerBrickWei = 0.0012 ether; 

    address public propertyManager; 
    bool public propertyConsolidated = false; 

    mapping(address => uint256) public myBricks;
    uint256 public bricksSold;

    event BrickPurchased(address indexed buyer, uint256 amount);
    event PropertyConsolidated(address indexed manager, uint256 totalPayout);
    event PayoutClaimed(address indexed investor, uint256 amount);

    constructor() {
        propertyManager = msg.sender; // Deployer becomes the fund asset manager
    }

    // Public fractional allocation entry point
    function buyManhattanBrick(uint256 numberOfBricks) public payable {
        require(!propertyConsolidated, "Property is undergoing consolidation");
        require(numberOfBricks > 0, "You must buy at least 1 brick");
        require(bricksSold + numberOfBricks <= totalBricks, "Not enough bricks available");
        require(msg.value >= pricePerBrickWei * numberOfBricks, "Insufficient tokens sent");

        myBricks[msg.sender] += numberOfBricks;
        bricksSold += numberOfBricks;

        emit BrickPurchased(msg.sender, numberOfBricks);
    }

    // CONSOLIDATION INSTRUMENT: Corporate Asset Call Option
    // Asset manager supplies liquidity to buy back all shares with 20% liquidation bonus
    function consolidateProperty() public payable {
        require(msg.sender == propertyManager, "Only asset manager can trigger consolidation");
        require(!propertyConsolidated, "Asset already consolidated");
        
        uint256 totalRequiredFunds = bricksSold * buybackPricePerBrickWei;
        require(msg.value >= totalRequiredFunds, "Insufficient funds for asset liquidation bonus");

        propertyConsolidated = true;
        
        emit PropertyConsolidated(msg.sender, totalRequiredFunds);
    }

    // Investor claim function for liquidated capital distribution
    function claimLiquidatedFunds() public {
        require(propertyConsolidated, "Liquidation phase not active");
        uint256 userBricks = myBricks[msg.sender];
        require(userBricks > 0, "No active shares found");

        uint256 payout = userBricks * buybackPricePerBrickWei;
        myBricks[msg.sender] = 0; 

      (bool success, ) = msg.sender.call{value: payout}("");
require(success, "Transfer failed");
        
        emit PayoutClaimed(msg.sender, payout);
    }

    // Read-only external verification for specific account asset balances
    function checkMyBrickCount(address owner) public view returns (uint256) {
        return myBricks[owner];
    }
}
