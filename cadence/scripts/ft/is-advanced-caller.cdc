import "FixesTradablePool"

access(all)
fun main(_ addr: Address): Bool {
    return FixesTradablePool.isAdvancedTokenPlayer(addr)
}
