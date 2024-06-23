// Fixes imports
import "FRC20Indexer"
import "FRC20FTShared"
import "FRC20TradingRecord"
import "FRC20AccountsPool"
import "FRC20Storefront"
import "FRC20Marketplace"

access(all)
fun main(
    address: Address,
    datetime: UInt64?,
    page: Int,
    size: Int,
): [FRC20TradingRecord.TransactionRecord] {
    let indexer = FRC20Indexer.getIndexer()
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    let records = FRC20TradingRecord.borrowTradingRecords(address)

    if records == nil {
        return []
    }

    let dateToQuery = datetime ?? UInt64(getCurrentBlock().timestamp)

    var ret: [FRC20TradingRecord.TransactionRecord] = []
    let clientLoaded = UInt64(page * size)
    var totalLoaded: UInt64 = 0

    // to load yesterday's data if not enough
    var i = 0
    var currentDate = dateToQuery
    let maxRepeat = 30
    while ret.length < size && i < maxRepeat {
        let prevDatetime = currentDate
        if let prevDateData = records!.borrowDailyRecords(prevDatetime) {
            let prevLength = prevDateData.getRecordLength()
            if prevLength > 0 {
                var offset = 0
                if clientLoaded > totalLoaded {
                    if clientLoaded - totalLoaded > prevLength {
                        totalLoaded = totalLoaded + UInt64(prevLength)
                        currentDate = prevDatetime - 86400
                        i = i + 1
                        continue
                    } else {
                        offset = Int(clientLoaded - totalLoaded)
                    }
                }
                // calculate how many records are loaded
                let needCount = size - ret.length
                let prevPage = (page - (Int(totalLoaded) + needCount - 1) / size)
                let prevData = prevDateData.getRecords(page: prevPage, pageSize: needCount, offset: offset)
                if prevData.length > 0 {
                    let upTo = prevData.length < needCount ? prevData.length : needCount
                    ret = ret.concat(prevData.slice(from: 0, upTo: upTo))
                }
                totalLoaded = totalLoaded + UInt64(prevData.length)
            }
        }
        currentDate = prevDatetime - 86400
        i = i + 1
    }
    log("page: ".concat(page.toString()).concat(", size: ").concat(size.toString()).concat(", loaded: ").concat(totalLoaded.toString()))
    return ret
}
