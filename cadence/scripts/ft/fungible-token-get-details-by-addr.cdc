// Fixes Imports
import "FixesFungibleTokenInterface"
import "FungibleTokenManager"

access(all)
fun main(
    ftAddress: Address,
): FungibleTokenManager.FixesTokenInfo? {
    return FungibleTokenManager.buildFixesTokenInfo(ftAddress, nil)
}
