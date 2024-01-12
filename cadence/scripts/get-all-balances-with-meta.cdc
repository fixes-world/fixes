import "FRC20Indexer"

access(all)
fun main(
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
                meta: meta,
                holders: indexer.getHoldersAmount(tick: tick),
                pool: indexer.getPoolBalance(tick: tick),
            ))
        }
    }
    return ret
}

access(all) struct BalanceInfo {
    access(all) let tick: String
    access(all) let balance: UFix64
    access(all) let meta: FRC20Indexer.FRC20Meta
    access(all) let holders: UInt64
    access(all) let pool: UFix64

    init(
        tick: String,
        balance: UFix64,
        meta: FRC20Indexer.FRC20Meta,
        holders: UInt64,
        pool: UFix64
    ) {
        self.tick = tick
        self.balance = balance
        self.meta = meta
        self.holders = holders
        self.pool = pool
    }
}
