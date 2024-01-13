// Fixes imports
import "FRC20TradingRecord"
import "FRC20AccountsPool"

access(all)
fun main(
    tick: String,
    page: Int,
    size: Int
): [TraderPoints] {
    let acctPools = FRC20AccountsPool.borrowAccountsPool()
    if let marketAddr = acctPools.getFRC20MarketAddress(tick: tick) {
        if let ref = FRC20TradingRecord.borrowTradingRecords(marketAddr) {
            let traders = ref.getTraders()
            let len = traders.length
            var start = page * size
            if start >= len {
                return []
            }
            var end = (page + 1) * size
            if end > len {
                end = len
            }
            let ret: [TraderPoints] = []
            let sliced = traders.slice(from: start, upTo: end)
            for addr in sliced {
                ret.append(TraderPoints(
                    address: addr,
                    points: ref.getTradersPoints(addr),
                    points10x: ref.get10xTradersPoints(addr),
                    points100x: ref.get100xTradersPoints(addr)
                ))
            }
            return ret
        }
    }
    return []
}

access(all)
struct TraderPoints {
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
