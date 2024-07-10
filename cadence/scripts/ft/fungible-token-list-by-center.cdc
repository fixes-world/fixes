// Fixes Imports
import "FixesTradablePool"
import "FungibleTokenManager"

/// Parameters
/// filter: UInt8 - 0: trending, 1: new, 2: finalized
access(all)
fun main(
    _ filter: UInt8,
    _ page: Int?,
    _ size: Int?
): [FungibleTokenManager.FixesTokenInfo] {
    let tradingCenter = FixesTradablePool.borrowTradingCenter()
    let arr: [FungibleTokenManager.FixesTokenInfo] = []

    let currPage = page ?? 0
    let currSize = size ?? 50

    var pools: [FixesTradablePool.AddressWithScore] = []
    if filter == 0 {
        pools = tradingCenter.getTopTrendingPools()
    } else if filter == 1 {
        pools = tradingCenter.queryLatestPools(page: currPage, size: currSize)
    } else if filter == 2 {
        pools = tradingCenter.queryLatestHandoveredPools(page: currPage, size: currSize)
    }

    for one in pools {
        if let info = FungibleTokenManager.buildFixesTokenInfo(one.address, nil) {
            arr.append(info)
        }
    }
    return arr
}
