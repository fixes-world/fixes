import "FungibleToken"
import "FlowToken"
import "stFlowToken"
import "FRC20Indexer"

access(all)
fun main(
    addr: Address,
    ticks: [String],
): {String: UFix64} {
    let indexer = FRC20Indexer.getIndexer()
    let ret: {String: UFix64} = {}
    for tick in ticks {
        if ret[tick] != nil {
            continue
        }
        var bal = 0.0
        if tick == "" {
            if let flowRef = getAccount(addr)
                .capabilities.get<&{FungibleToken.Balance}>(/public/flowTokenBalance)
                .borrow()
            {
                bal = flowRef.balance
            }
            ret[""] = bal
        } else if tick == "@".concat(Type<@stFlowToken.Vault>().identifier) {
            if let stFlowRef = getAccount(addr)
                .capabilities.get<&{FungibleToken.Balance}>(stFlowToken.tokenBalancePath)
                .borrow()
            {
                bal = stFlowRef.balance
            }
            ret["@"] = bal
        } else {
            if let tokenMeta = indexer.getTokenMeta(tick: tick) {
                bal = indexer.getBalance(tick: tokenMeta.tick, addr: addr)
            }
            ret[tick] = bal
        }
    }
    return ret
}
