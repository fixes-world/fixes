import "FRC20Indexer"

pub fun main(
    page: Int,
    size: Int
): [FRC20Indexer.FRC20Meta] {
    let indexer = FRC20Indexer.getIndexer()
    let tokens = indexer.getTokens()

    let len = tokens.length
    let startFrom = page * size
    let endAt = len > startFrom + size ? startFrom + size : len
    let slicedTokens = tokens.slice(from: startFrom, upTo: endAt)

    let ret: [FRC20Indexer.FRC20Meta] = []
    for tick in slicedTokens {
        if let meta = indexer.getTokenMeta(tick: tick) {
            ret.append(meta)
        }
    }
    return ret
}
