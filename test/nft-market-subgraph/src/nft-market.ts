import {
  Bought as BoughtEvent,
  Listed as ListedEvent,
  WhitelistBought as WhitelistBoughtEvent
} from "../generated/NFTMarket/NFTMarket"
import { Bought, Listed, WhitelistBought, User, NFT, Sale } from "../generated/schema"
import { Address, Bytes, BigInt } from "@graphprotocol/graph-ts"

// 获取或创建用户实体
function getOrCreateUser(address: Address): User {
  let user = User.load(address)
  if (!user) {
    user = new User(address)
    user.save()
  }
  return user
}

// 获取或创建 NFT 实体
function getOrCreateNFT(nftContract: Address, tokenId: BigInt): NFT {
  let id = nftContract.toHexString() + "-" + tokenId.toString()
  let nft = NFT.load(id)
  if (!nft) {
    nft = new NFT(id)
    nft.tokenId = tokenId
    nft.nftContract = nftContract
    nft.save()
  }
  return nft
}

export function handleBought(event: BoughtEvent): void {
  // 创建原始事件记录
  let boughtEntity = new Bought(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  boughtEntity.nft = event.params.nft
  boughtEntity.tokenId = event.params.tokenId
  boughtEntity.buyer = event.params.buyer
  boughtEntity.seller = event.params.seller
  boughtEntity.price = event.params.price
  boughtEntity.blockNumber = event.block.number
  boughtEntity.blockTimestamp = event.block.timestamp
  boughtEntity.transactionHash = event.transaction.hash
  boughtEntity.save()

  // 创建或更新相关实体
  let buyer = getOrCreateUser(event.params.buyer)
  let seller = getOrCreateUser(event.params.seller)
  let nft = getOrCreateNFT(event.params.nft, event.params.tokenId)

  // 创建销售记录
  let sale = new Sale(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  sale.nft = nft.id
  sale.tokenId = event.params.tokenId
  sale.buyer = buyer.id
  sale.seller = seller.id
  sale.price = event.params.price
  sale.saleType = "NORMAL"
  sale.blockNumber = event.block.number
  sale.blockTimestamp = event.block.timestamp
  sale.transactionHash = event.transaction.hash
  sale.save()

  // 查找并更新对应的上架记录
  // 这里简化处理，实际项目中可能需要更复杂的查询逻辑
  // 可以通过 tokenId 和 seller 来查找对应的 Listed 实体并更新其 isActive 状态
}

export function handleListed(event: ListedEvent): void {
  // 创建或更新相关实体
  let seller = getOrCreateUser(event.params.seller)
  let nft = getOrCreateNFT(event.params.nft, event.params.tokenId)

  // 创建上架记录
  let listed = new Listed(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  listed.nft = nft.id
  listed.tokenId = event.params.tokenId
  listed.seller = seller.id
  listed.price = event.params.price
  listed.isActive = true
  listed.blockNumber = event.block.number
  listed.blockTimestamp = event.block.timestamp
  listed.transactionHash = event.transaction.hash
  listed.save()
}

export function handleWhitelistBought(event: WhitelistBoughtEvent): void {
  // 创建原始事件记录
  let whitelistBoughtEntity = new WhitelistBought(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  whitelistBoughtEntity.nft = event.params.nft
  whitelistBoughtEntity.tokenId = event.params.tokenId
  whitelistBoughtEntity.buyer = event.params.buyer
  whitelistBoughtEntity.seller = event.params.seller
  whitelistBoughtEntity.price = event.params.price
  whitelistBoughtEntity.blockNumber = event.block.number
  whitelistBoughtEntity.blockTimestamp = event.block.timestamp
  whitelistBoughtEntity.transactionHash = event.transaction.hash
  whitelistBoughtEntity.save()

  // 创建或更新相关实体
  let buyer = getOrCreateUser(event.params.buyer)
  let seller = getOrCreateUser(event.params.seller)
  let nft = getOrCreateNFT(event.params.nft, event.params.tokenId)

  // 创建销售记录
  let sale = new Sale(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  sale.nft = nft.id
  sale.tokenId = event.params.tokenId
  sale.buyer = buyer.id
  sale.seller = seller.id
  sale.price = event.params.price
  sale.saleType = "WHITELIST"
  sale.blockNumber = event.block.number
  sale.blockTimestamp = event.block.timestamp
  sale.transactionHash = event.transaction.hash
  sale.save()
}
