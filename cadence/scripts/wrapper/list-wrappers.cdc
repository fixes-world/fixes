import "Fixes"
import "FixesWrappedNFT"
import "FRC20NFTWrapper"
import "FRC20Indexer"

access(all)
fun main(
    includeNoStrategy: Bool
): [WrapperHost] {
    let wrapperIndexer = FRC20NFTWrapper.borrowWrapperIndexerPublic()
    let ret: [WrapperHost] = []

    let wrappers = wrapperIndexer.getAllWrappers(includeNoStrategy, true)
    for addr in wrappers {
        if let wrapper = FRC20NFTWrapper.borrowWrapperPublic(addr: addr) {
            ret.append(WrapperHost(
                addr,
                wrapper.getStrategiesAmount(all: false),
                wrapper.getWhitelistedAddresses()
            ))
        }
    }
    return ret
}

access(all) struct WrapperHost {
    access(all) let address: Address
    access(all) let strategiesAmt: UInt64
    access(all) let whitelisted: [Address]

    init(
        _ address: Address,
        _ strategiesAmt: UInt64,
        _ whitelisted: [Address]
    ) {
        self.address = address
        self.strategiesAmt = strategiesAmt
        self.whitelisted = whitelisted
    }
}
