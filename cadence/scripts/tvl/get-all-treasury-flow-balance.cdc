import "FRC20Indexer"

access(all)
fun main(): UFix64 {
    let indexer = FRC20Indexer.getIndexer()
    let tokens = indexer.getTokens()
    var totalBalance = 0.0
    for tick in tokens {
        let balance = indexer.getPoolBalance(tick: tick)
        totalBalance = totalBalance + balance
    }
    return totalBalance
}
