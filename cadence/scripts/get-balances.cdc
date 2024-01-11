import "FungibleToken"
import "FlowToken"
import "FRC20Indexer"

access(all)
fun main(
    addr: Address,
    ticks: [String],
): {String: UFix64} {
    let indexer = FRC20Indexer.getIndexer()
    let vaultRef = getAccount(addr)
        .getCapability(/public/flowTokenBalance)
        .borrow<&FlowToken.Vault{FungibleToken.Balance}>()
        ?? panic("Could not borrow Balance reference to the Vault")
    let ret: {String: UFix64} = {}
    for tick in ticks {
        if tick != "" {
            let balance = indexer.getBalance(tick: tick, addr: addr)
            if balance > 0.0 {
                ret[tick] = balance
            }
        } else {
            let balance = vaultRef.balance
            if balance > 0.0 {
                ret[""] = balance
            }
        }
    }
    return ret
}
