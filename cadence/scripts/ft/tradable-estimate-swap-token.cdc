import "FungibleToken"
// Fixes Imports
import "FixesTradablePool"
import "FRC20AccountsPool"

access(all)
fun main(
    accountKey: String,
    directionTokenToFlow: Bool,
    amount: UFix64,
): UFix64? {
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    if let ftAddr = acctsPool.getFTContractAddress(accountKey) {
        if let pool = FixesTradablePool.borrowTradablePool(ftAddr) {
            if pool.isLiquidityHandovered() {
                return pool.getSwapEstimatedAmount(directionTokenToFlow, amount: amount)
            }
        }
    }
    return nil
}
