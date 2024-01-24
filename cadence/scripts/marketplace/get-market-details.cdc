// Fixes imports
import "FRC20Indexer"
import "FRC20FTShared"
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
    var ceilingPriceSellListing = 0.0

    let buyPriceRanks = market.getPriceRanks(type: FRC20Storefront.ListingType.FixedPriceBuyNow)
    if buyPriceRanks.length > 0 {
        // let len = buyPriceRanks.length - 1
        // let limit = len > 10 ? 10 : len
        var i = 0
        // while i < limit {
            let floorPriceRank = buyPriceRanks[i]
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
                // break
            }
        //     i = i + 1
        // }
    }
    let sellPriceRanks = market.getPriceRanks(type: FRC20Storefront.ListingType.FixedPriceSellNow)
    if sellPriceRanks.length > 0 {
        // let len = sellPriceRanks.length - 1
        // let limit = len > 10 ? 10 : len
        var i = 0
        // while i < limit {
            let ceilingPriceRank = sellPriceRanks[sellPriceRanks.length - 1 - i]
            let listIds = market.getListedIds(type: FRC20Storefront.ListingType.FixedPriceSellNow, rank: ceilingPriceRank)
            if listIds.length > 0 {
                if let listing = market.getListedItem(
                    type: FRC20Storefront.ListingType.FixedPriceSellNow,
                    rank: ceilingPriceRank,
                    id: listIds[0]
                ) {
                    if let details = listing.getDetails() {
                        ceilingPriceSellListing = details.pricePerToken()
                    }
                }
            //     break
            }
            // i = i + 1
        // }
    }

    let sharedSotre = FRC20FTShared.borrowStoreRef(marketAddr)
        ?? panic("No shared store for the token")
    let properties: {UInt8: String} = {}
    properties[FRC20FTShared.ConfigType.MarketAccessibleAfter.rawValue] = (market.accessibleAfter() ?? 0).toString()
    let claimableTokens = market.whitelistClaimingConditions()
    for token in claimableTokens.keys {
        properties[FRC20FTShared.ConfigType.MarketWhitelistClaimingToken.rawValue] = token
        properties[FRC20FTShared.ConfigType.MarketWhitelistClaimingAmount.rawValue] = claimableTokens[token]!.toString()
        break
    }
    properties[FRC20FTShared.ConfigType.MarketFeeSharedRatio.rawValue] = (sharedSotre.getByEnum(FRC20FTShared.ConfigType.MarketFeeSharedRatio) as! UFix64? ?? 0.0).toString()
    properties[FRC20FTShared.ConfigType.MarketFeeTokenSpecificRatio.rawValue] = (sharedSotre.getByEnum(FRC20FTShared.ConfigType.MarketFeeTokenSpecificRatio) as! UFix64? ?? 0.0).toString()
    properties[FRC20FTShared.ConfigType.MarketFeeDeployerRatio.rawValue] = (sharedSotre.getByEnum(FRC20FTShared.ConfigType.MarketFeeDeployerRatio) as! UFix64? ?? 0.0).toString()

    // staking info
    let stakingAddr = acctsPool.getFRC20StakingAddress(tick: tick)

    return TokenMarketDetailed(
        meta: tokenMeta,
        holders: indexer.getHoldersAmount(tick: tick),
        pool: indexer.getPoolBalance(tick: tick),
        stakable: stakingAddr != nil,
        stakingAddr: stakingAddr,
        volume24h: todayStatus?.volume ?? 0.0,
        sales24h: todayStatus?.sales ?? 0,
        volumeTotal: totalStatus.volume,
        salesTotal: totalStatus.sales,
        marketCap: marketRecords.getMarketCap() ?? 0.0,
        listedAmount: market.getListedAmount(),
        address: marketAddr,
        // detailed info
        floorPriceBuyListing: floorPriceBuyListing,
        ceilingPriceSellListing: ceilingPriceSellListing,
        floorPriceDeal: totalStatus.dealFloorPricePerToken,
        ceilingPriceDeal: totalStatus.dealCeilingPricePerToken,
        properties: properties,
        // for the address
        accessible: market.isAccessible() || (addr != nil ? market.canAccess(addr: addr!) : false),
        isValidToClaimAccess: addr != nil ? market.isValidToClaimAccess(addr: addr!) : nil
    )
}


access(all)
struct TokenMarketDetailed {
    // TokenMeta
    access(all) let meta: FRC20Indexer.FRC20Meta
    access(all) let holders: UInt64
    access(all) let pool: UFix64
    access(all) let stakable: Bool
    access(all) let stakingAddr: Address?
    // MarketStatus
    access(all) let volume24h: UFix64
    access(all) let sales24h: UInt64
    access(all) let volumeTotal: UFix64
    access(all) let salesTotal: UInt64
    access(all) let marketCap: UFix64
    access(all) let listedAmount: UInt64
    access(all) let address: Address
    // detailed info
    access(all) let floorPriceBuyListing: UFix64
    access(all) let ceilingPriceSellListing: UFix64
    access(all) let floorPriceDeal: UFix64
    access(all) let ceilingPriceDeal: UFix64
    access(all) let properties: {UInt8: String}
    // for the address
    access(all) let accessible: Bool
    access(all) let isValidToClaimAccess: Bool?

    init(
        meta: FRC20Indexer.FRC20Meta,
        holders: UInt64,
        pool: UFix64,
        stakable: Bool,
        stakingAddr: Address?,
        volume24h: UFix64,
        sales24h: UInt64,
        volumeTotal: UFix64,
        salesTotal: UInt64,
        marketCap: UFix64,
        listedAmount: UInt64,
        address: Address,
        floorPriceBuyListing: UFix64,
        ceilingPriceSellListing: UFix64,
        floorPriceDeal: UFix64,
        ceilingPriceDeal: UFix64,
        properties: {UInt8: String},
        accessible: Bool,
        isValidToClaimAccess: Bool?
    ) {
        self.meta = meta
        self.holders = holders
        self.pool = pool
        self.stakable = stakable
        self.stakingAddr = stakingAddr
        self.volume24h = volume24h
        self.sales24h = sales24h
        self.volumeTotal = volumeTotal
        self.salesTotal = salesTotal
        self.marketCap = marketCap
        self.listedAmount = listedAmount
        self.address = address
        self.floorPriceBuyListing = floorPriceBuyListing
        self.ceilingPriceSellListing = ceilingPriceSellListing
        self.floorPriceDeal = floorPriceDeal
        self.ceilingPriceDeal = ceilingPriceDeal
        self.properties = properties
        self.accessible = accessible
        self.isValidToClaimAccess = isValidToClaimAccess
    }
}
