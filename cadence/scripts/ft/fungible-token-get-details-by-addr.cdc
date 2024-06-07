// Fixes Imports
import "FixesFungibleTokenInterface"
import "FungibleTokenManager"

access(all)
fun main(
    ftAddress: Address,
): FungibleTokenManager.FixesTokenView? {
    let ftAcct = getAccount(ftAddress)
    var ftName = "FixesFungibleToken"
    var ftContract = ftAcct.contracts.borrow<&FixesFungibleTokenInterface>(name: ftName)
    if ftContract == nil {
        ftName = "FRC20FungibleToken"
        ftContract = ftAcct.contracts.borrow<&FixesFungibleTokenInterface>(name: ftName)
    }
    if ftContract == nil {
        return nil
    }
    return FungibleTokenManager.buildFixesTokenView(ftAddress, ftName)
}
