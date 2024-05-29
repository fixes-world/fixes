// Fixes imports
import "Fixes"
import "FRC20FTShared"
import "FRC20TradingRecord"

access(all)
fun main(
    datetime: UInt64?,
    page: Int,
    size: Int,
): [FRC20TradingRecord.TransactionRecord] {
    let records = FRC20TradingRecord.borrowTradingRecords(Fixes.getPlatformAddress())
    if records == nil {
        return []
    }
    let dateToQuery = datetime ?? UInt64(getCurrentBlock().timestamp)

    var ret: [FRC20TradingRecord.TransactionRecord] = []
    var totalLoaded: UInt64 = 0
    if let allData = records!.borrowDailyRecords(dateToQuery) {
        totalLoaded = totalLoaded + allData.getRecordLength()
        ret = allData.getRecords(page: page, pageSize: size)
        // to load yesterday's data if not enough
        var i = 0
        var currentDate = dateToQuery
        let maxRepeat = 30
        while ret.length < size && i < maxRepeat {
            let prevDatetime = currentDate - 86400
            if let prevDateData = records!.borrowDailyRecords(prevDatetime) {
                let prevLength = prevDateData.getRecordLength()
                if prevLength > 0 {
                    // calculate how many records are loaded
                    let needCount = size - ret.length
                    let prevPage = (page - (Int(totalLoaded) + needCount) / size)
                    let prevData: [FRC20TradingRecord.TransactionRecord] = prevDateData.getRecords(page: prevPage, pageSize: needCount)
                    if prevData.length > 0 {
                        let upTo = prevData.length < needCount ? prevData.length : needCount
                        ret = ret.concat(prevData.slice(from: 0, upTo: upTo))
                    }
                    totalLoaded = totalLoaded + UInt64(prevData.length)
                }
            }
            currentDate = prevDatetime
            i = i + 1
        }
    }
    return ret
}
