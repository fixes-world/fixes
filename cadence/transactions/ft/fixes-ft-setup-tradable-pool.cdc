import "FlowToken"
import "FungibleToken"
import "HybridCustody"
// Fixes Imports
import "FungibleTokenManager"
import "Fixes"
import "FixesInscriptionFactory"
import "FRC20FTShared"

transaction(
    symbol: String,
    tradablePoolSupply: UFix64,
    creatorFeePercentage: UFix64,
    freeMintAmount: UFix64,
) {
    let tickerName: String
    let setupTradablePoolIns: &Fixes.Inscription?

    prepare(acct: AuthAccount) {
        /** ------------- Prepare the Inscription Store - Start ---------------- */
        let storePath = Fixes.getFixesStoreStoragePath()
        if acct.borrow<&Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        let store = acct.borrow<&Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */

        // Get a reference to the signer's stored vault
        let flowVaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        self.tickerName = "$".concat(symbol)

        /** ------------- Create the Inscription 2 - Start ------------- */
        let fields: {String: String} = {}
        if tradablePoolSupply > 0.0 {
            fields["supply"] = tradablePoolSupply.toString()
        }
        if creatorFeePercentage > 0.0 {
            fields["feePerc"] = creatorFeePercentage.toString()
        }
        if freeMintAmount > 0.0 {
            fields["freeAmount"] = freeMintAmount.toString()
        }
        let tradablePoolInsDataStr = FixesInscriptionFactory.buildPureExecuting(
            tick: self.tickerName,
            usage: "setup-tradable-pool",
            fields
        )
        // estimate the required storage
        let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(tradablePoolInsDataStr)
        // get reserved cost
        let flowToReserve <- (flowVaultRef.withdraw(amount: estimatedReqValue) as! @FlowToken.Vault)
        // Create the Inscription first
        let newInsId = FixesInscriptionFactory.createAndStoreFrc20Inscription(
            tradablePoolInsDataStr,
            <- flowToReserve,
            store
        )
        // borrow a reference to the new Inscription
        self.setupTradablePoolIns = store.borrowInscriptionWritableRef(newInsId)
            ?? panic("Could not borrow a reference to the newly created Inscription!")
        /** ------------- End --------------------------------------- */
    }

    pre {
        FungibleTokenManager.isTokenSymbolEnabled(self.tickerName) == true: "Token is already enabled"
        self.setupTradablePoolIns != nil: "Invalid Tradable Pool Inscription"
    }

    execute {
        FungibleTokenManager.setupTradablePoolResources(self.setupTradablePoolIns!)
    }
}
