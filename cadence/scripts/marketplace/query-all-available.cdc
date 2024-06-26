// Fixes imports
import "FRC20Indexer"
import "FRC20TradingRecord"
import "FRC20AccountsPool"
import "FRC20Marketplace"

access(all)
fun main():[TokenMarketInfo] {
    let indexer = FRC20Indexer.getIndexer()
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    let addrsDict = acctsPool.getAddresses(type: FRC20AccountsPool.ChildAccountType.Market)

    let now = getCurrentBlock().timestamp

    let ret: [TokenMarketInfo] = []
    for tick in addrsDict.keys {
        if let tokenMeta = indexer.getTokenMeta(tick: tick) {
            let marketAddr = addrsDict[tick]!
            let market = FRC20Marketplace.borrowMarket(marketAddr)
            let marketRecords = FRC20TradingRecord.borrowTradingRecords(marketAddr)
            if market == nil || marketRecords == nil {
                continue
            }

            var todayStatus: FRC20TradingRecord.TradingStatus? = nil
            if let todayRecords = marketRecords!.borrowDailyRecords(UInt64(now)) {
                todayStatus = todayRecords.getStatus()
            }
            let totalStatus = marketRecords!.getStatus()

            // staking info
            let stakingAddr = acctsPool.getFRC20StakingAddress(tick: tick)

            ret.append(TokenMarketInfo(
                meta: tokenMeta,
                holders: indexer.getHoldersAmount(tick: tick),
                pool: indexer.getPoolBalance(tick: tick),
                stakable: stakingAddr != nil,
                stakingAddr: stakingAddr,
                marketEnabled: acctsPool.getFRC20MarketAddress(tick: tick) != nil,
                volume24h: todayStatus?.volume ?? 0.0,
                sales24h: todayStatus?.sales ?? 0,
                volumeTotal: totalStatus.volume,
                salesTotal: totalStatus.sales,
                listedAmount: market!.getListedAmount(),
                address: marketAddr,
            ))
        }
    }
    return ret
}

access(all)
struct TokenMarketInfo {
    // Token Meta
    access(all) let meta: FRC20Indexer.FRC20Meta
    access(all) let holders: UInt64
    access(all) let pool: UFix64
    access(all) let stakable: Bool
    access(all) let stakingAddr: Address?
    access(all) let marketEnabled: Bool
    // Market status
    access(all) let volume24h: UFix64
    access(all) let sales24h: UInt64
    access(all) let volumeTotal: UFix64
    access(all) let salesTotal: UInt64
    access(all) let listedAmount: UInt64
    access(all) let address: Address

    init(
        meta: FRC20Indexer.FRC20Meta,
        holders: UInt64,
        pool: UFix64,
        stakable: Bool,
        stakingAddr: Address?,
        marketEnabled: Bool,
        volume24h: UFix64,
        sales24h: UInt64,
        volumeTotal: UFix64,
        salesTotal: UInt64,
        listedAmount: UInt64,
        address: Address
    ) {
        self.meta = meta
        self.holders = holders
        self.pool = pool
        self.stakable = stakable
        self.stakingAddr = stakingAddr
        self.marketEnabled = marketEnabled
        self.volume24h = volume24h
        self.sales24h = sales24h
        self.volumeTotal = volumeTotal
        self.salesTotal = salesTotal
        self.listedAmount = listedAmount
        self.address = address
    }
}
