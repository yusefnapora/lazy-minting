const ethers = require('ethers')
const { TypedDataUtils } = require('ethers-eip712')


const SIGNING_DOMAIN_NAME = "LazyNFT-Voucher"
const SIGNING_DOMAIN_VERSION = "1"

class LazyMinter {

  constructor({ contractAddress, signer }) {
    this.contractAddress = contractAddress
    this.signer = signer

    this.types = {
      EIP712Domain: [
        {name: "name", type: "string"},
        {name: "version", type: "string"},
        {name: "chainId", type: "uint256"},
        {name: "verifyingContract", type: "address"},
      ],
      NFTVoucher: [
        {name: "tokenId", type: "uint256"},
        {name: "minPrice", type: "uint256"},
        {name: "uri", type: "string"},  
      ]
    }
  }

  async _signingDomain() {
    if (this._domain != null) {
      return this._domain
    }
    const chainId = await this.signer.getChainId()
    this._domain = {
      name: SIGNING_DOMAIN_NAME,
      version: SIGNING_DOMAIN_VERSION,
      verifyingContract: this.contractAddress,
      chainId,
    }
    return this._domain
  }

  async _formatVoucher(voucher) {
    const domain = await this._signingDomain()
    return {
      domain,
      types: this.types,
      primaryType: 'NFTVoucher',
      message: voucher,
    }
  }

  async createVoucher(tokenId, uri, minPrice = 0) {
    const voucher = { tokenId, uri, minPrice }
    const typedData = await this._formatVoucher(voucher)
    const digest = TypedDataUtils.encodeDigest(typedData)
    const signature = await this.signer.signMessage(digest)
    return {
      voucher,
      signature,
      digest,
    }
  }
}

module.exports = {
  LazyMinter
}