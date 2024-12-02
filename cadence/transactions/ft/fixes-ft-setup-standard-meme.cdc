import "FlowToken"
import "FungibleToken"
import "HybridCustody"
// Fixes Imports
import "FungibleTokenManager"
import "Fixes"
import "FixesInscriptionFactory"
import "FRC20FTShared"

transaction(
    coinAddress: Address,
    lotteryEpochDays: UInt8?,
) {
    let setupTradablePoolIns: auth(Fixes.Extractable) &Fixes.Inscription
    let setupLotteryPoolIns: auth(Fixes.Extractable) &Fixes.Inscription

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

        // Get a reference to the signer's stored vault
        let flowVaultRef = acct.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        let tokenInfo = FungibleTokenManager.buildFixesTokenInfo(coinAddress, nil)
            ?? panic("Token doesn't exist in address: ".concat(coinAddress.toString()))
        let tickerName = tokenInfo.view.accountKey

        /** ------------- Create the Inscription 2 - Start ------------- */
        let tradablePoolInsDataStr = FixesInscriptionFactory.buildPureExecuting(tick: tickerName, usage: "setup-tradable-pool", {})
        // Create the Inscription first
        let newInsId = FixesInscriptionFactory.createAndStoreFrc20Inscription(
            tradablePoolInsDataStr,
            <- flowVaultRef.withdraw(
                amount: FixesInscriptionFactory.estimateFrc20InsribeCost(tradablePoolInsDataStr)
            ) as! @FlowToken.Vault,
            store
        )
        // borrow a reference to the new Inscription
        self.setupTradablePoolIns = store.borrowInscriptionWritableRef(newInsId)
            ?? panic("Could not borrow a reference to the newly created Inscription!")
        /** ------------- End --------------------------------------- */

        /** ------------- Create the Inscription 2 - Start ------------- */
        let setupLotteryStr = FixesInscriptionFactory.buildPureExecuting(tick: tickerName, usage: "setup-lottery", {})
        // Create the Inscription first
        let newInsId2 = FixesInscriptionFactory.createAndStoreFrc20Inscription(
            setupLotteryStr,
            <- flowVaultRef.withdraw(amount: FixesInscriptionFactory.estimateFrc20InsribeCost(setupLotteryStr)) as! @FlowToken.Vault,
            store
        )
        // borrow a reference to the new Inscription
        self.setupLotteryPoolIns = store.borrowInscriptionWritableRef(newInsId2)
            ?? panic("Could not borrow a reference to the newly created Inscription!")
        /** ------------- End --------------------------------------- */
    }

    execute {
        // Setup Tradable Pool
        FungibleTokenManager.setupTradablePoolResources(self.setupTradablePoolIns)
        // Setup Lottery Pool
        FungibleTokenManager.setupLotteryPool(self.setupLotteryPoolIns, epochDays: lotteryEpochDays ?? 3)
    }
}
