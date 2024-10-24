import "FlowEVMBridge"
// Fixes Imports
import "FungibleTokenManager"

// Check if the fungible token is bridged
access(all)
fun main(
    ftAddress: Address,
): Bool {
    if let info = FungibleTokenManager.buildFixesTokenInfo(ftAddress, nil) {
        let ftType = info.view.standardView.identity.buildType()
        let isRequires = FlowEVMBridge.typeRequiresOnboarding(ftType)
        if isRequires == nil {
            return false
        }
        return isRequires!
    }
    return false
}
