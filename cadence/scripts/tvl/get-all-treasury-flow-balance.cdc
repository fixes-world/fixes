import "FRC20Indexer"
import "FGameLottery"
import "FGameLotteryRegistry"
import "FGameLotteryFactory"

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
    return totalBalance
}
