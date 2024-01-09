import "Fixes"
import "FixesWrappedNFT"
import "FRC20NFTWrapper"
import "FRC20Indexer"

access(all)
fun main(
    addr: Address
): UFix64 {
    let wrapper = FRC20NFTWrapper.borrowWrapperPublic(addr: addr)
        ?? panic("Wrapper not found")
    return wrapper.getInternalFlowBalance()
}
