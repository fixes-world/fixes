import "FTViewUtils"
import "ViewResolver"
import "FungibleTokenMetadataViews"
// Fixes Imports
import "FRC20AccountsPool"
import "FungibleTokenManager"

access(all)
fun main(
    _ name: String
): [FTViewUtils.StandardTokenView] {
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    let addresses = acctsPool.getAddresses(type: FRC20AccountsPool.ChildAccountType.FungibleToken)
    let views: [FTViewUtils.StandardTokenView] = []

    for key in addresses.keys {
        let ftAddress = addresses[key]!
        let ftName = key[0] == "$" ? "FixesFungibleToken" : "FRC20FungibleToken"
        if let view = FungibleTokenManager.buildStandardTokenView(ftAddress, ftName) {
            views.append(view)
        }
    }
    return views
}
