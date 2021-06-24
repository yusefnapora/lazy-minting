# Lazy Minting outline

## Motivation

Minting an NFT on a blockchain "mainnet" generally costs some amount of money, since writing data into the blockchain requires a fee, or _gas_, to pay for the computation and storage. This can be a barrier for artists and other NFT creators, especially those new to NFTs who may not want to invest a lot of money up front before knowing whether their work will sell.

Using a few advanced techniques, it's possible to defer the cost of minting an NFT until the moment it's sold to its first buyer. The gas fees for minting are rolled into the same transaction that assigns the NFT to the buyer, so the NFT creator never has to pay to mint. Instead, a portion of the purchase price simply goes to cover the additional gas needed to create the initial NFT record.

Minting "just in time" at the moment of purchase is often called _lazy minting_, and it has been [adopted by marketplaces like OpenSea](https://opensea.io/blog/announcements/introducing-the-collection-manager/) to lower the barrier to entry for NFT creators by making it possible to create NFTs without any up-front costs.

This guide will show how lazy minting works on Ethereum, using some helper libraries from [OpenZeppelin](https://openzeppelin.org).

## High-level overview

For lazy minting to work, we need a smart contract function that the NFT buyer can call that will both mint the NFT they want, and assign it to their account, all in one transaction.

Before we get started, let's look at a _non-lazy_ minting function:

```solidity
contract EagerNFT {
  address owner;

  function mint(address buyer, uint256 tokenId, string tokenURI) {
    require(message.sender == owner, "Only the contract owner can mint an NFT!");
    // minting logic...
  }
}
```

This `mint` function can only be called by the contract owner. This is a simple form of access control. A real-world contract may use something more sophisticated, like allowing anyone with a "minter" role to call the `mint` function. This restriction lets us ensure that only the artist themselves can create a new NFT. This is an important feature we need to keep for lazy minting.

In the lazy minting pattern, we need to change things a bit:

```solidity
contract LazyNFT {
  address owner;

  function redeem(address buyer, uint256 tokenId, string calldata tokenURI, bytes32 signature) {
    address signer = _verify(tokenId, tokenURI, signature);
    require(signer == owner, "Invalid signature - unknown signer");

    // minting logic...
  }

  function _verify(uint256 tokenId, string calldata tokenURI, bytes32 signature) private returns (address signer) {
    // verify signature against input and recover address, or revert transaction if signature is invalid
  }
}
```

We'll get to the actual minting logic in a second. First, notice that the access control has been removed. Anyone can call our `redeem` function, which makes sense, since we want the buyer to call this function, and we want to allow anyone to buy an NFT.

We've also added a new parameter, `signature`. This is the key to lazy minting, so we'll go into how it's produced in detail below. For now, we can think of the signature as a "ticket" that a buyer can redeem for an NFT.

The signature serves two important purposes. First, we can use the signature to validate the contents of the NFT, to prove that the NFT creator really did want to create a token with this exact content. Second, validating the signature also produces the public key and address of the account that created the signature. Once we have that, we can make sure that it really was the NFT creator that produced the signature and not some impostor.

