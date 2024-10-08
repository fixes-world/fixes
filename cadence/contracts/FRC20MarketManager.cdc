/**
> Author: Fixes Lab <https://github.com/fixes-world/>

# FRC20MarketManager

THe resource manager for the FRC20Marketplace contract.

*/
import "Fixes"
import "FixesInscriptionFactory"
import "FixesHeartbeat"
import "FRC20FTShared"
import "FRC20Indexer"
import "FRC20AccountsPool"
import "FRC20Marketplace"
import "FRC20TradingRecord"

access(all) contract FRC20MarketManager {

    access(all) entitlement Manage

    /* --- Events --- */

    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()

    /// Event emitted when a new market is enabled
    access(all) event NewMarketEnabled(tick: String, address: Address, by: Address)

    /* --- Variable, Enums and Structs --- */

    access(all)
    let FRC20MarketManagerStoragePath: StoragePath

    /* --- Interfaces & Resources --- */

    /// The resource manager for the FRC20MarketManager
    ///
    access(all)
    resource Manager: FRC20Marketplace.MarketManager {
        /// Update the admin whitelist
        ///
        access(Manage)
        fun updateAdminWhitelist(
            tick: String,
            address: Address,
            isWhitelisted: Bool
        ) {
            let market = FRC20MarketManager.borrowMarket(tick)
                ?? panic("The market is not enabled")
            market.updateAdminWhitelist(
                mananger: (&self as &{FRC20Marketplace.MarketManager}),
                address: address,
                isWhitelisted: isWhitelisted
            )
        }

        /// Update the marketplace properties
        ///
        access(Manage)
        fun updateMarketplaceProperties(
            tick: String,
            _ props: {FRC20FTShared.ConfigType: String}
        ) {
            let market = FRC20MarketManager.borrowMarket(tick)
                ?? panic("The market is not enabled")
            market.updateMarketplaceProperties(
                mananger: (&self as &{FRC20Marketplace.MarketManager}),
                props
            )
        }
    }

    /* --- Contract access methods  --- */

    access(contract)
    fun _ensureMarketResourcesAvailable(tick: String) {
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // try to borrow the account to check if it was created
        let childAcctRef = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.Market, tick)
            ?? panic("The market account was not created")

        // The market should have the following resources in the account:
        // - FRC20Marketplace.Market: Market resource
        // - FRC20FTShared.SharedStore: Market configuration
        // - FRC20FTShared.Hooks: Hooks for the transactions done in the market
        // - FRC20TradingRecord.TradingRecordingHook: Hook for the trading records
        // - FRC20TradingRecord.TradingRecords: Trading records resource

        if let market = childAcctRef.storage.borrow<&FRC20Marketplace.Market>(from: FRC20Marketplace.FRC20MarketStoragePath) {
            assert(
                market.tick == tick,
                message: "The market tick is not the same as the expected one"
            )
        } else {
            // create the market and save it in the account
            let market <- FRC20Marketplace.createMarket(tick)
            // save the market in the account
            childAcctRef.storage.save(<- market, to: FRC20Marketplace.FRC20MarketStoragePath)

            // link the market to the public path
            childAcctRef.capabilities.unpublish(FRC20Marketplace.FRC20MarketPublicPath)
            childAcctRef.capabilities.publish(
                childAcctRef.capabilities.storage.issue<&FRC20Marketplace.Market>(FRC20Marketplace.FRC20MarketStoragePath),
                at: FRC20Marketplace.FRC20MarketPublicPath
            )
        }

        // create the shared store and save it in the account
        if childAcctRef.storage.borrow<&AnyResource>(from: FRC20FTShared.SharedStoreStoragePath) == nil {
            let sharedStore <- FRC20FTShared.createSharedStore()
            childAcctRef.storage.save(<- sharedStore, to: FRC20FTShared.SharedStoreStoragePath)
            // link the shared store to the public path
            childAcctRef.capabilities.unpublish(FRC20FTShared.SharedStorePublicPath)
            childAcctRef.capabilities.publish(
                childAcctRef.capabilities.storage.issue<&FRC20FTShared.SharedStore>(FRC20FTShared.SharedStoreStoragePath),
                at: FRC20FTShared.SharedStorePublicPath
            )
        }

        // create the hooks and save it in the account
        if childAcctRef.storage.borrow<&AnyResource>(from: FRC20FTShared.TransactionHookStoragePath) == nil {
            let hooks <- FRC20FTShared.createHooks()
            childAcctRef.storage.save(<- hooks, to: FRC20FTShared.TransactionHookStoragePath)
        }
        // link the hooks to the public path
        if childAcctRef
            .capabilities.get<&FRC20FTShared.Hooks>(FRC20FTShared.TransactionHookPublicPath)
            .borrow() == nil {
            // link the hooks to the public path
            childAcctRef.capabilities.unpublish(FRC20FTShared.TransactionHookPublicPath)
            childAcctRef.capabilities.publish(
                childAcctRef.capabilities.storage.issue<&FRC20FTShared.Hooks>(FRC20FTShared.TransactionHookStoragePath),
                at: FRC20FTShared.TransactionHookPublicPath
            )
        }

        // borrow the hooks reference
        let hooksRef = childAcctRef.storage.borrow<auth(FRC20FTShared.Manage) &FRC20FTShared.Hooks>(from: FRC20FTShared.TransactionHookStoragePath)
            ?? panic("The hooks were not created")

        // ensure trading records are available
        if childAcctRef.storage.borrow<&AnyResource>(from: FRC20TradingRecord.TradingRecordsStoragePath) == nil {
            let tradingRecords <- FRC20TradingRecord.createTradingRecords(tick)
            childAcctRef.storage.save(<- tradingRecords, to: FRC20TradingRecord.TradingRecordsStoragePath)
            // link the trading records to the public path
            childAcctRef.capabilities.unpublish(FRC20TradingRecord.TradingRecordsPublicPath)
            childAcctRef.capabilities.publish(
                childAcctRef.capabilities.storage.issue<&FRC20TradingRecord.TradingRecords>(FRC20TradingRecord.TradingRecordsStoragePath),
                at: FRC20TradingRecord.TradingRecordsPublicPath
            )
        }

        // add the trading records to the hooks, if it is not added yet
        // get the public capability of the trading record hook
        let tradingRecordsCap = childAcctRef
            .capabilities.get<&FRC20TradingRecord.TradingRecords>(
                FRC20TradingRecord.TradingRecordsPublicPath
            )
        assert(tradingRecordsCap.check(), message: "The trading record hook is not valid")
        // get the reference of the trading record hook
        let recordsRef = tradingRecordsCap.borrow()
            ?? panic("The trading record hook is not valid")
        if !hooksRef.hasHook(recordsRef.getType()) {
            hooksRef.addHook(tradingRecordsCap)
        }
    }

    // --- Public methods ---

    /// Enable a new market, and create the market account
    /// The inscription owner should be the deployer of the token
    ///
    access(all)
    fun enableAndCreateFRC20Market(
        ins: auth(Fixes.Extractable) &Fixes.Inscription,
        newAccount: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>,
    ) {
        // singletoken resources
        let frc20Indexer = FRC20Indexer.getIndexer()
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // inscription data
        let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
        let op = meta["op"]?.toLower() ?? panic("The token operation is not found")
        assert(
            op == "enable-market",
            message: "The inscription is not for enabling a market"
        )

        let tick = meta["tick"]?.toLower() ?? panic("The token tick is not found")

        /// Check if the market is already enabled
        assert(
            acctsPool.getFRC20MarketAddress(tick: tick) == nil,
            message: "The market is already enabled"
        )

        // Check if the token is already registered
        let tokenMeta = frc20Indexer.getTokenMeta(tick: tick) ?? panic("The token is not registered")
        assert(
            tokenMeta.deployer == ins.owner!.address,
            message: "The token is not deployed by the inscription owner"
        )

        // execute the inscription to ensure you are the deployer of the token
        let ret = frc20Indexer.executeByDeployer(ins: ins)
        assert(
            ret == true,
            message: "The inscription execution failed"
        )

        // create the account for the market at the accounts pool
        acctsPool.setupNewChildForMarket(
            tick: tick,
            newAccount
        )
        let address = acctsPool.getFRC20MarketAddress(tick: tick)
            ?? panic("The market account was not created")

        // ensure all market resources are available
        self._ensureMarketResourcesAvailable(tick: tick)

        // emit the event
        emit NewMarketEnabled(
            tick: tick,
            address: address,
            by: ins.owner!.address
        )
    }

    /// Borrow the market reference
    ///
    access(all)
    view fun borrowMarket(_ tick: String): &{FRC20Marketplace.MarketPublic}? {
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        if let address = acctsPool.getFRC20MarketAddress(tick: tick) {
            return FRC20Marketplace.borrowMarket(address)
        }
        return nil
    }

    /// Anyone can create a market manager resource.
    ///
    access(all)
    fun createManager(): @Manager {
        return <- create Manager()
    }

    init() {
        let identifier = "FRC20MarketManager_".concat(self.account.address.toString())
        self.FRC20MarketManagerStoragePath = StoragePath(identifier: identifier)!

        emit ContractInitialized()
    }
}
