# Playmind

Welcome to the **Playmind Ecosystem**, a decentralized platform built on Ethereum that enables game publishers, players, and agents to interact securely and transparently. This README provides an in-depth overview of the ecosystem's components, their interactions, and how various functionalities are implemented.

---

## Table of Contents

1. [Overview](#overview)
2. [Contracts Overview](#contracts-overview)
   - [PlayerNFT](#playernft)
   - [SessionNFT](#sessionnft)
   - [GameNFT](#gamenft)
   - [Agent](#agent)
   - [PlaiToken](#plaitoken)
   - [PublisherRegistry](#publisherregistry)
3. [Workflow](#workflow)
   - [Publisher Adds Games](#publisher-adds-games)
   - [Players Start Sessions](#players-start-sessions)
   - [Configuring Purchase Prices](#configuring-purchase-prices)
   - [Session Protection via Lit Protocol](#session-protection-via-lit-protocol)
   - [Agents Purchase Sessions and Distribute Rewards](#agents-purchase-sessions-and-distribute-rewards)
4. [Security Features](#security-features)
5. [Conclusion](#conclusion)

---

## Overview

The **Playmind Ecosystem** is designed to provide a secure and verifiable environment for gameplay sessions. It leverages **Non-Fungible Tokens (NFTs)** to represent player identities (`PlayerNFT`), gameplay sessions (`SessionNFT`), and games (`GameNFT`). The ecosystem also includes mechanisms for session purchase, reward distribution, and cryptographic verification.

---

## Contracts Overview

### PlayerNFT

The `PlayerNFT` contract manages player identities within the Playmind ecosystem. Each player can own only one `PlayerNFT`, which serves as their unique identity.

- **Key Features:**
  - One-to-one mapping between players and NFTs.
  - Immutable player-NFT association.
  - Metadata storage for player profiles.
  - Integration with `SessionNFT` for gameplay verification.

- **Functions:**
  - `safeMint(address to, string memory uri)`: Mints a new `PlayerNFT` to the specified address.
  - `hasPlayerNFT(address player)`: Checks if an address owns a `PlayerNFT`.
  - `getPlayerTokenId(address player)`: Retrieves the token ID of a player's NFT.

### SessionNFT

The `SessionNFT` contract manages and verifies gameplay sessions through NFTs and cryptographic proofs.

- **Key Features:**
  - Session NFTs tied to `PlayerNFTs`.
  - Minimum session duration enforcement.
  - IPFS-based gameplay data storage.
  - Cryptographic verification using ECDSA.
  - Session state tracking.

- **Functions:**
  - `startSession(...)`: Starts a new gameplay session.
  - `endSession(string calldata ipfsCID, bytes32 dataHash)`: Ends a gameplay session to await upload data to IPFS.
  - `verifySession(uint256 tokenId, bytes memory signature)`: Verifies a session with proof of play.
  - `purchaseSession(uint256 tokenId)`: Allows users to purchase access to a session's data.

### GameNFT

The `GameNFT` contract manages game registrations and gameplay sessions in the Playmind ecosystem.

- **Key Features:**
  - Only verified publishers can register games.
  - Each game is represented as a unique NFT.
  - Games can be activated/deactivated by their publishers.
  - Integrated with `SessionNFT` for gameplay session management.

- **Functions:**
  - `registerGame(...)`: Registers a new game in the ecosystem.
  - `startSession(uint256 gameId)`: Starts a new gameplay session for a specific game.
  - `setGameActive(uint256 gameId, bool active)`: Updates the active status of a game.
  - `setEncryptionProtocol(uint256 gameId, string memory protocol)`: Updates the encryption protocol for a game.

### Agent

The `Agent` contract manages batch session purchases and distributes rewards to session owners.

- **Key Features:**
  - Purchase individual or batch sessions.
  - Track purchased sessions.
  - Distribute rewards to session owners.
  - Handle token approvals and transfers.

- **Functions:**
  - `purchaseSession(uint256 sessionId)`: Purchases a single session.
  - `batchPurchase(uint256[] calldata sessionIds)`: Purchases multiple sessions in a batch.
  - `distribute(uint256 amount)`: Distributes rewards to the contract for session owners to claim.
  - `claimRewards(uint256 sessionId)`: Allows session owners to claim rewards.

### PlaiToken

The `PlaiToken` contract is an ERC20 token used for payments and rewards within the ecosystem.

- **Key Features:**
  - Mintable by the owner.
  - Used for session purchases and reward distributions.

### PublisherRegistry

The `PublisherRegistry` contract manages the verification and status of game publishers in the Playmind ecosystem.

- **Key Features:**
  - Publisher verification by platform owner.
  - Active/inactive status management.
  - Immutable publisher metadata.

- **Functions:**
  - `verifyPublisher(...)`: Verifies a new publisher in the ecosystem.
  - `deactivatePublisher(address publisherAddress)`: Temporarily deactivates a verified publisher.
  - `reactivatePublisher(address publisherAddress)`: Reactivates a previously deactivated publisher.
  - `isVerifiedPublisher(address publisherAddress)`: Checks if an address is a verified and active publisher.

---

## Workflow

### Publisher Adds Games

1. **Verification:** Publishers must first be verified in the `PublisherRegistry` by the platform owner.
2. **Registration:** Verified publishers can register new games using the `GameNFT.registerGame(...)` function. Each game is minted as a unique NFT.
3. **Activation:** Publishers can activate or deactivate their games using `GameNFT.setGameActive(...)`.

### Players Start Sessions

1. **PlayerNFT Requirement:** Players must own a `PlayerNFT` to participate in gameplay sessions.
2. **Session Creation:** Players start sessions by calling `GameNFT.startSession(...)`. This creates a new `SessionNFT` tied to the player and the game.
3. **Session Completion:** Players end sessions by calling `SessionNFT.endSession(...)`, uploading gameplay data to IPFS.

### Configuring Purchase Prices

- **Price Configuration:** Publishers can set purchase prices for their games during registration (`GameNFT.registerGame(...)`). It can be zero, as there are as well strategies to monetize on usage (agents distributing rewards).
- **Payment Handling:** When players start sessions, they pay the configured price using the specified ERC20 token.

### Session Protection via Lit Protocol

- **Encryption Protocol:** Publishers can configure encryption protocols for their games using `GameNFT.setEncryptionProtocol(...)`.
- **Lit Protocol Integration:** When using the Lit Protocol, access conditions ensure that only users who have purchased the session can access encrypted content.

```javascript
const litAccessConditions = [{
    contractAddress: sessionNFT.address,
    chain: "ethereum",
    standardContractType: "custom",
    method: "sessionPurchases",
    parameters: [":tokenId", ":userAddress"],
    returnValueTest: {
        comparator: "=",
        value: "true"
    }
}];
```

### Agents Purchase Sessions and Distribute Rewards

1. **Batch Purchases:** Agents can purchase multiple sessions in bulk using `Agent.batchPurchase(...)`.
2. **Reward Distribution:** Agents distribute rewards to session owners by calling `Agent.distribute(...)`.
3. **Reward Claiming:** Session owners can claim their rewards using `Agent.claimRewards(...)`.

---

## Security Features

- **Access Control:** Only verified publishers can register games. Only game publishers can verify sessions.
- **Immutable Associations:** Player-NFT associations are immutable, ensuring secure identity management.
- **Cryptographic Verification:** Sessions are verified using ECDSA signatures, ensuring data integrity.
- **Minimum Session Duration:** Enforces a minimum session duration to prevent abuse.

---

## Conclusion

The **Playmind Ecosystem** provides a robust framework for managing game publishers, players, and gameplay sessions in a decentralized manner. By leveraging NFTs, cryptographic proofs, and smart contracts, it ensures secure, verifiable, and tamper-proof interactions within the ecosystem.

For more information, please refer to the individual contract documentation or contact the development team.
