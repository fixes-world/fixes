// Fixes Imports
import "FixesTradablePool"

access(all)
fun main(
    ftAddr: Address,
    amount: UFix64,
): UFix64? {
    if let pool = FixesTradablePool.borrowTradablePool(ftAddr) {
        return pool.getEstimatedSellingValueByAmount(amount)
    }
    return nil
}
