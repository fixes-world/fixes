// Fixes imports
import "FRC20Indexer"
import "FRC20FTShared"
import "FRC20AccountsPool"
import "FRC20Staking"
import "FRC20StakingManager"
import "FRC20Marketplace"
import "FRC20Storefront"
import "FRC20StakingVesting"

access(all)
fun main(
    tick: String,
    strategies: [String]
): [RewardStrategyDetail] {
    let ret: [RewardStrategyDetail] = []

    let indexer = FRC20Indexer.getIndexer()
    let tokenMeta = indexer.getTokenMeta(tick: tick)
        ?? panic("No token meta for the token")

    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    // staking info
    let stakingAddr = acctsPool.getFRC20StakingAddress(tick: tick)
        ?? panic("No staking address for the token".concat(tick))
    let stakingPool = FRC20Staking.borrowPool(stakingAddr)
        ?? panic("No staking pool for the token".concat(tick))
    let vestingPool = FRC20StakingVesting.borrowVaultRef(stakingAddr)
        ?? panic("No vesting pool for the token".concat(tick))
    // convert to dict
    let vestings = vestingPool.getVestingEntries()
    let rewardVestingDict: {String: [FRC20StakingVesting.VestingInfo]} = {}
    for vesting in vestings {
        if vesting.stakeTick != tick {
            continue
        }
        if rewardVestingDict[vesting.rewardTick] == nil {
            rewardVestingDict[vesting.rewardTick] = []
        }
        let dictRef = (&rewardVestingDict[vesting.rewardTick] as &[FRC20StakingVesting.VestingInfo]?)!
        dictRef.append(vesting)
    }
    // get reward details
    for rewardTick in strategies {
        let isFTReward = rewardTick == "" || CompositeType(rewardTick) != nil
        if let rewardStrategy = stakingPool.getRewardDetails(rewardTick) {
            let detail = RewardStrategyDetail(
                meta: !isFTReward ? indexer.getTokenMeta(tick: rewardTick) : nil,
                holders: !isFTReward ? indexer.getHoldersAmount(tick: rewardTick) : nil,
                pool: !isFTReward ? indexer.getPoolBalance(tick: rewardTick) : nil,
                stakable: acctsPool.getFRC20StakingAddress(tick: rewardTick) != nil,
                stakingAddr: acctsPool.getFRC20StakingAddress(tick: rewardTick),
                marketEnabled: acctsPool.getFRC20MarketAddress(tick: tick) != nil,
                details: rewardStrategy,
                vestings: rewardVestingDict[rewardTick] ?? []
            )
            ret.append(detail)
        }
    }

    return ret
}

access(all) struct RewardStrategyDetail {
    // Reward TokenMeta
    access(all) let meta: FRC20Indexer.FRC20Meta?
    access(all) let holders: UInt64?
    access(all) let pool: UFix64?
    access(all) let stakable: Bool?
    access(all) let stakingAddr: Address?
    access(all) let marketEnabled: Bool?
    // Strategy Details
    access(all) let details: FRC20Staking.RewardDetails
    access(all) let vestings: [FRC20StakingVesting.VestingInfo]

    init(
        meta: FRC20Indexer.FRC20Meta?,
        holders: UInt64?,
        pool: UFix64?,
        stakable: Bool?,
        stakingAddr: Address?,
        marketEnabled: Bool?,
        details: FRC20Staking.RewardDetails,
        vestings: [FRC20StakingVesting.VestingInfo]
    ) {
        self.meta = meta
        self.holders = holders
        self.pool = pool
        self.stakable = stakable
        self.stakingAddr = stakingAddr
        self.marketEnabled = marketEnabled
        self.details = details
        self.vestings = vestings
    }
}
