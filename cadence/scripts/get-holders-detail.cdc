import "FRC20Indexer"

access(all)
fun main(
    tick: String,
): [BalanceInfo] {
    let indexer = FRC20Indexer.getIndexer()
    let addrs = indexer.getHolders(tick: tick)

    let ret: [BalanceInfo] = []
    var i = 0
    while i < addrs.length {
        let addr = addrs[i]
        let amount = indexer.getBalance(tick: tick, addr: addr)
        if amount > 0.0 {
            ret.append(BalanceInfo(address: addr, amount: amount))
        }
        i = i + 1
    }
    return ret
}

access(all) struct BalanceInfo {
    access(all) let address: Address
    access(all) let amount: UFix64

    init(address: Address, amount: UFix64) {
        self.address = address
        self.amount = amount
    }
}
