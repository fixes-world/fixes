// Third party imports
import "NonFungibleToken"
import "MetadataViews"
// Fixes imports
// import "FRC20Indexer"
// import "FRC20FTShared"
// import "FRC20AccountsPool"
// import "FRC20Staking"
// import "FRC20StakingManager"
import "FRC20SemiNFT"

access(all)
fun main(
    addr: Address,
    tick: String?,
    page: Int,
    size: Int,
): [StakedNFTInfo] {
    if let collection = getAccount(addr)
        .getCapability<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(FRC20SemiNFT.CollectionPublicPath)
        .borrow() {

        let nftIDs = collection.getIDs()
        var startAt = page * size
        if startAt >= nftIDs.length {
            return []
        }
        let sliced = nftIDs.slice(from: startAt, upTo: nftIDs.length)
        let ret: [StakedNFTInfo] = []
        for id in sliced {
            if let nft = collection.borrowFRC20SemiNFTPublic(id: id) {
                // skip if not staked
                if nft.isStakedTick() == false {
                    continue
                }
                // skip if not the tick we want
                if tick != nil && nft.getOriginalTick() != tick! {
                    continue
                }
                // get the NFT view
                let nftView = MetadataViews.getNFTView(id: id, viewResolver: nft)
                let balance = nft.getBalance()
                let rewardNames = nft.getRewardStrategies()
                let claimingRecords: {String: FRC20SemiNFT.RewardClaimRecord} = {}
                for name in rewardNames {
                    claimingRecords[name] = nft.getClaimingRecord(name)!
                }
                ret.append(StakedNFTInfo(
                    basic: nftView,
                    tick: nft.getOriginalTick(),
                    sTick: nft.getTickerName(),
                    balance: nft.getBalance(),
                    claimingRecords: claimingRecords,
                ))
                // break if we have enough
                if ret.length >= size {
                    break
                }
            }
        }
        return ret
    }
    return []
}

access(all) struct StakedNFTInfo {
    // NFT data
    access(all) let id: UInt64
    access(all) let uuid: UInt64
    access(all) let display: MetadataViews.Display?
    access(all) let externalURL: MetadataViews.ExternalURL?
    access(all) let traits: [MetadataViews.Trait]
    // semiNFT data
    access(all) let tick: String
    access(all) let sTick: String
    access(all) let balance: UFix64
    access(all) let claimingRecords: {String: FRC20SemiNFT.RewardClaimRecord}

    init(
        basic: MetadataViews.NFTView,
        tick: String,
        sTick: String,
        balance: UFix64,
        claimingRecords: {String: FRC20SemiNFT.RewardClaimRecord},
    ) {
        // NFT data
        self.id = basic.id
        self.uuid = basic.uuid
        self.display = basic.display
        self.externalURL = basic.externalURL
        self.traits = basic.traits?.traits ?? []
        // semiNFT data
        self.tick = tick
        self.sTick = sTick
        self.balance = balance
        self.claimingRecords = claimingRecords
    }
}
