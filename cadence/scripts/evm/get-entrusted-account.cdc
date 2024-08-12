import "FRC20AccountsPool"

access(all)
fun main(
    key: String
): Address? {
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    return acctsPool.getEntrustedAccountAddress(key)
}
