import "FRC20Staking"
import "FRC20AccountsPool"
import "FRC20Marketplace"
import "FRC20Storefront"
import "FRC20Indexer"

access(all)
fun main(): UFix64 {
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    let stakingTokens = acctsPool.getAddresses(type: FRC20AccountsPool.ChildAccountType.Staking)

    var totalTVL = 0.0
    let ticks = stakingTokens.keys

    for tick in ticks {
        let stakingAddr = stakingTokens[tick]!
        let stakingPool = FRC20Staking.borrowPool(stakingAddr)
        if stakingPool == nil {
            continue
        }

        let indexer = FRC20Indexer.getIndexer()
        // calculate floor price
        let benchmarkPrice = indexer.getBenchmarkValue(tick: tick)
        var floorPrice = benchmarkPrice

        if let marketAddr = acctsPool.getFRC20MarketAddress(tick: tick) {
            if let market = FRC20Marketplace.borrowMarket(marketAddr) {
                let buyPriceRanks = market.getPriceRanks(type: FRC20Storefront.ListingType.FixedPriceBuyNow)
                if buyPriceRanks.length > 0 {
                    var i = 0
                    let floorPriceRank = buyPriceRanks[i]
                    let listIds = market.getListedIds(type: FRC20Storefront.ListingType.FixedPriceBuyNow, rank: floorPriceRank)
                    if listIds.length > 0 {
                        if let listing = market.getListedItem(
                            type: FRC20Storefront.ListingType.FixedPriceBuyNow,
                            rank: floorPriceRank,
                            id: listIds[0]
                        ) {
                            if let details = listing.getDetails() {
                                floorPrice = details.pricePerToken()
                            }
                        }
                    }
                }
            }
        } // end if

        var details = stakingPool!.getDetails()
        let validStaked = details.totalStaked - details.totalUnstakingLocked

        totalTVL = totalTVL + (validStaked * (floorPrice - benchmarkPrice))
    }
    return totalTVL
}
