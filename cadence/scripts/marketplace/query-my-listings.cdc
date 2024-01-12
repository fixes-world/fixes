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
    addr: Address,
    limit: Int,
    page: Int,
): [ListedItemInfo] {
    let indexer = FRC20Indexer.getIndexer()
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()

    let storefront = FRC20Storefront.borrowStorefront(address: addr)
    if storefront == nil {
        return []
    }

    let listingIds = storefront!.getListingIDs()
    var upTo = (page + 1) * limit
    if upTo > listingIds.length {
        upTo = listingIds.length
    }
    let slicedIds = listingIds.slice(from: page * limit, upTo: upTo)

    let ret: [ListedItemInfo] = []
    for id in slicedIds {
        if let listing = storefront!.borrowListing(id) {
            let details = listing.getDetails()

            let marketAddr = acctsPool.getFRC20MarketAddress(tick: details.tick)
            if marketAddr == nil {
                continue
            }
            let market = FRC20Marketplace.borrowMarket(marketAddr!)
            if market == nil {
                continue
            }
            if let item = market!.getListedItem(type: details.type, rank: details.priceRank(), id: id) {
                ret.append(ListedItemInfo(
                    type: details.type,
                    priceRank: details.priceRank(),
                    rankedIdx: -1,
                    itemInMarket: item,
                    details: details
                ))
            }
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
