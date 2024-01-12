// Fixes imports
import "FRC20Indexer"
import "FRC20FTShared"
import "FRC20TradingRecord"
import "FRC20AccountsPool"
import "FRC20Storefront"
import "FRC20Marketplace"

access(all)
fun main(
    tick: String,
    datetime: UInt64?,
    page: Int,
    size: Int,
): [FRC20TradingRecord.TransactionRecord] {
    let indexer = FRC20Indexer.getIndexer()
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    let marketAddr = acctsPool.getFRC20MarketAddress(tick: tick)
        ?? panic("No market for the token")
    let tokenMeta = indexer.getTokenMeta(tick: tick)
        ?? panic("No token meta for the token")
    let market = FRC20Marketplace.borrowMarket(marketAddr)
        ?? panic("No market resource for the token")
    let marketRecords = FRC20TradingRecord.borrowTradingRecords(marketAddr)
        ?? panic("No market records for the token")

    let dateToQuery = datetime ?? UInt64(getCurrentBlock().timestamp)

    var ret: [FRC20TradingRecord.TransactionRecord] = []
    if let allData = marketRecords.borrowDailyRecords(dateToQuery) {
        ret = allData.getRecords(page: page, pageSize: size)
    }
    return ret
}
