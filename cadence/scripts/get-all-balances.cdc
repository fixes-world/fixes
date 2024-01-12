import "FRC20Indexer"

access(all)
fun main(
    addr: Address
): {String: UFix64} {
    let indexer = FRC20Indexer.getIndexer()
    return indexer.getBalances(addr: addr)
}
