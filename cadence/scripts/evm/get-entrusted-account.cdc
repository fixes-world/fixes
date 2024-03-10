import "FRC20AccountsPool"

access(all)
fun main(
    evmAddr: String
): Address? {
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    return acctsPool.getEVMEntrustedAccountAddress(evmAddr)
}
