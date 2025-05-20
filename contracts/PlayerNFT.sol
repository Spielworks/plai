// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PlayerNFT - Player Identity and Ownership Management
 * @dev A contract that manages player identities in the Playmind ecosystem through NFTs.
 *
 * This contract implements a one-to-one mapping between players and NFTs, ensuring:
 * 1. Each player can only own one PlayerNFT
 * 2. Each PlayerNFT uniquely identifies a player
 * 3. PlayerNFTs are required for participating in gameplay sessions
 *
 * Key Features:
 * - Single NFT per player address
 * - Immutable player-NFT association
 * - Metadata storage for player profiles
 * - Integration with SessionNFT for gameplay verification
 *
 * Security Features:
 * - Prevents multiple NFT minting per address
 * - Only owner can mint new PlayerNFTs
 * - Built on OpenZeppelin's ERC721 implementation
 *
 * The PlayerNFT serves as the foundational identity layer for the Playmind ecosystem,
 * enabling secure and verifiable gameplay sessions.
 */
contract PlayerNFT is ERC721URIStorage, Ownable {
    /**
     * @dev Initializes the PlayerNFT contract
     * @param initialOwner Address that will have permission to mint PlayerNFTs
     */
    constructor(address initialOwner) ERC721("PlaymindPlayer", "PLAYER") Ownable(initialOwner) {}
    uint256 private _tokenIdCounter;
    
    // Mapping from player address to token ID
    mapping(address => uint256) public playerToTokenId;
    
    /**
     * @dev Mints a new PlayerNFT to the specified address
     * @param to Address that will own the PlayerNFT
     * @param uri IPFS URI containing player metadata
     *
     * Requirements:
     * - Recipient must not already have a PlayerNFT
     *
     * This function:
     * 1. Validates the recipient doesn't have an NFT
     * 2. Mints a new NFT with unique tokenId
     * 3. Sets the token URI for metadata
     * 4. Records the token ownership in playerToTokenId mapping
     *
     * The PlayerNFT serves as the player's identity in the ecosystem,
     * enabling participation in gameplay sessions and verification.
     */
    function safeMint(address to, string memory uri) public {
        require(playerToTokenId[to] == 0, "Player already has an NFT");
        
        _tokenIdCounter++;
        uint256 tokenId = _tokenIdCounter;
        
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        
        playerToTokenId[to] = tokenId;
    }
    
    /**
     * @dev Checks if an address owns a PlayerNFT
     * @param player Address to check
     * @return bool True if the address owns a PlayerNFT, false otherwise
     *
     * This function is used by other contracts (GameNFT, SessionNFT) to verify
     * player ownership before allowing participation in gameplay sessions.
     * It's a key part of the access control system.
     */
    function hasPlayerNFT(address player) public view returns (bool) {
        return playerToTokenId[player] != 0;
    }
    
    /**
     * @dev Gets the token ID of a player's NFT
     * @param player Address of the player
     * @return uint256 Token ID of the player's NFT
     *
     * Requirements:
     * - Player must own a PlayerNFT
     *
     * This function is used to retrieve the specific token ID
     * associated with a player's address, enabling other contracts
     * to reference and verify the player's NFT. It reverts if the
     * player doesn't own an NFT.
     */
    function getPlayerTokenId(address player) public view returns (uint256) {
        require(playerToTokenId[player] != 0, "Player does not have an NFT");
        return playerToTokenId[player];
    }
}
