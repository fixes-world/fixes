import "FungibleToken"
// Fixes Imports
import "FixesTokenLockDrops"

access(all)
fun main(
    ftAddr: Address,
    lockingPeriod: UFix64,
    lockingAmount: UFix64
): UFix64 {
    if let pool = FixesTokenLockDrops.borrowDropsPool(ftAddr) {
        let perieds = pool.getLockingPeriods()
        if perieds.contains(lockingPeriod) {
            return pool.estimateMintableAmount(lockingPeriod, amount: lockingAmount)
        }
    }
    return 0.0
}
