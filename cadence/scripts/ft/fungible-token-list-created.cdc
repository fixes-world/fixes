// Fixes Imports
import "FixesFungibleTokenInterface"
import "FungibleTokenManager"

access(all)
fun main(
    _ addr: Address
): [FungibleTokenManager.FixesTokenInfo] {
    let views: [FungibleTokenManager.FixesTokenInfo] = []
    if let ftManager = FungibleTokenManager.borrowFTManager(addr) {
        let ftAddresses = ftManager.getCreatedFungibleTokenAddresses()
        for ftAddress in ftAddresses {
            // setup the view
            if let tokenInfo = FungibleTokenManager.buildFixesTokenInfo(ftAddress, nil) {
                views.append(tokenInfo)
            }
        }
    }
    return views
}
