// Thirdparty imports
import "MetadataViews"
// Fixes imports
import "FixesAvatar"
import "FixesHeartbeat"
import "FRC20FTShared"
import "FRC20Indexer"
import "FRC20AccountsPool"
import "FRC20TradingRecord"
import "FRC20Marketplace"

transaction(
    tick: String,
) {
    let signerAddress: Address
    let market: &{FRC20Marketplace.MarketPublic}

    prepare(acct: auth(Storage, Capabilities) &Account) {
        /** ------------- Start -- TradingRecords General Initialization -------------  */
        // Ensure hooks are initialized
        if acct.storage.borrow<&AnyResource>(from: FRC20FTShared.TransactionHookStoragePath) == nil {
            let hooks <- FRC20FTShared.createHooks()
            acct.storage.save(<- hooks, to: FRC20FTShared.TransactionHookStoragePath)
        }

        // link the hooks to the public path
        if acct
            .capabilities.get<&FRC20FTShared.Hooks>(FRC20FTShared.TransactionHookPublicPath)
            .borrow() == nil {
            // link the hooks to the public path
            acct.capabilities.unpublish(FRC20FTShared.TransactionHookPublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FRC20FTShared.Hooks>(FRC20FTShared.TransactionHookStoragePath),
                at: FRC20FTShared.TransactionHookPublicPath
            )
        }

        // borrow the hooks reference
        let hooksRef = acct.storage
            .borrow<auth(FRC20FTShared.Manage) &FRC20FTShared.Hooks>(from: FRC20FTShared.TransactionHookStoragePath)
            ?? panic("The hooks were not created")

        // Ensure Trading Records is initialized
        if acct.storage.borrow<&AnyResource>(from: FRC20TradingRecord.TradingRecordsStoragePath) == nil {
            let tradingRecords <- FRC20TradingRecord.createTradingRecords(nil)
            acct.storage.save(<- tradingRecords, to: FRC20TradingRecord.TradingRecordsStoragePath)
            // link the trading records to the public path
            acct.capabilities.unpublish(FRC20TradingRecord.TradingRecordsPublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FRC20TradingRecord.TradingRecords>(FRC20TradingRecord.TradingRecordsStoragePath),
                at: FRC20TradingRecord.TradingRecordsPublicPath
            )
        }

        // Ensure trading record hook is added to the hooks
        // get the public capability of the trading record hook
        let tradingRecordsCap = acct
            .capabilities.get<&FRC20TradingRecord.TradingRecords>(
                FRC20TradingRecord.TradingRecordsPublicPath
            )
        assert(tradingRecordsCap.check(), message: "The trading record hook is not valid")
        // get the reference of the trading record hook
        let recordsRef = tradingRecordsCap.borrow() ?? panic("The trading record hook is not valid")
        if !hooksRef.hasHook(recordsRef.getType()) {
            hooksRef.addHook(tradingRecordsCap)
        }

        // Ensure Fixes Avatar is initialized
        if acct.storage.borrow<&AnyResource>(from: FixesAvatar.AvatarStoragePath) == nil {
            acct.storage.save(<- FixesAvatar.createProfile(), to: FixesAvatar.AvatarStoragePath)
            // link the avatar to the public path
            acct.capabilities.unpublish(FixesAvatar.AvatarPublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FixesAvatar.Profile>(FixesAvatar.AvatarStoragePath),
                at: FixesAvatar.AvatarPublicPath
            )
        }
        let profileCap = FixesAvatar.getProfileCap(acct.address)
        assert(profileCap.check(), message: "The profile is not valid")
        let profileRef = profileCap.borrow() ?? panic("The profile is not valid")
        if !hooksRef.hasHook(profileRef.getType()) {
            hooksRef.addHook(profileCap)
        }
        /** ------------- End -----------------------------------------------------------------  */

        // Borrow a reference to the FRC20Marketplace contract
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

        log("Done: user claim access")
    }

    post {
        self.market.canAccess(addr: self.signerAddress): "Failed to update your Accessible properties"
    }
}

