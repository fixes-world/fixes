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
    amount: UFix64,
) {
    let tickerName: String
    let pool: &FixesTradablePool.TradableLiquidityPool
    let provider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
    let recipient: &{FungibleToken.Receiver}

    prepare(acct: auth(Storage, Capabilities) &Account) {
        /** ------------- Prepare the Inscription Store - Start ---------------- */
        let storePath = Fixes.getFixesStoreStoragePath()
        if acct.storage
            .borrow<auth(Fixes.Manage) &Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.storage.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        let store = acct.storage
            .borrow<auth(Fixes.Manage) &Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */

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

        self.tickerName = "$".concat(symbol)

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
        if acct.storage.borrow<&AnyResource>(from: tokenVaultData.storagePath) == nil {
            // save the empty vault
            acct.storage.save(<- tokenVaultData.createEmptyVault(), to: tokenVaultData.storagePath)
        }

        // save the public capability to the stored vault
        if acct.capabilities.get<&{FungibleToken.Receiver}>(tokenVaultData.receiverPath).borrow() == nil {
            acct.capabilities.unpublish(tokenVaultData.receiverPath)
            // Create a public capability to the stored Vault that exposes
            // the `deposit` method through the `Receiver` interface.
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&{FungibleToken.Receiver}>(tokenVaultData.storagePath),
                at: tokenVaultData.receiverPath
            )
        }

        if acct.capabilities.get<&{FungibleToken.Vault, FixesFungibleTokenInterface.Vault}>(tokenVaultData.metadataPath).borrow() == nil {
            acct.capabilities.unpublish(tokenVaultData.metadataPath)
            // Create a public capability to the stored Vault that only exposes
            // the `balance` field and the `resolveView` method through the `Balance` interface
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&{FungibleToken.Vault, FixesFungibleTokenInterface.Vault}>(tokenVaultData.storagePath),
                at: tokenVaultData.metadataPath
            )
        }
        /** ------------- End ----------------------------------------------- */

        // Get a reference to the signer's stored vault
        self.provider = acct.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        self.recipient = acct.capabilities.get<&{FungibleToken.Receiver}>(tokenVaultData.receiverPath).borrow()
            ?? panic("Could not get the recipient's Receiver reference!")
    }

    execute {
        // sell tokens
        self.pool.quickSwapToken(
            <- self.provider.withdraw(amount: amount),
            self.recipient
        )
    }
}
