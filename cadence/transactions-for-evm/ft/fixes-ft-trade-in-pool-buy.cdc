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
import "EVMAgent"

transaction(
    symbol: String,
    cost: UFix64?,
    amount: UFix64?,
    hexPublicKey: String,
    hexSignature: String,
    timestamp: UInt64,
) {
    let tickerName: String
    let ins: &Fixes.Inscription
    let pool: &FixesTradablePool.TradableLiquidityPool{FixesTradablePool.LiquidityPoolInterface, FixesFungibleTokenInterface.IMinterHolder, FungibleToken.Receiver}
    let recipient: &{FungibleToken.Receiver}

    prepare(signer: AuthAccount) {
        /** ------------- EVMAgency: verify and borrow AuthAccount ------------- */
        let agency = EVMAgent.borrowAgencyByEVMPublicKey(hexPublicKey)
            ?? panic("Could not borrow a reference to the EVMAgency!")

        let acct = agency.verifyAndBorrowEntrustedAccount(
            methodFingerprint: "fixes-ft-trade-in-pool-buy(String|UFix64|UFix64)",
            params: [symbol, cost?.toString() ?? "", amount?.toString() ?? ""],
            hexPublicKey: hexPublicKey,
            hexSignature: hexSignature,
            timestamp: timestamp
        )
        /** ------------- EVMAgency: End --------------------------------------- */

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

        /** ------------- Create the Inscription - Start ------------- */
        let fields: {String: String} = {}

        let dataStr = FixesInscriptionFactory.buildPureExecuting(
            tick: self.tickerName,
            usage: "init",
            fields
        )
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

        /// calculate the cost or amount
        var costAmount = cost
        if costAmount == nil || costAmount! == 0.0 {
            assert(
                amount != nil,
                message: "Either cost or amount should be provided!"
            )
            costAmount = self.pool.getBuyPriceAfterFee(amount!)
        }
        assert(
            costAmount != nil,
            message: "Cost amount should be provided!"
        )
        let costVault <- flowVaultRef.withdraw(amount: costAmount!)
        self.ins.deposit(<- (costVault as! @FlowToken.Vault))
    }

    execute {
        // buy tokens
        self.pool.buyTokens(self.ins, amount, recipient: self.recipient)
    }
}
