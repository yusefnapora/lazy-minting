# Lazy Minting outline

## Motivation

Minting an NFT on a blockchain "mainnet" generally costs some amount of money, since writing data into the blockchain requires a fee, or _gas_, to pay for the computation and storage. This can be a barrier for artists and other NFT creators, especially those new to NFTs who may not want to invest a lot of money up front before knowing whether their work will sell.

Using a few advanced techniques, it's possible to defer the cost of minting an NFT until the moment it's sold to its first buyer. The gas fees for minting are rolled into the same transaction that assigns the NFT to the buyer, so the NFT creator never has to pay to mint. Instead, a portion of the purchase price simply goes to cover the additional gas needed to create the initial NFT record.

Minting "just in time" at the moment of purchase is often called _lazy minting_, and it has been [adopted by marketplaces like OpenSea](https://opensea.io/blog/announcements/introducing-the-collection-manager/) to lower the barrier to entry for NFT creators by making it possible to create NFTs without any up-front costs.

This guide will show how lazy minting works on Ethereum, using some helper libraries from [OpenZeppelin](https://openzeppelin.org).

## Overview

For lazy minting to work, we need a smart contract function that the NFT buyer can call that will both mint the NFT they want and assign it to their account, all in one transaction.

Before we get started, let's look at a _non-lazy_ minting function:

```solidity
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract EagerNFT is ERC721URIStorage, AccessControl {
  using Counters for Counters.Counter;
  Counters.Counter _tokenIds;

  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  constructor(address minter)
    ERC721("EagerNFT", "EGR") {
      _setupRole(MINTER_ROLE, minter);
    }

  function mint(address buyer, string tokenURI) {
    require(hasRole(MINTER_ROLE, msg.sender), "Unauthorized");
    
    // minting logic
    _tokenIds.increment();
    uint256 tokenId = _tokenIds.current();
    _mint(buyer, tokenId);
    _setTokenURI(tokenId, tokenURI);
  }
}
```

This contract builds on the [OpenZeppelin ERC721 base contract](https://docs.openzeppelin.com/contracts/4.x/erc721), adding role-based [Access Control](https://docs.openzeppelin.com/contracts/4.x/access-control).

In the `mint` function, we require that the caller has the `MINTER_ROLE`, ensuring that only authorized minters can create new NFTs.

In the lazy minting pattern, we need to change things a bit:

```solidity
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

contract LazyNFT {
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  constructor(address minter)
    ERC721("LazyNFT", "LAZ") {
      _setupRole(MINTER_ROLE, minter);
    }

  struct NFTVoucher {
    uint256 tokenId;
    uint256 minPrice;
    string uri;
  }

  function redeem(address redeemer, NFTVoucher calldata voucher, bytes memory signature) public payable {
    address signer = _verify(voucher, signature);
    require(hasRole(MINTER_ROLE, signer), "Invalid signature - unknown signer");

    // minting logic...
  }

  function _verify(NFTVoucher voucher, bytes memory signature) private returns (address signer) {
    // verify signature against input and recover address, or revert transaction if signature is invalid
  }
}
```

We'll get to the signatures and minting logic in a second. First, notice that we have a new `struct` named `NFTVoucher`. An `NFTVoucher` represents an un-minted NFT which hasn't yet been recorded. To turn it into a real NFT, a buyer can call the `redeem` function and pass in a voucher, plus a signature of the voucher that's been prepared by the NFT creator.

This contract still has role-based access controls, but we've changed things up a bit. Instead of checking that `msg.sender` is an authorized minter, we allow anyone to call the `redeem` function. The access controls are used to make sure that the signature was produced by someone authorized to mint NFTs. This works because verifying an Ethereum signature returns the address of the signer, so we can validate the voucher and learn who created it in one operation.
