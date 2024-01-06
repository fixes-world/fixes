import "Fixes"
import "FRC20AccountsPool"
import "FRC20Indexer"
import "FRC20FTShared"
import "FRC20TradingRecord"
import "FRC20Marketplace"

pub contract FRC20MarketManager {
    /* --- Events --- */

    /// Event emitted when the contract is initialized
    pub event ContractInitialized()

    /// Event emitted when a new market is enabled
    pub event NewMarketEnabled(tick: String, address: Address, by: Address)

    /* --- Variable, Enums and Structs --- */

    pub let FRC20MarketManagerStoragePath: StoragePath
    pub let FRC20MarketManagerPublicPath: PublicPath

    /* --- Interfaces & Resources --- */

    /// The resource manager for the FRC20MarketManager
    ///
    pub resource Manager {
        access(all)
        let tick: String

        init(_ tick: String) {
            self.tick = tick
        }

        // TODO: implement the details
    }

    // --- Public methods ---

    access(all)
    fun enableAndCreateFRC20Market(
        ins: &Fixes.Inscription,
        newAccount: Capability<&AuthAccount>,
    ): @Manager {
        // singletoken resources
        let frc20Indexer = FRC20Indexer.getIndexer()
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // inscription data
        let meta = frc20Indexer.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
        let tick = meta["tick"]?.toLower() ?? panic("The token tick is not found")

        // Check if the token is already registered
        let tokenMeta = frc20Indexer.getTokenMeta(tick: tick) ?? panic("The token is not registered")
        /// Check if the market is already enabled
        assert(
            acctsPool.getFRC20MarketAddress(tick: tick) == nil,
            message: "The market is already enabled"
        )

        // execute the inscription to ensure you are the deployer of the token
        let ret = frc20Indexer.executeByDeployer(ins: ins)
        assert(
            ret == true,
            message: "The inscription execution failed"
        )

        // create the account for the market at the accounts pool
        acctsPool.setupNewChildForTick(
            type: FRC20AccountsPool.ChildAccountType.Market,
            tick: tick,
            newAccount
        )

        // try to borrow the account to check if it was created
        let childAcctRef = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.Market, tick: tick)
            ?? panic("The market account was not created")

        // ensure market is not in the account
        assert(
            childAcctRef.borrow<&FRC20Marketplace.Market>(from: FRC20Marketplace.FRC20MarketStoragePath) == nil,
            message: "The market is already in the account"
        )
        // create the market and save it in the account
        let market <- FRC20Marketplace.createMarket(tick)

        // save the market in the account
        childAcctRef.save(<- market, to: FRC20Marketplace.FRC20MarketStoragePath)
        // link the market to the public path
        childAcctRef.unlink(FRC20Marketplace.FRC20MarketPublicPath)
        childAcctRef.link<&FRC20Marketplace.Market{FRC20Marketplace.MarketPublic}>(
            FRC20Marketplace.FRC20MarketPublicPath,
            target: FRC20Marketplace.FRC20MarketStoragePath
        )

        // create the hooks and save it in the account
        if childAcctRef.borrow<&AnyResource>(from: FRC20FTShared.TransactionHookStoragePath) == nil {
            let hooks <- FRC20FTShared.createHooks()
            childAcctRef.save(<- hooks, to: FRC20FTShared.TransactionHookStoragePath)
            // link the hooks to the public path
            childAcctRef.unlink(FRC20FTShared.TransactionHookPublicPath)
            childAcctRef.link<&FRC20FTShared.Hooks{FRC20FTShared.TransactionHook}>(
                FRC20FTShared.TransactionHookPublicPath,
                target: FRC20FTShared.TransactionHookStoragePath
            )
        }

        let hooksRef = childAcctRef.borrow<&FRC20FTShared.Hooks>(from: FRC20FTShared.TransactionHookStoragePath)
            ?? panic("The hooks were not created")

        // create trading record hook and save it in the account
        if childAcctRef.borrow<&AnyResource>(from: FRC20TradingRecord.TradingRecordingHookStoragePath) == nil {
            let tradingRecord <- FRC20TradingRecord.createTradingRecordingHook()
            childAcctRef.save(<- tradingRecord, to: FRC20TradingRecord.TradingRecordingHookStoragePath)
            // link the trading record to the public path
            childAcctRef.unlink(FRC20TradingRecord.TradingRecordingHookPublicPath)
            // Trading recording hook is one of the hooks
            childAcctRef.link<&FRC20TradingRecord.TradingRecordingHook{FRC20FTShared.TransactionHook}>(
                FRC20TradingRecord.TradingRecordingHookPublicPath,
                target: FRC20TradingRecord.TradingRecordingHookStoragePath
            )
        }
        // add the trading record hook to the hooks
        // get the public capability of the trading record hook
        let tradingRecordingCap = childAcctRef
            .getCapability<&FRC20TradingRecord.TradingRecordingHook{FRC20FTShared.TransactionHook}>(
                FRC20TradingRecord.TradingRecordingHookPublicPath
            )
        assert(tradingRecordingCap.check(), message: "The trading record hook is not valid")
        // add the trading record hook to the hooks
        hooksRef.addHook(tradingRecordingCap)

        // create trading records and save it in the account
        if childAcctRef.borrow<&AnyResource>(from: FRC20TradingRecord.TradingRecordsStoragePath) == nil {
            let tradingRecords <- FRC20TradingRecord.createTradingRecords(tick)
            childAcctRef.save(<- tradingRecords, to: FRC20TradingRecord.TradingRecordsStoragePath)
            // link the trading records to the public path
            childAcctRef.unlink(FRC20TradingRecord.TradingRecordsPublicPath)
            childAcctRef.link<&FRC20TradingRecord.TradingRecords{FRC20TradingRecord.TradingRecordsPublic, FRC20TradingRecord.TradingStatusViewer}>(
                FRC20TradingRecord.TradingRecordsPublicPath,
                target: FRC20TradingRecord.TradingRecordsStoragePath
            )
        }

        // emit the event
        emit NewMarketEnabled(
            tick: tick,
            address: childAcctRef.address,
            by: ins.owner!.address
        )

        // return the market manager
        return <- create Manager(tick)
    }

    init() {
        let identifier = "FRC20MarketManager_".concat(self.account.address.toString())
        self.FRC20MarketManagerStoragePath = StoragePath(identifier: identifier)!
        self.FRC20MarketManagerPublicPath = PublicPath(identifier: identifier)!

        emit ContractInitialized()
    }
}
