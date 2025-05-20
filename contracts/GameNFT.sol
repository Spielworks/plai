// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PlayerNFT.sol";
import "./SessionNFT.sol";
import "./PublisherRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title GameNFT - Game Registration and Session Management
 * @dev A contract for managing game registrations and gameplay sessions in the Playmind ecosystem.
 *
 * This contract serves as the central hub for game management, allowing verified publishers to:
 * 1. Register new games as NFTs
 * 2. Manage game metadata and active status
 * 3. Control session creation for their games
 *
 * Key Features:
 * - Only verified publishers can register games
 * - Each game is represented as a unique NFT
 * - Games can be activated/deactivated by their publishers
 * - Integrated with SessionNFT for gameplay session management
 * - Tracks active sessions per game
 *
 * Security Features:
 * - Publisher verification through PublisherRegistry
 * - Access control for game management functions
 * - Session creation restricted to players with PlayerNFTs
 */
contract GameNFT is ERC721URIStorage, Ownable {
    uint256 private _tokenIdCounter;
    SessionNFT public sessionNFT;
    PlayerNFT public playerNFT;
    PublisherRegistry public publisherRegistry;
    string private defaultEncryptionProtocol;
    
    // Game metadata
    struct GameMetadata {
        string name;
        string version;
        address publisher;
        bool active;
        address paymentToken;
        uint256 price;
        string encryptionProtocol;
    }
    
    // Mapping from token ID to GameMetadata
    mapping(uint256 => GameMetadata) public games;
    
    // Mapping from game token ID to active sessions count
    mapping(uint256 => uint256) public activeSessions;
    
    event GameRegistered(uint256 indexed tokenId, string name, string version, address publisher);
    event SessionStarted(uint256 indexed gameId, uint256 indexed sessionId, address indexed player);
    
    /**
     * @dev Initializes the GameNFT contract with required dependencies
     * @param initialOwner Address of the contract owner
     * @param _sessionNFT Address of the SessionNFT contract
     * @param _playerNFT Address of the PlayerNFT contract
     * @param _publisherRegistry Address of the PublisherRegistry contract
     */
    constructor(
        address initialOwner,
        address _sessionNFT,
        address _playerNFT,
        address _publisherRegistry,
        string memory defaultEncryptionProtocol_
    ) ERC721("PlaymindGame", "GAME") Ownable(initialOwner) {
        sessionNFT = SessionNFT(_sessionNFT);
        playerNFT = PlayerNFT(_playerNFT);
        publisherRegistry = PublisherRegistry(_publisherRegistry);
        defaultEncryptionProtocol = defaultEncryptionProtocol_;
    }
    
    /**
     * @dev Registers a new game in the ecosystem
     * @param name Name of the game
     * @param version Version string of the game
     * @param uri IPFS URI containing game metadata
     * @param publisher Address of the game publisher
     * @return tokenId The unique identifier for the newly registered game
     *
     * Requirements:
     * - Publisher must be verified in the PublisherRegistry
     * - Only the publisher themselves can register their games
     *
     * Emits a {GameRegistered} event upon successful registration
     */
    function registerGame(
        string memory name,
        string memory version,
        string memory uri,
        address publisher,
        address paymentToken,
        uint256 price
    ) external returns (uint256) {
        // Check if the publisher is verified
        require(publisherRegistry.isVerifiedPublisher(publisher), "Publisher not verified");
        // Only the publisher themselves can register their game
        require(msg.sender == publisher, "Only publisher can register game");
        _tokenIdCounter++;
        uint256 tokenId = _tokenIdCounter;
        
        games[tokenId] = GameMetadata({
            name: name,
            version: version,
            publisher: publisher,
            active: true,
            paymentToken: paymentToken,
            price: price,
            encryptionProtocol: defaultEncryptionProtocol
        });
        
        _safeMint(publisher, tokenId);
        _setTokenURI(tokenId, uri);
        
        emit GameRegistered(tokenId, name, version, publisher);
        return tokenId;
    }
    
    /**
     * @dev Starts a new gameplay session for a specific game
     * @param gameId The ID of the game to start a session for
     * @return sessionId The unique identifier for the newly created session
     *
     * Requirements:
     * - Game must exist and be active
     * - Player must own a PlayerNFT
     * - Game publisher must be available to verify the session
     *
     * This function:
     * 1. Validates game and player requirements
     * 2. Creates a new session through SessionNFT
     * 3. Updates active sessions counter
     * 4. Emits a {SessionStarted} event
     */
    function startSession(uint256 gameId) external returns (uint256) {
        require(_ownerOf(gameId) != address(0), "Game does not exist");
        require(games[gameId].active, "Game is not active");
        require(playerNFT.hasPlayerNFT(msg.sender), "Must own a PlayerNFT");
        
        // Handle payment
        if (games[gameId].price > 0) {
            require(IERC20(games[gameId].paymentToken).transferFrom(
                msg.sender,
                games[gameId].publisher,
                games[gameId].price
            ), "Payment failed");
        }
        
        // Get the game publisher (owner) who will be the verifier
        address publisher = games[gameId].publisher;
        
        // Start session in SessionNFT contract
        uint256 sessionId = sessionNFT.startSession(
            msg.sender,
            gameId,
            publisher,
            games[gameId].price,
            games[gameId].paymentToken
        );
        
        // Increment active sessions for this game
        activeSessions[gameId]++;
        
        emit SessionStarted(gameId, sessionId, msg.sender);
        return sessionId;
    }
    
    /**
     * @dev Updates the active status of a game
     * @param gameId The ID of the game to update
     * @param active The new active status (true = active, false = inactive)
     *
     * Requirements:
     * - Only the game's publisher can update its status
     *
     * This allows publishers to temporarily disable their games
     * while maintaining ownership and history. Inactive games
     * cannot start new sessions but existing sessions remain valid.
     */
    function setGameActive(uint256 gameId, bool active) external {
        require(msg.sender == games[gameId].publisher, "Only publisher can modify");
        games[gameId].active = active;
    }

    /**
     * @dev Updates the encryption protocol for a game
     * @param gameId The ID of the game to update
     * @param protocol The new encryption protocol ("none" or "LITProtocol")
     */
    function setEncryptionProtocol(uint256 gameId, string memory protocol) external {
        require(msg.sender == games[gameId].publisher, "Only publisher can modify");
        require(
            keccak256(bytes(protocol)) == keccak256(bytes("none")) ||
            keccak256(bytes(protocol)) == keccak256(bytes("LITProtocol")),
            "Invalid protocol"
        );
        games[gameId].encryptionProtocol = protocol;
    }

    /**
     * @dev Gets the encryption protocol for a game
     * @param gameId The ID of the game
     * @return The encryption protocol being used
     *
     * When using LITProtocol, implement the following access conditions:
     * ```javascript
     * const litAccessConditions = [{
     *   contractAddress: sessionNFT.address,
     *   chain: "ethereum",
     *   standardContractType: "custom",
     *   method: "sessionPurchases",
     *   parameters: [":tokenId", ":userAddress"],
     *   returnValueTest: {
     *     comparator: "=",
     *     value: "true"
     *   }
     * }];
     * ```
     * 
     * This configuration ensures that only users who have purchased the session
     * can access the encrypted content. The sessionPurchases mapping in SessionNFT
     * is used to verify purchase status.
     */
    function getEncryptionProtocol(uint256 gameId) external view returns (string memory) {
        require(_ownerOf(gameId) != address(0), "Game does not exist");
        return games[gameId].encryptionProtocol;
    }
    
    /**
     * @dev Get game metadata
     * @param gameId Game token ID
     */
    function getGame(uint256 gameId) external view returns (GameMetadata memory) {
        require(_ownerOf(gameId) != address(0), "Game does not exist");
        return games[gameId];
    }
}
