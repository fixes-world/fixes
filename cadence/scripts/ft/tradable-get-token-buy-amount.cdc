import "FungibleToken"
// Fixes Imports
import "FixesTradablePool"
import "FRC20AccountsPool"

access(all)
fun main(
    accountKey: String,
    cost: UFix64,
    isAfterFee: Bool
): UFix64? {
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    if let ftAddr = acctsPool.getFTContractAddress(accountKey) {
        if let pool = FixesTradablePool.borrowTradablePool(ftAddr) {
            if pool.isLocalActive() {
                return isAfterFee
                    ? pool.getBuyAmountAfterFee(cost)
                    : pool.getBuyAmount(cost)
            }
        }
    }
    return nil
}
