import "FRC20Indexer"

access(all)
fun main(
    tick: String
): Bool {
    let indexer = FRC20Indexer.getIndexer()
    return indexer.getTokenMeta(tick: tick) != nil
}
