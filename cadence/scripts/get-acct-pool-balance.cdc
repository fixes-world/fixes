import "FlowToken"
import "FungibleToken"
import "FRC20Indexer"
import "FRC20AccountsPool"

access(all)
fun main(
    type: UInt8,
    tick: String?,
): UFix64 {
    if let type = FRC20AccountsPool.ChildAccountType(rawValue: type) {
        let acctPool = FRC20AccountsPool.borrowAccountsPool()
        var addr: Address? = nil
        if type == FRC20AccountsPool.ChildAccountType.Market {
            if tick == nil {
                addr = acctPool.getMarketSharedAddress()
            } else {
                addr = acctPool.getFRC20MarketAddress(tick: tick!)
            }
        } else if type == FRC20AccountsPool.ChildAccountType.Staking {
            if tick != nil {
                addr = acctPool.getFRC20StakingAddress(tick: tick!)
            }
        }
        if addr != nil {
            let vaultRef = getAccount(addr!)
                .getCapability(/public/flowTokenBalance)
                .borrow<&FlowToken.Vault{FungibleToken.Balance}>()
                ?? panic("Could not borrow Balance reference to the Vault")
            return vaultRef.balance
        }
    }
    return 0.0
}
