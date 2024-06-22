import "FlowToken"
import "FungibleToken"
import "MetadataViews"
import "ViewResolver"
// Fixes Imports
import "Fixes"
import "FixesInscriptionFactory"
import "FixesFungibleTokenInterface"
import "FRC20FTShared"
import "FRC20AccountsPool"
import "FixesTradablePool"

transaction(
    symbol: String,
    amount: UFix64,
) {
    let tickerName: String
    let pool: &FixesTradablePool.TradableLiquidityPool{FixesTradablePool.LiquidityPoolInterface, FixesFungibleTokenInterface.IMinterHolder, FungibleToken.Receiver}
    let provider: &{FungibleToken.Provider}
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
        /** ------------- End ----------------------------------------------- */

        self.provider = acct.borrow<&{FungibleToken.Provider}>(from: tokenVaultData.storagePath)
            ?? panic("Could not borrow a reference to the Token Provider!")

        self.recipient = Fixes.borrowFlowTokenReceiver(acct.address)
            ?? panic("Could not get the FlowToken Receiver!")
    }

    execute {
        // sell tokens
        self.pool.quickSwapToken(
            <- self.provider.withdraw(amount: amount),
            self.recipient
        )
    }
}
