import "FRC20Indexer"

pub fun main(
    tick: String,
): [BalanceInfo] {
    let indexer = FRC20Indexer.getIndexer()
    let addrs = indexer.getHolders(tick: tick)

    let ret: [BalanceInfo] = []
    var i = 0
    while i < addrs.length {
        let addr = addrs[i]
        let amount = indexer.getBalance(tick: tick, addr: addr)
        ret.append(BalanceInfo(address: addr, amount: amount))
        i = i + 1
    }
    return ret
}

pub struct BalanceInfo {
    pub let address: Address
    pub let amount: UFix64

    init(address: Address, amount: UFix64) {
        self.address = address
        self.amount = amount
    }
}
