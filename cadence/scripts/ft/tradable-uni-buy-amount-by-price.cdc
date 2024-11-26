// Fixes Imports
import "FixesTradablePool"

access(all)
fun main(
    ftAddr: Address,
    cost: UFix64,
): UFix64? {
    if let pool = FixesTradablePool.borrowTradablePool(ftAddr) {
        return pool.getEstimatedBuyingAmountByCost(cost)
    }
    return nil
}
