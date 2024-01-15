// Fixes imports
import "FRC20Indexer"
import "FRC20FTShared"
import "FRC20TradingRecord"
import "FRC20AccountsPool"

access(all)
fun main(
    tick: String,
    page: Int,
    size: Int,
): [TraderPointStatus] {
    let indexer = FRC20Indexer.getIndexer()
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    let marketAddr = acctsPool.getFRC20MarketAddress(tick: tick)
        ?? panic("No market for the token")
    let tokenMeta = indexer.getTokenMeta(tick: tick)
        ?? panic("No token meta for the token")
    let marketRecords = FRC20TradingRecord.borrowTradingRecords(marketAddr)
        ?? panic("No market records for the token")

    let traderAddrs = marketRecords.get10xTraders()
    var upTo = (page + 1) * size
    if upTo > traderAddrs.length {
        upTo = traderAddrs.length
    }
    let sliced = traderAddrs.slice(from: page * size, upTo: upTo)
    let ret: [TraderPointStatus] = []
    for addr in sliced {
        ret.append(TraderPointStatus(
           address: addr,
            points: marketRecords.getTradersPoints(addr),
            points10x: marketRecords.get10xTradersPoints(addr),
            points100x: marketRecords.get100xTradersPoints(addr)
        ))
    }
    return ret
}

access(all)
struct TraderPointStatus {
    access(all)
    let address: Address
    access(all)
    let points: UFix64
    access(all)
    let points10x: UFix64
    access(all)
    let points100x: UFix64

    init(
        address: Address,
        points: UFix64,
        points10x: UFix64,
        points100x: UFix64
    ) {
        self.address = address
        self.points = points
        self.points10x = points10x
        self.points100x = points100x
    }
}
