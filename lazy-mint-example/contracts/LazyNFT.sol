//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

contract LazyNFT is ERC721URIStorage, EIP712, AccessControl {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  constructor(address minter)
    ERC721("LazyNFT", "LAZ") 
    EIP712("LazyNFT-Voucher", "1") {
      _setupRole(MINTER_ROLE, minter);
    }

  /// @notice Represents an un-minted NFT, which has not yet been recorded into the blockchain. A signed voucher can be redeemed for a real NFT in the redeem function.
  struct NFTVoucher {
    /// @notice The id of the token to be redeemed. Must be unique - if another token with this ID already exists, the redeem function will revert.
    uint256 tokenId;

    /// @notice The minimum price (in wei) that the NFT creator is willing to accept for the initial sale of this NFT.
    uint256 minPrice;

    /// @notice The metadata URI to associate with this token.
    string uri;
  }


  /// @notice Redeems an NFTVoucher for an actual NFT, creating it in the process.
  /// @param redeemer The address of the account which will receive the NFT upon success.
  /// @param voucher An NFTVoucher that describes the NFT to be redeemed.
  /// @param signature An EIP712 signature of the voucher, produced by the NFT creator.
  function redeem(address redeemer, NFTVoucher calldata voucher, bytes memory signature) public payable returns (uint256) {
    // make sure signature is valid and get the address of the signer
    address signer = _verify(voucher, signature);

    // make sure that the signer is authorized to mint NFTs
    require(hasRole(MINTER_ROLE, signer), "Signature was not produced by authorized minter");

    // make sure that the redeemer is paying enough to cover the buyer's cost
    require(msg.value >= voucher.minPrice, "Insufficient funds to redeem");

    // first assign the token to the signer, to establish provenance on-chain
    _mint(signer, voucher.tokenId);
    _setTokenURI(voucher.tokenId, voucher.uri);
    
    // transfer to the redeemer
    _transfer(signer, redeemer, voucher.tokenId);

    // send purchase cost to the minter's account. If you want, you can take a % for the platform, etc.
    signer.transfer(msg.value);

    return voucher.tokenId;
  }

  bytes32 constant _voucherSignatureABI = keccak256("NFTVoucher(uint256 tokenId,uint256 minPrice,string uri))");

  function _hash(NFTVoucher calldata voucher) internal view returns (bytes32) {
    return _hashTypedDataV4(keccak256(abi.encode(
      _voucherSignatureABI,
      voucher.tokenId,
      voucher.minPrice,
      bytes(voucher.uri)
    )));
  }

  function _verify(NFTVoucher calldata voucher, bytes memory signature) internal view returns (address) {
    bytes32 digest = _hash(voucher);
    return ECDSA.recover(digest, signature);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override (AccessControl, ERC721) returns (bool) {
    return ERC721.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
  }
}
