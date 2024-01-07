// Thirdparty imports
import "FungibleToken"
import "FlowToken"
// Fixes imports
import "FRC20FTShared"
import "FRC20Indexer"
import "FRC20AccountsPool"
import "FRC20Marketplace"
import "FRC20MarketManager"

transaction(
    tick: String,
) {
    let market: &FRC20Marketplace.Market{FRC20Marketplace.MarketPublic}
    let signerAddress: Address

    prepare(acct: AuthAccount) {
        let pool = FRC20AccountsPool.borrowAccountsPool()
        let marketAddr = pool.getFRC20MarketAddress(tick: tick)
            ?? panic("FRC20Market does not exist for tick ".concat(tick))
        self.market = FRC20Marketplace.borrowMarket(marketAddr)
            ?? panic("Could not borrow reference to the FRC20Market")

        self.signerAddress = acct.address
    }

    execute {
        // All the checks are done in the FRC20Marketplace contract
        // Actually, anyone can invoke this method.
        self.market.claimWhitelist(addr: self.signerAddress)

        log("Done")
    }

    post {
        self.market.canAccess(addr: self.signerAddress): "Failed to update your accessable properties"
    }
}

