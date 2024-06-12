// Fixes Imports
import "FRC20AccountsPool"
import "FungibleTokenManager"

access(all)
fun main(
    accountKey: String,
): FungibleTokenManager.FixesTokenInfo? {
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    if let ftAddress = acctsPool.getFTContractAddress(accountKey) {
        return FungibleTokenManager.buildFixesTokenInfo(ftAddress, accountKey)
    }
    return nil
}
