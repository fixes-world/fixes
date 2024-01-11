// Fixes imports
import "FRC20Indexer"
import "FRC20TradingRecord"
import "FRC20AccountsPool"
import "FRC20Storefront"
import "FRC20Marketplace"

access(all)
fun main(
    tick: String,
    addr: Address?
): TokenMarketDetailed {
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

    let now = getCurrentBlock().timestamp
    var todayStatus: FRC20TradingRecord.TradingStatus? = nil
    if let todayRecords = marketRecords.borrowDailyRecords(UInt64(now)) {
        todayStatus = todayRecords.getStatus()
    }
    let totalStatus = marketRecords.getStatus()

    // calculate floor price
    var floorPriceBuyListing = 0.0
    var floorPriceSellListing = 0.0

    let buyPriceRanks = market.getPriceRanks(type: FRC20Storefront.ListingType.FixedPriceBuyNow)
    if buyPriceRanks.length > 0 {
        let floorPriceRank = buyPriceRanks[0]
        let listIds = market.getListedIds(type: FRC20Storefront.ListingType.FixedPriceBuyNow, rank: floorPriceRank)
        if listIds.length > 0 {
            if let listing = market.getListedItem(
                type: FRC20Storefront.ListingType.FixedPriceBuyNow,
                rank: floorPriceRank,
                id: listIds[0]
            ) {
                if let details = listing.getDetails() {
                    floorPriceBuyListing = details.pricePerToken()
                }
            }
        }
    }
    let sellPriceRanks = market.getPriceRanks(type: FRC20Storefront.ListingType.FixedPriceSellNow)
    if sellPriceRanks.length > 0 {
        let floorPriceRank = sellPriceRanks[0]
        let listIds = market.getListedIds(type: FRC20Storefront.ListingType.FixedPriceSellNow, rank: floorPriceRank)
        if listIds.length > 0 {
            if let listing = market.getListedItem(
                type: FRC20Storefront.ListingType.FixedPriceSellNow,
                rank: floorPriceRank,
                id: listIds[0]
            ) {
                if let details = listing.getDetails() {
                    floorPriceSellListing = details.pricePerToken()
                }
            }
        }
    }

    return TokenMarketDetailed(
        meta: tokenMeta,
        holders: indexer.getHoldersAmount(tick: tick),
        pool: indexer.getPoolBalance(tick: tick),
        volume24h: todayStatus?.volume ?? 0.0,
        sales24h: todayStatus?.sales ?? 0,
        volumeTotal: totalStatus.volume,
        salesTotal: totalStatus.sales,
        marketCap: marketRecords.getMarketCap() ?? 0.0,
        listedAmount: market.getListedAmount(),
        // detailed info
        floorPriceBuyListing: floorPriceBuyListing,
        floorPriceSellListing: floorPriceSellListing,
        floorPriceDeal: totalStatus.dealFloorPricePerToken,
        ceilingPriceDeal: totalStatus.dealCeilingPricePerToken,
        properties: {},
        // for the address
        accessible: addr != nil ? market.canAccess(addr: addr!) : nil
    )
}


access(all)
struct TokenMarketDetailed {
    access(all) let meta: FRC20Indexer.FRC20Meta
    access(all) let holders: UInt64
    access(all) let pool: UFix64
    access(all) let volume24h: UFix64
    access(all) let sales24h: UInt64
    access(all) let volumeTotal: UFix64
    access(all) let salesTotal: UInt64
    access(all) let marketCap: UFix64
    access(all) let listedAmount: UInt64
    // detailed info
    access(all) let floorPriceBuyListing: UFix64
    access(all) let floorPriceSellListing: UFix64
    access(all) let floorPriceDeal: UFix64
    access(all) let ceilingPriceDeal: UFix64
    access(all) let properties: {UInt8: String}
    // for the address
    access(all) let accessible: Bool?

    init(
        meta: FRC20Indexer.FRC20Meta,
        holders: UInt64,
        pool: UFix64,
        volume24h: UFix64,
        sales24h: UInt64,
        volumeTotal: UFix64,
        salesTotal: UInt64,
        marketCap: UFix64,
        listedAmount: UInt64,
        floorPriceBuyListing: UFix64,
        floorPriceSellListing: UFix64,
        floorPriceDeal: UFix64,
        ceilingPriceDeal: UFix64,
        properties: {UInt8: String},
        accessible: Bool?
    ) {
        self.meta = meta
        self.holders = holders
        self.pool = pool
        self.volume24h = volume24h
        self.sales24h = sales24h
        self.volumeTotal = volumeTotal
        self.salesTotal = salesTotal
        self.marketCap = marketCap
        self.listedAmount = listedAmount
        self.floorPriceBuyListing = floorPriceBuyListing
        self.floorPriceSellListing = floorPriceSellListing
        self.floorPriceDeal = floorPriceDeal
        self.ceilingPriceDeal = ceilingPriceDeal
        self.properties = properties
        self.accessible = accessible
    }
}
