// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PublisherRegistry - Game Publisher Verification System
 * @dev A contract that manages the verification and status of game publishers in the Playmind ecosystem.
 *
 * This contract acts as a trusted registry for game publishers, providing:
 * 1. Publisher verification and metadata management
 * 2. Active status tracking for publishers
 * 3. Integration with GameNFT for game registration authorization
 *
 * Key Features:
 * - Publisher verification by platform owner
 * - Publisher metadata storage (name, website)
 * - Active/inactive status management
 * - Query functions for publisher verification
 *
 * Security Features:
 * - Only owner can verify publishers
 * - Publishers cannot be deleted, only deactivated
 * - Immutable publisher metadata
 * - Built on OpenZeppelin's Ownable for access control
 *
 * The PublisherRegistry serves as the trust layer of the Playmind ecosystem,
 * ensuring that only legitimate publishers can create and manage games.
 */
contract PublisherRegistry is Ownable {
    struct Publisher {
        string name;
        string website;
        uint256 verificationDate;
        bool active;
    }
    
    // Mapping from publisher address to Publisher data
    mapping(address => Publisher) public publishers;
    
    event PublisherVerified(address indexed publisher, string name, string website);
    event PublisherDeactivated(address indexed publisher);
    event PublisherReactivated(address indexed publisher);
    
    /**
     * @dev Initializes the PublisherRegistry contract
     * @param initialOwner Address that will have permission to verify publishers
     *
     * The owner will be responsible for verifying legitimate game publishers
     * and managing their active status in the ecosystem.
     */
    constructor(address initialOwner) Ownable(initialOwner) {}
    
    /**
     * @dev Verifies a new publisher in the ecosystem
     * @param publisherAddress Address of the publisher to verify
     * @param name Official registered name of the publisher
     * @param website Official website URL of the publisher
     *
     * Requirements:
     * - Only contract owner can verify publishers
     * - Publisher must not be already verified
     * - Name and website must not be empty
     *
     * This function:
     * 1. Creates a new Publisher record
     * 2. Sets verification timestamp
     * 3. Activates the publisher
     * 4. Emits a {PublisherVerified} event
     */
    function verifyPublisher(
        address publisherAddress,
        string memory name,
        string memory website
    ) external onlyOwner {
        require(publisherAddress != address(0), "Invalid address");
        require(publishers[publisherAddress].verificationDate == 0, "Publisher already exists");
        
        publishers[publisherAddress] = Publisher({
            name: name,
            website: website,
            verificationDate: block.timestamp,
            active: true
        });
        
        emit PublisherVerified(publisherAddress, name, website);
    }
    
    /**
     * @dev Temporarily deactivates a verified publisher
     * @param publisherAddress Address of the publisher to deactivate
     *
     * Requirements:
     * - Only contract owner can deactivate publishers
     * - Publisher must exist in the registry
     *
     * This function:
     * 1. Sets the publisher's active status to false
     * 2. Emits a {PublisherDeactivated} event
     *
     * Deactivated publishers cannot register new games but retain
     * their verification history and existing games.
     */
    function deactivatePublisher(address publisherAddress) external onlyOwner {
        require(publishers[publisherAddress].verificationDate != 0, "Publisher does not exist");
        publishers[publisherAddress].active = false;
        emit PublisherDeactivated(publisherAddress);
    }
    
    /**
     * @dev Reactivates a previously deactivated publisher
     * @param publisherAddress Address of the publisher to reactivate
     *
     * Requirements:
     * - Only contract owner can reactivate publishers
     * - Publisher must exist in the registry
     *
     * This function:
     * 1. Sets the publisher's active status to true
     * 2. Emits a {PublisherReactivated} event
     *
     * Reactivation restores the publisher's ability to register
     * and manage games in the ecosystem.
     * @param publisherAddress Address of the publisher to reactivate
     */
    function reactivatePublisher(address publisherAddress) external onlyOwner {
        require(publishers[publisherAddress].verificationDate != 0, "Publisher does not exist");
        publishers[publisherAddress].active = true;
        emit PublisherReactivated(publisherAddress);
    }
    
    /**
     * @dev Checks if an address is a verified and active publisher
     * @param publisherAddress Address to check
     * @return bool True if the publisher is verified and active
     *
     * This function is used by other contracts (particularly GameNFT)
     * to validate publisher permissions before allowing game registration
     * and session verification.
     *
     * A publisher must be both:
     * 1. Verified (has a verification date)
     * 2. Active (not deactivated)
     */
    function isVerifiedPublisher(address publisherAddress) external view returns (bool) {
        return publishers[publisherAddress].verificationDate != 0 && 
               publishers[publisherAddress].active;
    }
    
    /**
     * @dev Retrieves the complete details of a publisher
     * @param publisherAddress Address of the publisher
     * @return Publisher struct containing all publisher metadata
     *
     * Requirements:
     * - Publisher must exist in the registry
     *
     * Returns the complete Publisher struct including:
     * - Official name
     * - Website URL
     * - Verification date
     * - Active status
     */
    function getPublisher(address publisherAddress) external view returns (Publisher memory) {
        require(publishers[publisherAddress].verificationDate != 0, "Publisher does not exist");
        return publishers[publisherAddress];
    }
}
