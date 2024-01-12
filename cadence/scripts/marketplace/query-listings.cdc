// Thirdparty imports
import "MetadataViews"
import "FungibleToken"
import "FlowToken"
// Fixes imports
import "FRC20FTShared"
import "FRC20Indexer"
import "FRC20TradingRecord"
import "FRC20AccountsPool"
import "FRC20Storefront"
import "FRC20Marketplace"
import "FRC20MarketManager"

access(all)
fun main(
    tick: String,
    type: UInt8,
    limit: Int,
    startRank: UInt64?,
    startRankIdxFrom: Int?,
): [ListedItemInfo] {
    let type = FRC20Storefront.ListingType(rawValue: type)
        ?? panic("Invalid listing type")
    let indexer = FRC20Indexer.getIndexer()
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()

    let marketAddr = acctsPool.getFRC20MarketAddress(tick: tick)
        ?? panic("No market for the token")
    let tokenMeta = indexer.getTokenMeta(tick: tick)
        ?? panic("No token meta for the token")
    let market = FRC20Marketplace.borrowMarket(marketAddr)
        ?? panic("No market resource for the token")

    let ret: [ListedItemInfo] = []

    var priceRanks = market.getPriceRanks(type: type)
    // reverse price ranks if sell now
    if type == FRC20Storefront.ListingType.FixedPriceSellNow {
        priceRanks = priceRanks.reverse()
    }
    let startRankIdx = startRank == nil ? 0 : (priceRanks.firstIndex(of: startRank!) ?? 0)

    var rankSliceFromIdx = startRankIdxFrom ?? 0
    var currentIdx = startRankIdx
    var restSize = limit
    while restSize > 0 && currentIdx < priceRanks.length {
        let currentRank = priceRanks[currentIdx]
        let listedIds = market.getListedIds(type: type, rank: currentRank)
        // skip if no more items
        if rankSliceFromIdx >= listedIds.length {
            currentIdx = currentIdx + 1
            rankSliceFromIdx = 0
            continue
        }
        // slice items
        let fromIdx = rankSliceFromIdx
        let sliceSize = restSize < listedIds.length - fromIdx ? restSize : listedIds.length - fromIdx
        let slice = listedIds.slice(from: fromIdx, upTo: fromIdx + sliceSize)
        // add items
        for i, listedId in slice {
            if let item = market.getListedItem(type: type, rank: currentRank, id: listedId) {
                if let details = item.getDetails() {
                    ret.append(ListedItemInfo(
                        type: type,
                        priceRank: currentRank,
                        rankedIdx: fromIdx + i,
                        itemInMarket: item,
                        details: details
                    ))
                }
            }
        }

        restSize = restSize - sliceSize
        if restSize > 0 {
            currentIdx = currentIdx + 1
            rankSliceFromIdx = 0
        }
    }
    return ret
}

access(all) struct ListedItemInfo {
    access(all) let type: FRC20Storefront.ListingType
    access(all) let priceRank: UInt64
    access(all) let rankedIdx: Int
    access(all) let itemInMarket: FRC20Marketplace.ListedItem
    access(all) let details: FRC20Storefront.ListingDetails

    init(
        type: FRC20Storefront.ListingType,
        priceRank: UInt64,
        rankedIdx: Int,
        itemInMarket: FRC20Marketplace.ListedItem,
        details: FRC20Storefront.ListingDetails,
    ) {
        self.type = type
        self.priceRank = priceRank
        self.rankedIdx = rankedIdx
        self.itemInMarket = itemInMarket
        self.details = details
    }
}
