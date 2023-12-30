import "MetadataViews"
import "Fixes"
import "FixesWrappedNFT"
import "FRC20NFTWrapper"
import "FRC20Indexer"

pub fun main(
    all: Bool
): [Strategy] {
    let wrapperIndexer = FRC20NFTWrapper.borrowWrapperIndexerPublic()
    let frc20Indexer = FRC20Indexer.getIndexer()
    let allWrapper = wrapperIndexer.getAllWrappers(false, true)

    let ret: [Strategy] = []

    for wrapperAddr in allWrapper {
        if let wrapper = FRC20NFTWrapper.borrowWrapperPublic(addr: wrapperAddr) {
            let list = wrapper.getStrategies(all: all)
            for info in list {
                let token = frc20Indexer.getTokenMeta(tick: info.tick) ?? panic("token not found")
                ret.append(Strategy(
                    host: wrapperAddr,
                    info: info,
                    meta: token,
                    holders: frc20Indexer.getHoldersAmount(tick: info.tick),
                    pool: frc20Indexer.getPoolBalance(tick: info.tick),
                    collectionDisplay: wrapperIndexer.getNFTCollectionDisplay(nftType: info.nftType)
                ))
            }
        }
    }
    return ret
}

pub struct Strategy {
    pub let host: Address
    pub let info: FRC20NFTWrapper.FRC20Strategy
    pub let holders: UInt64
    pub let meta: FRC20Indexer.FRC20Meta
    pub let pool: UFix64
    pub let collectionDisplay: MetadataViews.NFTCollectionDisplay

    init(
        host: Address,
        info: FRC20NFTWrapper.FRC20Strategy,
        meta: FRC20Indexer.FRC20Meta,
        holders: UInt64,
        pool: UFix64,
        collectionDisplay: MetadataViews.NFTCollectionDisplay
    ) {
        self.host = host
        self.info = info
        self.holders = holders
        self.meta = meta
        self.pool = pool
        self.collectionDisplay = collectionDisplay
    }
}
