import "FRC20AccountsPool"

access(all)
fun main(
    tick: String
): Bool {
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    return acctsPool.getFRC20MarketAddress(tick: tick) != nil
}
