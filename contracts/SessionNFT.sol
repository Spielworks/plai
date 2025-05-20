// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./PlayerNFT.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SessionNFT - Gameplay Session Management and Verification
 * @dev A contract that manages and verifies gameplay sessions through NFTs and cryptographic proofs.
 *
 * This contract handles the complete lifecycle of gameplay sessions:
 * 1. Session creation and association with players and games
 * 2. Session completion with gameplay data
 * 3. Cryptographic verification by game publishers
 *
 * Key Features:
 * - Session NFTs tied to PlayerNFTs
 * - Minimum session duration enforcement
 * - IPFS-based gameplay data storage
 * - Cryptographic verification using ECDSA
 * - Session state tracking
 *
 * Security Features:
 * - Only GameNFT contract can start sessions
 * - Only session players can end their sessions
 * - Only game publishers can verify sessions
 * - Cryptographic proof of gameplay integrity
 * - Built on OpenZeppelin's ERC721 and ECDSA
 *
 * The SessionNFT serves as the proof-of-play layer in the Playmind ecosystem,
 * ensuring verifiable and tamper-proof gameplay records.
 */
contract SessionNFT is ERC721URIStorage, Ownable {
    constructor(address _playerNFT, address initialOwner) 
        ERC721("PlaymindSession", "SESSION") 
        Ownable(initialOwner) 
    {
        playerNFT = PlayerNFT(_playerNFT);
    }


    using ECDSA for bytes32;

    PlayerNFT public playerNFT;
    uint256 private _tokenIdCounter;
    
    // Minimum session duration in seconds
    uint256 public constant MIN_SESSION_DURATION = 300; // 5 minutes
    
    struct Session {
        address player;
        uint256 gameId;
        address verifier;  // Game publisher who will verify the session
        uint256 startTime;
        uint256 endTime;
        string ipfsCID;
        bytes32 dataHash;
        bool verified;
        uint256 purchasePrice;  // Price to purchase access to this session's data
        address paymentToken;  // ERC20 token used for payment
    }

    // Mapping to track if an address has purchased access to a session
    mapping(uint256 => mapping(address => bool)) private sessionPurchases;
    
    // Mapping from token ID to Session
    mapping(uint256 => Session) public sessions;
    
    // Mapping to track active sessions
    mapping(address => uint256) public activeSessions;
    
    event SessionStarted(address indexed player, uint256 indexed tokenId, uint256 startTime);
    event SessionEnded(address indexed player, uint256 indexed tokenId, uint256 endTime, string ipfsCID);
    event SessionVerified(uint256 indexed tokenId, bytes32 dataHash);
    event SessionPurchased(uint256 indexed tokenId, address indexed purchaser, uint256 price);
    

    
    /**
     * @dev Start a new gameplay session
     * @return tokenId The ID of the new session NFT
     */
    function startSession(
        address player,
        uint256 gameId,
        address verifier,
        uint256 purchasePrice,
        address paymentToken
    ) external returns (uint256) {
        // Only GameNFT contract can start sessions
        require(msg.sender == owner(), "Only GameNFT can start sessions");
        require(activeSessions[player] == 0, "Active session exists");
        
        _tokenIdCounter++;
        uint256 tokenId = _tokenIdCounter;
        
        sessions[tokenId] = Session({
            player: player,
            gameId: gameId,
            verifier: verifier,
            startTime: block.timestamp,
            endTime: 0,
            ipfsCID: "",
            dataHash: bytes32(0),
            verified: false,
            purchasePrice: purchasePrice,
            paymentToken: paymentToken
        });
        
        activeSessions[player] = tokenId;
        _safeMint(player, tokenId);
        
        emit SessionStarted(player, tokenId, block.timestamp);
        return tokenId;
    }
    
    /**
     * @dev End a gameplay session and upload data to IPFS
     * @param ipfsCID IPFS CID of the session data
     * @param dataHash Hash of the session data for verification
     */
    function endSession(string calldata ipfsCID, bytes32 dataHash) external {
        uint256 tokenId = activeSessions[msg.sender];
        require(tokenId != 0, "No active session");
        
        Session storage session = sessions[tokenId];
        require(session.player == msg.sender, "Not session owner");
        require(block.timestamp - session.startTime >= MIN_SESSION_DURATION, "Session too short");
        
        session.endTime = block.timestamp;
        session.ipfsCID = ipfsCID;
        session.dataHash = dataHash;
        
        activeSessions[msg.sender] = 0;
        _setTokenURI(tokenId, ipfsCID);
        
        emit SessionEnded(msg.sender, tokenId, block.timestamp, ipfsCID);
    }
    
    /**
     * @dev Verify a session with proof of play
     * @param tokenId The session token ID
     * @param signature The signature proving the data authenticity
     */
    function verifySession(uint256 tokenId, bytes memory signature) external {
        Session storage session = sessions[tokenId];
        require(!session.verified, "Session already verified");
        require(session.endTime > 0, "Session not ended");
        
        // Create message hash containing session data
        bytes32 messageHash = keccak256(abi.encodePacked(
            session.player,
            session.startTime,
            session.endTime,
            session.ipfsCID,
            session.dataHash
        ));
        
        // Verify the signature is from an authorized verifier (game server)
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        address signer = ECDSA.recover(ethSignedMessageHash, signature);
        require(signer == session.verifier, "Only game publisher can verify");
        
        session.verified = true;
        emit SessionVerified(tokenId, session.dataHash);
    }
    
    // Role for authorized verifiers (game servers)
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    
    /**
     * @dev Get session details
     * @param tokenId The session token ID
     */
    function getSession(uint256 tokenId) external view returns (Session memory) {
        require(_ownerOf(tokenId) != address(0), "Session does not exist");
        return sessions[tokenId];
    }

    /**
     * @dev Purchase access to a session's data
     * @param tokenId The ID of the session to purchase
     *
     * Requirements:
     * - Session must exist and be ended
     * - Purchaser must send exact purchase price
     * - Purchaser must not have already purchased this session
     *
     * This function:
     * 1. Validates the purchase requirements
     * 2. Records the purchase in sessionPurchases
     * 3. Transfers the payment to the session player
     * 4. Emits a SessionPurchased event
     */
    function purchaseSession(uint256 tokenId) external {
        require(_ownerOf(tokenId) != address(0), "Session does not exist");
        Session storage session = sessions[tokenId];
        require(session.endTime > 0, "Session not ended");

        if (session.purchasePrice > 0) {
            require(IERC20(session.paymentToken).transferFrom(msg.sender, session.player, session.purchasePrice), "Payment failed");
        }
        require(!sessionPurchases[tokenId][msg.sender], "Already purchased");

        sessionPurchases[tokenId][msg.sender] = true;
        emit SessionPurchased(tokenId, msg.sender, session.purchasePrice);
    }

    /**
     * @dev Check if an address has purchased access to a session
     * @param tokenId The session ID to check
     * @param purchaser The address to check
     * @return bool True if the address has purchased access
     */
    function hasPurchased(uint256 tokenId, address purchaser) external view returns (bool) {
        return sessionPurchases[tokenId][purchaser];
    }
    
    /**
     * @dev Check if a session is active
     * @param player The player's address
     */
    function hasActiveSession(address player) external view returns (bool) {
        return activeSessions[player] != 0;
    }
}
