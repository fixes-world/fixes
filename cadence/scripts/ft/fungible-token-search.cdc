import "ViewResolver"
import "FungibleTokenMetadataViews"
// Fixes Imports
import "FRC20AccountsPool"
import "FungibleTokenManager"

access(all)
fun main(
    _ name: String
): [FungibleTokenManager.FixesTokenInfo] {
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    let addresses = acctsPool.getAddresses(type: FRC20AccountsPool.ChildAccountType.FungibleToken)
    let arr: [FungibleTokenManager.FixesTokenInfo] = []

    for key in addresses.keys {
        let ftAddress = addresses[key]!
        if let info = FungibleTokenManager.buildFixesTokenInfo(ftAddress, nil) {
            arr.append(info)
        }
    }
    return arr
}
