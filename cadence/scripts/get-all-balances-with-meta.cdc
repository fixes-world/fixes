import "FRC20Indexer"

pub fun main(
    addr: Address
): [BalanceInfo] {
    let indexer = FRC20Indexer.getIndexer()
    let balances = indexer.getBalances(addr: addr)

    let ret: [BalanceInfo] = []
    for tick in balances.keys {
        if let meta = indexer.getTokenMeta(tick: tick) {
            ret.append(BalanceInfo(
                tick: tick,
                balance: balances[tick]!,
                meta: meta
            ))
        }
    }
    return ret
}

pub struct BalanceInfo {
    pub let tick: String
    pub let balance: UFix64
    pub let meta: FRC20Indexer.FRC20Meta

    init(
        tick: String,
        balance: UFix64,
        meta: FRC20Indexer.FRC20Meta
    ) {
        self.tick = tick
        self.balance = balance
        self.meta = meta
    }
}
