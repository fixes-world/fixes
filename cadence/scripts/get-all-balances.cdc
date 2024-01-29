import "FungibleToken"
import "FlowToken"
import "FRC20Indexer"

access(all)
fun main(
    addr: Address,
    includeFlowToken: Bool,
): {String: UFix64} {
    let indexer = FRC20Indexer.getIndexer()
    let balances = indexer.getBalances(addr: addr)
    if includeFlowToken {
        let vaultRef = getAccount(addr)
            .getCapability(/public/flowTokenBalance)
            .borrow<&FlowToken.Vault{FungibleToken.Balance}>()
            ?? panic("Could not borrow Balance reference to the Vault")
        balances[""] = vaultRef.balance
    }
    return balances
}
