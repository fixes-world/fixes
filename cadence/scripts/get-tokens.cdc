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
                holders: indexer.getHoldersAmount(tick: tick),
                meta: meta
            ))
        }
    }
    return ret
}

pub struct FRC20Info {
    pub let holders: UInt64
    pub let meta: FRC20Indexer.FRC20Meta

    init(
        holders: UInt64,
        meta: FRC20Indexer.FRC20Meta
    ) {
        self.holders = holders
        self.meta = meta
    }
}
