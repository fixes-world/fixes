import "Fixes"
import "FixesWrappedNFT"
import "FRC20NFTWrapper"
import "FRC20Indexer"

pub fun main(
    all: Bool
): [Strategy] {
    let indexerAddr = FRC20Indexer.getAddress()
    let indexer = FRC20Indexer.getIndexer()
    let wrapper = FRC20NFTWrapper.borrowWrapperPublic(addr: indexerAddr)
    let list = wrapper.getStrategies(all: all)
    let ret: [Strategy] = []
    for info in list {
        let token = indexer.getTokenMeta(tick: info.tick) ?? panic("token not found")
        ret.append(Strategy(
            info: info,
            meta: token,
            holders: indexer.getHoldersAmount(tick: info.tick),
            pool: indexer.getPoolBalance(tick: info.tick),
        ))
    }
    return ret
}

pub struct Strategy {
    pub let info: FRC20NFTWrapper.FRC20Strategy
    pub let holders: UInt64
    pub let meta: FRC20Indexer.FRC20Meta
    pub let pool: UFix64

    init(
        info: FRC20NFTWrapper.FRC20Strategy,
        meta: FRC20Indexer.FRC20Meta,
        holders: UInt64,
        pool: UFix64,
    ) {
        self.info = info
        self.holders = holders
        self.meta = meta
        self.pool = pool
    }
}
