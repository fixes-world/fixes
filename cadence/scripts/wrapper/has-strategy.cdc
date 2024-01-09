import "Fixes"
import "FixesWrappedNFT"
import "FRC20NFTWrapper"
import "FRC20Indexer"

access(all)
fun main(
    wrapperAddr: Address,
    nftType: String
): Bool {
    if let wrapper = FRC20NFTWrapper.borrowWrapperPublic(addr: wrapperAddr) {
        if let type = CompositeType(nftType) {
            return wrapper.hasFRC20Strategy(FRC20NFTWrapper.asCollectionType(type.identifier))
        }
    }
    return false
}
