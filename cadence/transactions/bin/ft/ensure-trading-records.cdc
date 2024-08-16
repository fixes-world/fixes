import "FRC20FTShared"
import "FRC20TradingRecord"
import "FixesTradablePool"
import "FixesHeartbeat"

transaction() {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        let centerStoragePath = FixesTradablePool.getTradingCenterStoragePath()
        if acct.storage.borrow<&AnyResource>(from: centerStoragePath) == nil {
            acct.storage.save(<- FixesTradablePool.createCenter(), to: centerStoragePath)
            let cap = acct.capabilities.storage
                .issue<&FixesTradablePool.TradingCenter>(centerStoragePath)
            acct.capabilities.publish(cap, at: FixesTradablePool.getTradingCenterPublicPath())
        }

        // create the hooks and save it in the account
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
            let cap = acct.capabilities.storage.issue<&FRC20FTShared.Hooks>(FRC20FTShared.TransactionHookStoragePath)
            acct.capabilities.publish(cap, at: FRC20FTShared.TransactionHookPublicPath)
        }

        // ensure trading records are available
        if acct.storage.borrow<&AnyResource>(from: FRC20TradingRecord.TradingRecordsStoragePath) == nil {
            let tradingRecords <- FRC20TradingRecord.createTradingRecords(nil)
            acct.storage.save(<- tradingRecords, to: FRC20TradingRecord.TradingRecordsStoragePath)
        }

        if acct
            .capabilities.get<&FRC20TradingRecord.TradingRecords>(FRC20TradingRecord.TradingRecordsPublicPath)
            .borrow() == nil {
            // link the trading records to the public path
            acct.capabilities.unpublish(FRC20TradingRecord.TradingRecordsPublicPath)
            let cap = acct.capabilities.storage.issue<&FRC20TradingRecord.TradingRecords>(FRC20TradingRecord.TradingRecordsStoragePath)
            acct.capabilities.publish(cap, at: FRC20TradingRecord.TradingRecordsPublicPath)
        }

        // borrow the hooks reference
        let hooksRef = acct.storage
            .borrow<auth(FRC20FTShared.Manage) &FRC20FTShared.Hooks>(from: FRC20FTShared.TransactionHookStoragePath)
            ?? panic("The hooks were not created")

        // add the trading records to the hooks, if it is not added yet
        // get the public capability of the trading record hook
        let tradingRecordsCap = acct
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
}
