import "FRC20Indexer"

pub fun main(
    tick: String,
    addr: Address
): UFix64 {
    let indexer = FRC20Indexer.getIndexer()
    return indexer.getBalance(tick: tick, addr: addr)
}
