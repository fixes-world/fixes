import "FRC20Indexer"
import "FGameLottery"
import "FGameLotteryRegistry"
import "FGameLotteryFactory"
import "FRC20FTShared"
import "FRC20Staking"
import "FRC20AccountsPool"

access(all)
fun main(): UFix64 {
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
