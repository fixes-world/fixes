import "FixesFungibleTokenInterface"
import "FungibleTokenManager"
import "FixesTradablePool"

access(all)
fun main(
    _ ftAddr: Address
): [RankedHolder] {
    if let ftInterface = FungibleTokenManager.borrowFixesFTInterface(ftAddr) {
        let global = ftInterface.borrowGlobalPublic()
        let tradablePool = FixesTradablePool.borrowTradablePool(ftAddr)
        let totalSupply = tradablePool?.getTotalSupply() ?? global.getGrantedMintableAmount()

        let top100 = global.getEstimatedTop100Holders() ?? []
        let arr: [RankedHolder] = []
        for i, addr in top100 {
            let balance = ftInterface.getTokenBalance(addr)
            arr.append(RankedHolder(
                addr,
                UInt64(i),
                balance,
                balance / totalSupply
            ))
        }
        return arr
    }
    return []
}

access(all) struct RankedHolder {
    access(all) let address: Address
    access(all) let rank: UInt64
    access(all) let balance: UFix64
    access(all) let percentage: UFix64

    init(
        _ address: Address,
        _ rank: UInt64,
        _ balance: UFix64,
        _ percentage: UFix64
    ) {
        self.address = address
        self.rank = rank
        self.balance = balance
        self.percentage = percentage
    }
}
