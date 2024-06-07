// Fixes Imports
import "FRC20AccountsPool"
import "FungibleTokenManager"

access(all)
fun main(
    accountKey: String,
): FungibleTokenManager.FixesTokenView? {
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    if let ftAddress = acctsPool.getFTContractAddress(accountKey) {
        let ftName = accountKey[0] == "$" ? "FixesFungibleToken" : "FRC20FungibleToken"
        return FungibleTokenManager.buildFixesTokenView(ftAddress, ftName)
    }
    return nil
}
