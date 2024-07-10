import "FlowToken"
import "FungibleToken"
import "MetadataViews"
import "ViewResolver"
// Fixes Imports
import "Fixes"
import "FixesInscriptionFactory"
import "FixesFungibleTokenInterface"
import "FRC20FTShared"
import "FixesHeartbeat"
import "FRC20TradingRecord"
import "FixesAvatar"
import "FRC20AccountsPool"
import "FixesTradablePool"

transaction(
    symbol: String,
    burningTick: String,
    burningAmount: UFix64,
    extraCost: UFix64,
) {
    let tickerName: String
    let ins: &Fixes.Inscription
    let pool: &FixesTradablePool.TradableLiquidityPool{FixesTradablePool.LiquidityPoolInterface, FixesFungibleTokenInterface.IMinterHolder, FungibleToken.Receiver}
    let recipient: &{FungibleToken.Receiver}

    prepare(acct: AuthAccount) {
        /** ------------- Prepare the Inscription Store - Start ---------------- */
        let storePath = Fixes.getFixesStoreStoragePath()
        if acct.borrow<&Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        let store = acct.borrow<&Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */

        /** ------------- Start -- TradingRecords General Initialization -------------  */
        // Ensure hooks are initialized
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

        // borrow the hooks reference
        let hooksRef = acct.borrow<&FRC20FTShared.Hooks>(from: FRC20FTShared.TransactionHookStoragePath)
            ?? panic("The hooks were not created")

        // Ensure Trading Records is initialized
        if acct.borrow<&AnyResource>(from: FRC20TradingRecord.TradingRecordsStoragePath) == nil {
            let tradingRecords <- FRC20TradingRecord.createTradingRecords(nil)
            acct.save(<- tradingRecords, to: FRC20TradingRecord.TradingRecordsStoragePath)
            // link the trading records to the public path
            acct.unlink(FRC20TradingRecord.TradingRecordsPublicPath)
            acct.link<&FRC20TradingRecord.TradingRecords{FRC20TradingRecord.TradingRecordsPublic, FRC20TradingRecord.TradingStatusViewer, FRC20FTShared.TransactionHook}>(FRC20TradingRecord.TradingRecordsPublicPath, target: FRC20TradingRecord.TradingRecordsStoragePath)
        }

        // Ensure trading record hook is added to the hooks
        // get the public capability of the trading record hook
        let tradingRecordsCap = acct
            .getCapability<&FRC20TradingRecord.TradingRecords{FRC20TradingRecord.TradingRecordsPublic, FRC20TradingRecord.TradingStatusViewer, FRC20FTShared.TransactionHook}>(
                FRC20TradingRecord.TradingRecordsPublicPath
            )
        assert(tradingRecordsCap.check(), message: "The trading record hook is not valid")
        // get the reference of the trading record hook
        let recordsRef = tradingRecordsCap.borrow() ?? panic("The trading record hook is not valid")
        if !hooksRef.hasHook(recordsRef.getType()) {
            hooksRef.addHook(tradingRecordsCap)
        }

        // Ensure Fixes Avatar is initialized
        if acct.borrow<&AnyResource>(from: FixesAvatar.AvatarStoragePath) == nil {
            acct.save(<- FixesAvatar.create(), to: FixesAvatar.AvatarStoragePath)
            // link the avatar to the public path
            acct.unlink(FixesAvatar.AvatarPublicPath)
            acct.link<&FixesAvatar.Profile{FixesAvatar.ProfilePublic, FRC20FTShared.TransactionHook, MetadataViews.Resolver}>(FixesAvatar.AvatarPublicPath, target: FixesAvatar.AvatarStoragePath)
        }
        let profileCap = FixesAvatar.getProfileCap(acct.address)
        assert(profileCap.check(), message: "The profile is not valid")
        let profileRef = profileCap.borrow() ?? panic("The profile is not valid")
        if !hooksRef.hasHook(profileRef.getType()) {
            hooksRef.addHook(profileCap)
        }
        /** ------------- End -----------------------------------------------------------------  */

        // Get a reference to the signer's stored vault
        let flowVaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        self.tickerName = "$".concat(symbol)

        /** ------------- Create the Inscription - Start ------------- */
        let dataStr = FixesInscriptionFactory.buildBurnFRC20(tick: burningTick, amt: burningAmount)
        // estimate the required storage
        let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(dataStr)
        // get reserved cost
        let flowToReserve <- (flowVaultRef.withdraw(amount: estimatedReqValue) as! @FlowToken.Vault)
        // Create the Inscription first
        let newInsId = FixesInscriptionFactory.createAndStoreFrc20Inscription(
            dataStr,
            <- flowToReserve,
            store
        )
        // borrow a reference to the new Inscription
        self.ins = store.borrowInscriptionWritableRef(newInsId)
            ?? panic("Could not borrow a reference to the newly created Inscription!")
        /** ------------- End --------------------------------------- */

        /** ------------- Prepare the pool reference - Start -------------- */
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        let tokenFTAddr = acctsPool.getFTContractAddress(self.tickerName)
            ?? panic("Could not get the Fungible Token Address!")
        self.pool = FixesTradablePool.borrowTradablePool(tokenFTAddr)
            ?? panic("Could not get the Pool Resource!")
        /** ------------- End ----------------------------------------------- */

        /** ------------- Prepare the token recipient - Start -------------- */
        let tokenVaultData = self.pool.getTokenVaultData()
        // ensure storage path
        if acct.borrow<&AnyResource>(from: tokenVaultData.storagePath) == nil {
            // save the empty vault
            acct.save(<- tokenVaultData.createEmptyVault(), to: tokenVaultData.storagePath)
            // save the public capability

            // @deprecated after Cadence 1.0
            // Create a public capability to the stored Vault that exposes
            // the `deposit` method through the `Receiver` interface.
            acct.link<&{FungibleToken.Receiver}>(tokenVaultData.receiverPath, target: tokenVaultData.storagePath)
            // Create a public capability to the stored Vault that only exposes
            // the `balance` field and the `resolveView` method through the `Balance` interface
            acct.link<&{FungibleToken.Balance, MetadataViews.Resolver, FixesFungibleTokenInterface.Metadata}>(
                tokenVaultData.metadataPath,
                target: tokenVaultData.storagePath
            )
        }

        self.recipient = acct.getCapability<&{FungibleToken.Receiver}>(tokenVaultData.receiverPath)
            .borrow()
            ?? panic("Could not borrow a reference to the recipient's Receiver!")
        /** ------------- End ----------------------------------------------- */

        // withdraw the cost to ins
        if extraCost > 0.0 {
            let costVault <- flowVaultRef.withdraw(amount: extraCost)
            self.ins.deposit(<- (costVault as! @FlowToken.Vault))
        }
    }

    execute {
        self.pool.buyTokens(self.ins, nil, recipient: self.recipient)
    }
}
