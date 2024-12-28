/**

> Author: Fixes Lab <https://github.com/fixes-world/>

# FixesTVL

This is an utility contract for calculating the Total Value Locked (TVL) of the Fixes ecosystem.

*/
import "FungibleToken"
import "LiquidStaking"
import "stFlowToken"
// Fixes Imports
import "FRC20FTShared"
import "FRC20Indexer"
import "FRC20Staking"
import "FRC20AccountsPool"
import "FRC20Marketplace"
import "FRC20Storefront"
import "FGameLottery"
import "FGameLotteryRegistry"
import "FGameLotteryFactory"
import "FixesFungibleTokenInterface"
import "FixesTokenLockDrops"
import "FixesTradablePool"

/// The Fixes Asset Genes contract
///
access(all) contract FixesTVL {

    /// Get Flow Value of all staked $flows tokens
    ///
    access(all)
    fun getAllStakedFlowValue(): UFix64 {
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

    /// Get Flow Value of all treasury pool balances
    ///
    access(all)
    fun getAllTreasuryFlowValue(): UFix64 {
        let indexer = FRC20Indexer.getIndexer()
        let tokens = indexer.getTokens()
        var totalBalance = 0.0
        // all treasury pool balance
        for tick in tokens {
            let balance = indexer.getPoolBalance(tick: tick)
            totalBalance = totalBalance + balance
        }

        // FLOW lottery jackpot balance
        let registry = FGameLotteryRegistry.borrowRegistry()
        let flowLotteryPoolName = FGameLotteryFactory.getFIXESMintingLotteryPoolName()
        if let poolAddr = registry.getLotteryPoolAddress(flowLotteryPoolName) {
            if let poolRef = FGameLottery.borrowLotteryPool(poolAddr) {
                let jackpotBalance = poolRef.getJackpotPoolBalance()
                totalBalance = totalBalance + jackpotBalance
            }
        }

        // Unclaimed FLOW Reward in the staking reward pool
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        let platformStakingTick = FRC20FTShared.getPlatformStakingTickerName()
        if let stakingPoolAddr = acctsPool.getFRC20StakingAddress(tick: platformStakingTick) {
            if let stakingPool = FRC20Staking.borrowPool(stakingPoolAddr) {
                if let detail = stakingPool.getRewardDetails("") {
                    totalBalance = totalBalance + detail.totalReward
                }
            }
        }

        return totalBalance
    }

    /// Get Flow Value of all locked Fixes coins
    ///
    access(all)
    fun getAllLockedCoinFlowValue(): UFix64 {
        // singleton resource and constants
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        let frc20Indexer = FRC20Indexer.getIndexer()
        let stFlowTokenKey = "@".concat(Type<@stFlowToken.Vault>().identifier)

        // dictionary of addresses
        let addrsDict = acctsPool.getAddresses(type: FRC20AccountsPool.ChildAccountType.FungibleToken)
        // dictionary of tickers and total locked token balances
        let tickerTotal: {String: UFix64} = {}
        // This is the soft burned LP value which is fully locked in the BlackHole Vault
        var flowLockedInBondingCurve = 0.0
        var flowValueLockedInLotteryPool = 0.0
        addrsDict.forEachKey(fun (key: String): Bool {
            if let addr = addrsDict[key] {
                // sum up all locked token balances in LockDrops Pool
                if let dropsPool = FixesTokenLockDrops.borrowDropsPool(addr) {
                    let lockedTokenSymbol = dropsPool.getLockingTokenTicker()
                    tickerTotal[lockedTokenSymbol] = (tickerTotal[lockedTokenSymbol] ?? 0.0) + dropsPool.getTotalLockedTokenBalance()
                }
                // sum up all locked flow in Bonding Curve
                if let tradablePool = FixesTradablePool.borrowTradablePool(addr) {
                    flowLockedInBondingCurve = flowLockedInBondingCurve + tradablePool.getFlowBalanceInPool()

                    // sum up all locked flow in Lottery Pool
                    if let lotteryPool = FGameLottery.borrowLotteryPool(addr) {
                        let lotteryPoolBalance = lotteryPool.getPoolTotalBalance()
                        let flowValue = tradablePool.getSwapEstimatedAmount(true, amount: lotteryPoolBalance)
                        flowValueLockedInLotteryPool = flowValueLockedInLotteryPool + flowValue
                    }
                }
            }
            return true
        })
        // sum up all locked token balances in LockDrops Pool
        var totalLockingTokenTVL = 0.0
        tickerTotal.forEachKey(fun (key: String): Bool {
            let lockedAmount = tickerTotal[key]!
            if key == "" {
                // this is locked FLOW
                totalLockingTokenTVL = totalLockingTokenTVL + lockedAmount
            } else if key == "fixes" {
                // this is locked FIXES
                let price = frc20Indexer.getBenchmarkValue(tick: "fixes")
                totalLockingTokenTVL = totalLockingTokenTVL + lockedAmount * price
            } else if key == stFlowTokenKey {
                // this is locked stFlow
                totalLockingTokenTVL = totalLockingTokenTVL + LiquidStaking.calcFlowFromStFlow(stFlowAmount: lockedAmount)
            }
            return true
        })
        return totalLockingTokenTVL + flowLockedInBondingCurve + flowValueLockedInLotteryPool
    }
}
