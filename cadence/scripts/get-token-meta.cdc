import "FRC20Indexer"

pub fun main(tick: String): FRC20Indexer.FRC20Meta? {
    let indexer = FRC20Indexer.getIndexer()
    return indexer.getTokenMeta(tick: tick)
}
