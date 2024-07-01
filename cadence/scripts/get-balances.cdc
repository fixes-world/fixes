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
        if tick == "" {
            var flowBal = 0.0
            if let flowRef = getAccount(addr)
                .getCapability(/public/flowTokenBalance)
                .borrow<&{FungibleToken.Balance}>()
            {
                flowBal = flowRef.balance
            }
            ret[""] = flowBal
        } else if tick == "@".concat(Type<@stFlowToken.Vault>().identifier) {
            var bal = 0.0
            if let stFlowRef = getAccount(addr)
                .getCapability(stFlowToken.tokenBalancePath)
                .borrow<&{FungibleToken.Balance}>()
            {
                bal = stFlowRef.balance
            }
            ret["@"] = bal
        } else {
            ret[tick] = indexer.getBalance(tick: tick, addr: addr)
        }
    }
    return ret
}
