// Fixes imports
import "FRC20Indexer"
import "FRC20FTShared"
import "FRC20TradingRecord"

access(all)
fun main(addr: Address): TraderStatus {
    if let ref = FRC20TradingRecord.borrowTradingRecords(addr) {
        let totalStatus = ref.getStatus()
        let now = UInt64(getCurrentBlock().timestamp)
        let dailyRef = ref.borrowDailyRecords(now)
        let dailyStatus = dailyRef?.getStatus()
        return TraderStatus(
            address: addr,
            totalSales: totalStatus.sales,
            totalVolume: totalStatus.volume,
            dailySales: dailyStatus?.sales ?? 0,
            dailyVolume: dailyStatus?.volume ?? 0.0,
            points: ref.getTradersPoints(addr),
            points10x: ref.get10xTradersPoints(addr),
            points100x: ref.get100xTradersPoints(addr)
        )
    }
    return TraderStatus(
        address: addr,
        totalSales: 0,
        totalVolume: 0.0,
        dailySales: 0,
        dailyVolume: 0.0,
        points: 0.0,
        points10x: 0.0,
        points100x: 0.0
    )
}

access(all)
struct TraderStatus {
    access(all)
    let address: Address
    access(all)
    let totalSales: UInt64
    access(all)
    let totalVolume: UFix64
    access(all)
    let dailySales: UInt64
    access(all)
    let dailyVolume: UFix64
    access(all)
    let points: UFix64
    access(all)
    let points10x: UFix64
    access(all)
    let points100x: UFix64

    init(
        address: Address,
        totalSales: UInt64,
        totalVolume: UFix64,
        dailySales: UInt64,
        dailyVolume: UFix64,
        points: UFix64,
        points10x: UFix64,
        points100x: UFix64
    ) {
        self.address = address
        self.totalSales = totalSales
        self.totalVolume = totalVolume
        self.dailySales = dailySales
        self.dailyVolume = dailyVolume
        self.points = points
        self.points10x = points10x
        self.points100x = points100x
    }
}
