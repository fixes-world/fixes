import "FungibleToken"
// Fixes Imports
import "FixesTokenLockDrops"

access(all)
fun main(
    userAddr: Address,
): [Address] {
    let center = FixesTokenLockDrops.borrowLockingCenter()
    return center.getUserJoinedPools(userAddr)
}
