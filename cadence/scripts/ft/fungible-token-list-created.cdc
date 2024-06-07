import "FTViewUtils"
import "ViewResolver"
import "FungibleTokenMetadataViews"
// Fixes Imports
import "FixesFungibleTokenInterface"
import "FungibleTokenManager"

access(all)
fun main(
    _ addr: Address
): [FTViewUtils.StandardTokenView] {
    let views: [FTViewUtils.StandardTokenView] = []
    if let ftManager = FungibleTokenManager.borrowFTManager(addr) {
        let ftAddresses = ftManager.getCreatedFungibleTokenAddresses()
        for ftAddress in ftAddresses {
            let ftAcct = getAccount(ftAddress)
            var ftName = "FixesFungibleToken"
            var ftContract = ftAcct.contracts.borrow<&FixesFungibleTokenInterface>(name: ftName)
            if ftContract == nil {
                ftName = "FRC20FungibleToken"
                ftContract = ftAcct.contracts.borrow<&FixesFungibleTokenInterface>(name: ftName)
            }
            if ftContract == nil {
                continue
            }
            // setup the view
            if let tokenView = FungibleTokenManager.buildStandardTokenView(ftAddress, ftName) {
                views.append(tokenView)
            }
        }
    }
    return views
}
