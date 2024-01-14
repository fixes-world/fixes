import "FRC20Indexer"

access(all)
fun main(): UFix64 {
    let indexer = FRC20Indexer.getIndexer()
    return indexer.getPlatformTreasuryBalance()
}
