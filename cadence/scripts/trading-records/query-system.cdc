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
    let clientLoaded = UInt64(page * size)
    var totalLoaded: UInt64 = 0
    var pageInPrevRecord = 0

    // to load yesterday's data if not enough
    var i = 0
    var currentDate = dateToQuery
    let maxRepeat = 30
    while ret.length < size && i < maxRepeat {
        let prevDatetime = currentDate
        if let prevDateData = records!.borrowDailyRecords(prevDatetime) {
            let prevLength = prevDateData.getRecordLength()
            if prevLength > 0 {
                log("Date: ".concat(prevDatetime.toString()).concat(", length: ").concat(prevLength.toString()))
                let needCount = size - ret.length

                var offset = 0
                if clientLoaded > totalLoaded {
                    let loadedDiff: Int = Int(clientLoaded - totalLoaded)
                    if loadedDiff > Int(prevLength) {
                        totalLoaded = totalLoaded + UInt64(prevLength)
                        pageInPrevRecord = (Int(totalLoaded) + needCount - 1) / size
                        currentDate = prevDatetime - 86400
                        i = i + 1
                        continue
                    } else {
                        // load records in this date
                        offset = loadedDiff % size
                        let loadedPageThisDate = loadedDiff / size
                        totalLoaded = totalLoaded + UInt64(loadedPageThisDate * size) + UInt64(offset)
                    }
                }

                let pageToInThisRecord = page - pageInPrevRecord

                // calculate how many records are loaded
                let prevData = prevDateData.getRecords(
                    page: pageToInThisRecord,
                    pageSize: needCount,
                    offset: offset
                )
                if prevData.length > 0 {
                    let upTo = prevData.length < needCount ? prevData.length : needCount
                    ret = ret.concat(prevData.slice(from: 0, upTo: upTo))
                }
                log("totalLoaded: ".concat(totalLoaded.toString()).concat(", clientLoaded: ").concat(clientLoaded.toString()).concat(", prevLength: ").concat(prevLength.toString()).concat(", offset: ").concat(offset.toString()).concat(", needCount: ").concat(needCount.toString()).concat(", loadPage: ").concat(pageToInThisRecord.toString()).concat(", pageInPrevRecord: ").concat(pageInPrevRecord.toString()).concat(", newLoadedLen: ").concat(prevData.length.toString()))
                totalLoaded = totalLoaded + UInt64(prevData.length)
            }
        }
        pageInPrevRecord = Int(totalLoaded) / size
        currentDate = prevDatetime - 86400
        i = i + 1
    }
    log("page: ".concat(page.toString()).concat(", size: ").concat(size.toString()).concat(", loaded: ").concat(totalLoaded.toString()).concat(", return length: ").concat(ret.length.toString()))
    return ret
}
