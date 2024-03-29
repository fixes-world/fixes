// Third party imports
import "NonFungibleToken"
import "MetadataViews"
// Fixes imports
import "FRC20SemiNFT"
import "FRC20Votes"

access(all)
fun main(
    addr: Address,
    tick: String?,
    page: Int,
    size: Int,
): [StakedNFTInfo] {
    let acct = getAuthAccount(addr)
    // ensure collection exists
    if acct.borrow<&AnyResource>(from: FRC20SemiNFT.CollectionStoragePath) == nil {
        return []
    }

    let ret: [StakedNFTInfo] = []
    let retRef = &ret as &[StakedNFTInfo]
    var startAt = page * size
    var restSize = size

    // Load from staked NFT Collection
    // ensure path correct
    acct.unlink(FRC20SemiNFT.CollectionPublicPath)
    acct.link<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(FRC20SemiNFT.CollectionPublicPath, target: FRC20SemiNFT.CollectionStoragePath)
    // get the collection reference
    if let collection = acct
        .getCapability<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(FRC20SemiNFT.CollectionPublicPath)
        .borrow() {

        let nftIDs = collection.getIDs()
        if startAt < nftIDs.length {
            var endAt = startAt + restSize
            if endAt > nftIDs.length {
                endAt = nftIDs.length
                // size is total items needed to return
                // restSize is the remaining items to return
                // so we need to update restSize to be the remaining items
                restSize = size - (endAt - startAt)
            }
            let sliced = nftIDs.slice(from: startAt, upTo: endAt)
            for id in sliced {
                if let nft = collection.borrowFRC20SemiNFTPublic(id: id) {
                    tryAddStakedNFT(ret: retRef, tick: tick, nft: nft, locked: false)
                }
            }
            // if we are at the end of the list, we need to reset the startAt
            if ret.length <= size {
                startAt = 0
            }
        } else {
            // if we are at the end of the list, we need to reset the startAt
            startAt = startAt - nftIDs.length
        }
    }

    // Load from Voting NFT Collection
    if restSize > 0 {
        if let voter = FRC20Votes.borrowVoterPublic(addr) {
            let nftIDs = voter.getIDs()
            if startAt < nftIDs.length {
                var endAt = startAt + restSize
                if endAt > nftIDs.length {
                    endAt = nftIDs.length
                }
                let sliced = nftIDs.slice(from: startAt, upTo: endAt)
                for id in sliced {
                    if let nft = voter.borrowFRC20SemiNFTPublic(id: id) {
                        tryAddStakedNFT(ret: retRef, tick: tick, nft: nft, locked: true)
                    }
                }
            }
        }
    }
    return ret
}

access(all)
fun tryAddStakedNFT(
    ret: &[StakedNFTInfo],
    tick: String?,
    nft: &FRC20SemiNFT.NFT{FRC20SemiNFT.IFRC20SemiNFT, NonFungibleToken.INFT, MetadataViews.Resolver},
    locked: Bool,
) {
    // skip if not staked
    if nft.isStakedTick() == false {
        return
    }
    // skip if not the tick we want
    if tick != nil && nft.getOriginalTick() != tick! {
        return
    }
    // get the NFT view
    let nftView = MetadataViews.getNFTView(id: nft.id, viewResolver: nft)
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
        isLocked: locked,
    ))
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
    // Locking status
    access(all) let locked: Bool

    init(
        basic: MetadataViews.NFTView,
        tick: String,
        sTick: String,
        balance: UFix64,
        claimingRecords: {String: FRC20SemiNFT.RewardClaimRecord},
        isLocked: Bool,
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
        // Locking status
        self.locked = isLocked
    }
}
