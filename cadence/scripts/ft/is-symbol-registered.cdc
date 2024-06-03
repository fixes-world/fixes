import "FRC20AccountsPool"

access(all)
fun main(
    symbol: String
): Bool {
    let tick = "$".concat(symbol)
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    return acctsPool.getFTContractAddress(tick) != nil
}
