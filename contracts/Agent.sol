// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./SessionNFT.sol";

/**
 * @title Agent - Session Purchase and Reward Distribution
 * @dev A contract that manages batch session purchases and distributes rewards to session owners
 *
 * Key Features:
 * - Purchase individual or batch sessions
 * - Track purchased sessions
 * - Distribute rewards to session owners
 * - Handle token approvals and transfers
 */
contract Agent is Ownable, IERC721Receiver {
    IERC20 public plaiToken;
    SessionNFT public sessionNFT;
    
    // Total number of sessions purchased by this agent
    uint256 public totalSessionsPurchased;
    
    // Mapping to track if a session's rewards have been claimed
    mapping(uint256 => bool) public rewardsClaimed;
    
    // Current distribution pool
    uint256 public currentDistributionPool;
    
    event SessionPurchased(uint256 indexed sessionId);
    event BatchPurchase(uint256[] sessionIds);
    event RewardsDistributed(uint256 amount);
    event RewardClaimed(uint256 indexed sessionId, address indexed owner, uint256 amount);
    
    constructor(
        address initialOwner,
        address _plaiToken,
        address _sessionNFT
    ) Ownable(initialOwner) {
        plaiToken = IERC20(_plaiToken);
        sessionNFT = SessionNFT(_sessionNFT);
    }
    
    /**
     * @dev Purchase a single session
     * @param sessionId The ID of the session to purchase
     */
    function purchaseSession(uint256 sessionId) external onlyOwner {
        SessionNFT.Session memory session = sessionNFT.getSession(sessionId);
        
        if (session.purchasePrice > 0) {
            require(plaiToken.balanceOf(address(this)) >= session.purchasePrice, "Insufficient balance");
            plaiToken.approve(address(sessionNFT), session.purchasePrice);
            sessionNFT.purchaseSession(sessionId);
        }
        
        totalSessionsPurchased++;
        
        emit SessionPurchased(sessionId);
    }
    
    /**
     * @dev Purchase multiple sessions in a batch
     * @param sessionIds Array of session IDs to purchase
     */
    function batchPurchase(uint256[] calldata sessionIds) external onlyOwner {
        uint256 totalCost = 0;
        
        // Calculate total cost
        for (uint256 i = 0; i < sessionIds.length; i++) {
            SessionNFT.Session memory session = sessionNFT.getSession(sessionIds[i]);
            require(session.purchasePrice > 0, "Session not for sale");
            totalCost += session.purchasePrice;
        }
        
        // Approve total amount
        plaiToken.approve(address(sessionNFT), totalCost);
        
        // Purchase all sessions
        for (uint256 i = 0; i < sessionIds.length; i++) {
            sessionNFT.purchaseSession(sessionIds[i]);
            totalSessionsPurchased++;
        }
        
        emit BatchPurchase(sessionIds);
    }
    
    /**
     * @dev Distribute rewards to the contract for session owners to claim
     * @param amount Amount of PLAI tokens to distribute
     */
    function distribute(uint256 amount) external onlyOwner {
        require(totalSessionsPurchased > 0, "No sessions purchased");
        require(plaiToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        currentDistributionPool += amount;
        emit RewardsDistributed(amount);
    }
    
    /**
     * @dev Claim rewards for a session
     * @param sessionId The ID of the session to claim rewards for
     */
    function claimRewards(uint256 sessionId) external {
        SessionNFT.Session memory session = sessionNFT.getSession(sessionId);
        require(sessionNFT.hasPurchased(sessionId, address(this)), "Session not purchased by agent");
        require(!rewardsClaimed[sessionId], "Rewards already claimed");
        require(msg.sender == session.player, "Only session owner can claim");
        
        uint256 rewardAmount = currentDistributionPool / totalSessionsPurchased;
        require(rewardAmount > 0, "No rewards available");
        
        rewardsClaimed[sessionId] = true;
        require(plaiToken.transfer(msg.sender, rewardAmount), "Reward transfer failed");
        
        emit RewardClaimed(sessionId, msg.sender, rewardAmount);
    }
    
    /**
     * @dev Get the current reward amount per session
     * @return The amount of PLAI tokens each session owner can claim
     */
    function getRewardPerSession() external view returns (uint256) {
        if (totalSessionsPurchased == 0) return 0;
        return currentDistributionPool / totalSessionsPurchased;
    }

    /**
     * @dev Implements IERC721Receiver to receive NFTs
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
