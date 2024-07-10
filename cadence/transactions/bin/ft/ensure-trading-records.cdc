import "FRC20FTShared"
import "FRC20TradingRecord"
import "FixesTradablePool"
import "FixesHeartbeat"

transaction() {
    prepare(acct: AuthAccount) {
        let centerStoragePath = FixesTradablePool.getTradingCenterStoragePath()
        if acct.borrow<&AnyResource>(from: centerStoragePath) == nil {
            acct.save(<- FixesTradablePool.createCenter(), to: centerStoragePath)
            acct.link<&FixesTradablePool.TradingCenter{FixesTradablePool.CeneterPublic}>(
                FixesTradablePool.getTradingCenterPublicPath(),
                target: centerStoragePath
            )
        }

        // create the hooks and save it in the account
        if acct.borrow<&AnyResource>(from: FRC20FTShared.TransactionHookStoragePath) == nil {
            let hooks <- FRC20FTShared.createHooks()
            acct.save(<- hooks, to: FRC20FTShared.TransactionHookStoragePath)
        }

        // link the hooks to the public path
        if acct
            .getCapability<&FRC20FTShared.Hooks{FRC20FTShared.TransactionHook, FixesHeartbeat.IHeartbeatHook}>(FRC20FTShared.TransactionHookPublicPath)
            .borrow() == nil {
            // link the hooks to the public path
            acct.unlink(FRC20FTShared.TransactionHookPublicPath)
            acct.link<&FRC20FTShared.Hooks{FRC20FTShared.TransactionHook, FixesHeartbeat.IHeartbeatHook}>(
                FRC20FTShared.TransactionHookPublicPath,
                target: FRC20FTShared.TransactionHookStoragePath
            )
        }

        // ensure trading records are available
        if acct.borrow<&AnyResource>(from: FRC20TradingRecord.TradingRecordsStoragePath) == nil {
            let tradingRecords <- FRC20TradingRecord.createTradingRecords(nil)
            acct.save(<- tradingRecords, to: FRC20TradingRecord.TradingRecordsStoragePath)
        }

        if acct
            .getCapability<&FRC20TradingRecord.TradingRecords{FRC20TradingRecord.TradingRecordsPublic, FRC20TradingRecord.TradingStatusViewer, FRC20FTShared.TransactionHook}>(FRC20TradingRecord.TradingRecordsPublicPath)
            .borrow() == nil {
            // link the trading records to the public path
            acct.unlink(FRC20TradingRecord.TradingRecordsPublicPath)
            acct.link<&FRC20TradingRecord.TradingRecords{FRC20TradingRecord.TradingRecordsPublic, FRC20TradingRecord.TradingStatusViewer, FRC20FTShared.TransactionHook}>(
                FRC20TradingRecord.TradingRecordsPublicPath,
                target: FRC20TradingRecord.TradingRecordsStoragePath
            )
        }

        // borrow the hooks reference
        let hooksRef = acct.borrow<&FRC20FTShared.Hooks>(from: FRC20FTShared.TransactionHookStoragePath)
            ?? panic("The hooks were not created")

        // add the trading records to the hooks, if it is not added yet
        // get the public capability of the trading record hook
        let tradingRecordsCap = acct
            .getCapability<&FRC20TradingRecord.TradingRecords{FRC20TradingRecord.TradingRecordsPublic, FRC20TradingRecord.TradingStatusViewer, FRC20FTShared.TransactionHook}>(
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
