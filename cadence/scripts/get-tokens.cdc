import "FRC20Indexer"
import "FRC20AccountsPool"

access(all)
fun main(
    page: Int,
    size: Int
): [FRC20Info] {
    let indexer = FRC20Indexer.getIndexer()
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    let tokens = indexer.getTokens()

    let len = tokens.length
    let startFrom = page * size
    let endAt = len > startFrom + size ? startFrom + size : len
    let slicedTokens = tokens.slice(from: startFrom, upTo: endAt)

    let ret: [FRC20Info] = []
    for tick in slicedTokens {
        if let meta = indexer.getTokenMeta(tick: tick) {
            let stakingAddr = acctsPool.getFRC20StakingAddress(tick: tick)
            ret.append(FRC20Info(
                meta: meta,
                holders: indexer.getHoldersAmount(tick: tick),
                pool: indexer.getPoolBalance(tick: tick),
                stakable: stakingAddr != nil,
                stakingAddr: stakingAddr,
            ))
        }
    }
    return ret
}

access(all) struct FRC20Info {
    access(all) let holders: UInt64
    access(all) let meta: FRC20Indexer.FRC20Meta
    access(all) let pool: UFix64
    access(all) let stakable: Bool
    access(all) let stakingAddr: Address?

    init(
        meta: FRC20Indexer.FRC20Meta,
        holders: UInt64,
        pool: UFix64,
        stakable: Bool,
        stakingAddr: Address?,
    ) {
        self.holders = holders
        self.meta = meta
        self.pool = pool
        self.stakable = stakable
        self.stakingAddr = stakingAddr
    }
}
