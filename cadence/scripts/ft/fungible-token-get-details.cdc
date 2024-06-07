import "FTViewUtils"
import "ViewResolver"
import "FungibleTokenMetadataViews"
// Fixes Imports
import "FRC20AccountsPool"
import "FungibleTokenManager"

access(all)
fun main(
    accountKey: String,
): FTViewUtils.StandardTokenView? {
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    if let ftAddress = acctsPool.getFTContractAddress(accountKey) {
        let ftName = accountKey[0] == "$" ? "FixesFungibleToken" : "FRC20FungibleToken"
        return FungibleTokenManager.buildStandardTokenView(ftAddress, ftName)
    }
    return nil
}
