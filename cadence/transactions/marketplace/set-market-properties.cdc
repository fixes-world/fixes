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
    properties: {UInt8: String}
) {
    let manager: &FRC20MarketManager.Manager
    let market: &FRC20Marketplace.Market{FRC20Marketplace.MarketPublic}

    prepare(acct: AuthAccount) {
        // if the FRC20MarketManager doesn't exist in storage, create it
        if acct.borrow<&FRC20MarketManager.Manager>(from: FRC20MarketManager.FRC20MarketManagerStoragePath) == nil {
            acct.save(<- FRC20MarketManager.createManager(), to: FRC20MarketManager.FRC20MarketManagerStoragePath)
        }
        self.manager = acct.borrow<&FRC20MarketManager.Manager>(from: FRC20MarketManager.FRC20MarketManagerStoragePath)
            ?? panic("Could not borrow reference to the FRC20MarketManager")

        let pool = FRC20AccountsPool.borrowAccountsPool()
        let marketAddr = pool.getFRC20MarketAddress(tick: tick)
            ?? panic("FRC20Market does not exist for tick ".concat(tick))
        self.market = FRC20Marketplace.borrowMarket(marketAddr)
            ?? panic("Could not borrow reference to the FRC20Market")
    }

    pre {
        self.market.isInAdminWhitelist(self.manager.getOwnerAddress()): "Only the owner can update the marketplace properties"
    }

    execute {
        // set the properties
        let initProps: {FRC20FTShared.ConfigType: String} = {}
        for key in properties.keys {
            if let configType = FRC20FTShared.ConfigType(rawValue: key) {
                initProps[configType] = properties[key]!
            }
        }
        if initProps.keys.length > 0 {
            self.manager.updateMarketplaceProperties(tick: tick, initProps)
        }
        log("Done")
    }
}

