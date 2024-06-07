// Fixes Imports
import "FixesFungibleTokenInterface"
import "FungibleTokenManager"

access(all)
fun main(
    _ addr: Address
): [FungibleTokenManager.FixesTokenView] {
    let views: [FungibleTokenManager.FixesTokenView] = []
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
            if let tokenView = FungibleTokenManager.buildFixesTokenView(ftAddress, ftName) {
                views.append(tokenView)
            }
        }
    }
    return views
}
