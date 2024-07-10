import "FungibleToken"
// Fixes Imports
import "FixesTradablePool"
import "FRC20AccountsPool"

access(all)
fun main(
    accountKey: String,
    amount: UFix64,
    isAfterFee: Bool
): UFix64? {
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    if let ftAddr = acctsPool.getFTContractAddress(accountKey) {
        if let pool = FixesTradablePool.borrowTradablePool(ftAddr) {
            if pool.isLocalActive() {
                return isAfterFee
                    ? pool.getSellPriceAfterFee(amount)
                    : pool.getSellPrice(amount)
            }
        }
    }
    return nil
}
