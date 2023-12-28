import "Fixes"
import "FixesWrappedNFT"
import "FRC20NFTWrapper"
import "FRC20Indexer"

pub fun main(
    includeNoStrategy: Bool
): [WrapperHost] {
    let wrapperIndexer = FRC20NFTWrapper.borrowWrapperIndexerPublic()
    let ret: [WrapperHost] = []

    let wrappers = wrapperIndexer.getAllWrappers(includeNoStrategy: includeNoStrategy)
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

pub struct WrapperHost {
    pub let address: Address
    pub let strategiesAmt: UInt64
    pub let whitelisted: [Address]

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
