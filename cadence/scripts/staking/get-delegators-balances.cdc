// Fixes imports
import "FRC20Indexer"
import "FRC20FTShared"
import "FRC20AccountsPool"
import "FRC20Staking"

access(all)
fun main(
    tick: String,
): [BalanceInfo] {
    let indexer = FRC20Indexer.getIndexer()
    let tokenMeta = indexer.getTokenMeta(tick: tick)
        ?? panic("No token meta for the token")

    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    // staking info
    let stakingAddr = acctsPool.getFRC20StakingAddress(tick: tick)
        ?? panic("No staking address for the token".concat(tick))
    let stakingPool = FRC20Staking.borrowPool(stakingAddr)
        ?? panic("No staking pool for the token".concat(tick))

    let ret: [BalanceInfo] = []
    let delegators = stakingPool.getDelegators()
    for addr in delegators {
        if let delegatorRef = FRC20Staking.borrowDelegator(addr) {
            let amount = delegatorRef.getStakedBalance(tick: tick)
            if amount > 0.0 {
                ret.append(BalanceInfo(address: addr, amount: amount))
            }
        }
    }
    return ret
}


access(all) struct BalanceInfo {
    access(all) let address: Address
    access(all) let amount: UFix64

    init(address: Address, amount: UFix64) {
        self.address = address
        self.amount = amount
    }
}
