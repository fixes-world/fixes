import "FungibleToken"
// Fixes Imports
import "FixesTradablePool"
import "FRC20AccountsPool"

access(all)
fun main(
    accountKey: String,
): UFix64? {
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    if let ftAddr = acctsPool.getFTContractAddress(accountKey) {
        if let pool = FixesTradablePool.borrowTradablePool(ftAddr) {
            return pool.getTokenPriceInFlow()
        }
    }
    return nil
}
