// Fixes imports
import "FRC20Indexer"
import "FRC20FTShared"
import "FRC20AccountsPool"
import "FRC20Votes"
import "FRC20Staking"
import "FRC20StakingManager"
import "FRC20Marketplace"
import "FRC20Storefront"

access(all)
fun main(
    tick: String,
    addr: Address?
): StakingDetails {
    let now = getCurrentBlock().timestamp

    let indexer = FRC20Indexer.getIndexer()
    let tokenMeta = indexer.getTokenMeta(tick: tick)
        ?? panic("No token meta for the token")

    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    // staking info
    let stakingAddr = acctsPool.getFRC20StakingAddress(tick: tick)
        ?? panic("No staking address for the token".concat(tick))
    let stakingPool = FRC20Staking.borrowPool(stakingAddr)
        ?? panic("No staking pool for the token".concat(tick))

    // calculate floor price
    var floorPriceBuyListing = 0.0

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
                            floorPriceBuyListing = details.pricePerToken()
                        }
                    }
                }
            }
        }
    } // end if

    var totalLockedStakedBalance: UFix64 = 0.0
    var totalStakedBalance: UFix64 = 0.0
    var totalUnstakingBalance: UFix64 = 0.0
    var totalUnlockedClaimableBalance: UFix64 = 0.0
    // delegator ref
    if addr != nil {
        if let delegatorRef = FRC20Staking.borrowDelegator(addr!) {
            totalStakedBalance = delegatorRef.getStakedBalance(tick: tick)
            if let unstakingRecord = stakingPool.getDelegatorUnstakingInfo(addr!) {
                totalUnstakingBalance = unstakingRecord.totalUnstakingBalance
                totalUnlockedClaimableBalance = unstakingRecord.totalUnlockedClaimableBalance
            }
        }
        if let voter = FRC20Votes.borrowVoterPublic(addr!) {
            totalLockedStakedBalance = voter.getStakedBalance(tick: tick)
        }
    } // update delegator info

    return StakingDetails(
        meta: tokenMeta,
        holders: indexer.getHoldersAmount(tick: tick),
        pool: indexer.getPoolBalance(tick: tick),
        stakable: stakingAddr != nil,
        stakingAddr: stakingAddr,
        marketEnabled: acctsPool.getFRC20MarketAddress(tick: tick) != nil,
        // Staking Status
        details: stakingPool.getDetails(),
        floorPriceBuyListing: floorPriceBuyListing,
        // for the address
        isEligibleForRegistering: addr != nil
            ? FRC20StakingManager.isEligibleForRegistering(stakeTick: tick, addr: addr!)
            : false,
        totalStakedBalance: totalStakedBalance,
        totalUnstakingBalance: totalUnstakingBalance,
        totalUnlockedClaimableBalance: totalUnlockedClaimableBalance,
        totalLockedStakedBalance: totalLockedStakedBalance,
    )
}


access(all) struct StakingDetails {
    // TokenMeta
    access(all) let meta: FRC20Indexer.FRC20Meta
    access(all) let holders: UInt64
    access(all) let pool: UFix64
    access(all) let stakable: Bool
    access(all) let stakingAddr: Address?
    access(all) let marketEnabled: Bool
    // Staking Status
    access(all) let details: FRC20Staking.StakingInfo
    access(all) let floorPriceBuyListing: UFix64
    // for the address
    // check if the address is eligible for registering reward strategy
    access(all) let isEligibleForRegistering: Bool
    // get delegation info for the address
    access(all) let totalStakedBalance: UFix64
    access(all) let totalUnstakingBalance: UFix64
    access(all) let totalUnlockedClaimableBalance: UFix64
    access(all) let totalLockedStakedBalance: UFix64

    init(
        meta: FRC20Indexer.FRC20Meta,
        holders: UInt64,
        pool: UFix64,
        stakable: Bool,
        stakingAddr: Address?,
        marketEnabled: Bool,
        details: FRC20Staking.StakingInfo,
        floorPriceBuyListing: UFix64,
        isEligibleForRegistering: Bool,
        totalStakedBalance: UFix64,
        totalUnstakingBalance: UFix64,
        totalUnlockedClaimableBalance: UFix64,
        totalLockedStakedBalance: UFix64,
    ) {
        self.meta = meta
        self.holders = holders
        self.pool = pool
        self.stakable = stakable
        self.stakingAddr = stakingAddr
        self.marketEnabled = marketEnabled
        // Staking Status
        self.details = details
        self.floorPriceBuyListing = floorPriceBuyListing
        // for the address
        self.isEligibleForRegistering = isEligibleForRegistering
        self.totalStakedBalance = totalStakedBalance
        self.totalUnstakingBalance = totalUnstakingBalance
        self.totalUnlockedClaimableBalance = totalUnlockedClaimableBalance
        self.totalLockedStakedBalance = totalLockedStakedBalance
    }
}
