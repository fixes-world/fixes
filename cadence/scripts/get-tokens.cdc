import "FRC20Indexer"

pub fun main(
    page: Int,
    size: Int
): [FRC20Info] {
    let indexer = FRC20Indexer.getIndexer()
    let tokens = indexer.getTokens()

    let len = tokens.length
    let startFrom = page * size
    let endAt = len > startFrom + size ? startFrom + size : len
    let slicedTokens = tokens.slice(from: startFrom, upTo: endAt)

    let ret: [FRC20Info] = []
    for tick in slicedTokens {
        if let meta = indexer.getTokenMeta(tick: tick) {
            ret.append(FRC20Info(
                meta: meta,
                holders: indexer.getHoldersAmount(tick: tick),
                pool: indexer.getPoolBalance(tick: tick),
            ))
        }
    }
    return ret
}

pub struct FRC20Info {
    pub let meta: FRC20Indexer.FRC20Meta
    pub let holders: UInt64
    pub let pool: UFix64

    init(
        meta: FRC20Indexer.FRC20Meta,
        holders: UInt64,
        pool: UFix64,
    ) {
        self.holders = holders
        self.meta = meta
        self.pool = pool
    }
}
