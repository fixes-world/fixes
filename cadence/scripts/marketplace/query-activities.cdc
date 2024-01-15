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
        let todayLen = allData.getRecordLength()
        ret = allData.getRecords(page: page, pageSize: size)
        // to load yesterday's data if not enough
        if ret.length < size {
            let prevDatetime = dateToQuery - 86400
            if let prevDateData = marketRecords.borrowDailyRecords(prevDatetime) {
                let prevLength = prevDateData.getRecordLength()
                if prevLength > 0 {
                    // calculate how many records are loaded
                    let loadedCount = page * size
                    let needCount = size - ret.length
                    let prevPage = (page - (Int(todayLen) + needCount) / size)
                    let prevData: [FRC20TradingRecord.TransactionRecord] = prevDateData.getRecords(page: prevPage, pageSize: size)
                    if prevData.length > 0 {
                        let upTo = prevData.length < needCount ? prevData.length : needCount
                        ret = ret.concat(prevData.slice(from: 0, upTo: upTo))
                    }
                }
            }
        }
    }
    return ret
}
