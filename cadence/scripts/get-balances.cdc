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
            ret[tick] = indexer.getBalance(tick: tick, addr: addr)
        } else {
            ret[""] = vaultRef.balance
        }
    }
    return ret
}
