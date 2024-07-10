import "FlowToken"
import "FungibleToken"
import "MetadataViews"
// Fixes Imports
import "Fixes"
import "FixesInscriptionFactory"
import "FixesFungibleTokenInterface"
import "FungibleTokenManager"
import "FRC20FTShared"
import "FRC20AccountsPool"
import "FRC20Converter"
import "EVMAgent"

transaction(
    tick: String,
    amount: UFix64,
    hexPublicKey: String,
    hexSignature: String,
    timestamp: UInt64,
) {
    let ins: &Fixes.Inscription
    let converter: &FRC20Converter.FTConverter{FRC20Converter.IConverter}
    let tokenReceiver: &{FungibleToken.Receiver}

    prepare(signer: AuthAccount) {
        /** ------------- EVMAgency: verify and borrow AuthAccount ------------- */
        let agency = EVMAgent.borrowAgencyByEVMPublicKey(hexPublicKey)
            ?? panic("Could not borrow a reference to the EVMAgency!")

        let acct = agency.verifyAndBorrowEntrustedAccount(
            methodFingerprint: "frc20-ft-convert-from-indexer(String|UFix64)",
            params: [tick, amount.toString()],
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

        /** ------------- Create the Inscription - Start ------------- */
        let insDataStr = FixesInscriptionFactory.buildFungibleTokenConvertFromIndexer(tick: tick, amount: amount)
        // estimate the required storage
        let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(insDataStr)
        // get reserved cost
        let flowToReserve <- (flowVaultRef.withdraw(amount: estimatedReqValue) as! @FlowToken.Vault)
        // Create the Inscription first
        let newInsId = FixesInscriptionFactory.createAndStoreFrc20Inscription(
            insDataStr,
            <- flowToReserve,
            store
        )
        // borrow a reference to the new Inscription
        self.ins = store.borrowInscriptionWritableRef(newInsId)
            ?? panic("Could not borrow a reference to the newly created Inscription!")
        /** ------------- End ----------------------------------------- */

        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        /** ------------- Prepare the FRC20 Converter - Start ---------------- */
        let tickAddr = acctsPool.getFTContractAddress(tick)
            ?? panic("Could not get the FRC20 contract address for the given token ticker: ".concat(tick))

        self.converter = FRC20Converter.borrowConverter(tickAddr)
            ?? panic("Could not load the FRC20Converter for the given token symbol")
        /** ------------- End -------------------------------------------------- */

        /** ------------- Prepare the Token Vault - Start ---------------- */
        let ftContract = acctsPool.borrowFTContract(tick)
            ?? panic("Could not get the FRC20 contract for the given token ticker: ".concat(tick))
        let storagePath = ftContract.getVaultStoragePath()
        let recieverPath = ftContract.getReceiverPublicPath()

        // ensure the Vault Resource exists
        if acct.borrow<&AnyResource>(from: storagePath) == nil {
            acct.save(<- ftContract.createEmptyVault(), to: storagePath)

            // @deprecated after Cadence 1.0
            // Create a public capability to the stored Vault that exposes
            // the `deposit` method through the `Receiver` interface.
            acct.unlink(recieverPath)
            acct.link<&{FungibleToken.Receiver}>(recieverPath, target: storagePath)

            // Create a public capability to the stored Vault that only exposes
            // the `balance` field and the `resolveView` method through the `Balance` interface
            let metadataPath = ftContract.getVaultPublicPath()
            acct.unlink(metadataPath)
            acct.link<&{FungibleToken.Balance, MetadataViews.Resolver, FixesFungibleTokenInterface.Metadata}>(
                metadataPath,
                target: storagePath
            )
        }
        /** ------------- End ----------------------------------------------- */

        // Borrow a reference to the stored Vault
        self.tokenReceiver = acct.getCapability<&{FungibleToken.Receiver}>(recieverPath).borrow()
            ?? panic("Could not borrow a reference to the token receiver")

        let supportedTypes = self.tokenReceiver.getSupportedVaultTypes()
        assert(
            supportedTypes[self.converter.getTokenType()] == true,
            message: "Token Receiver does not support the given token type"
        )
    }

    pre {
        FungibleTokenManager.isTokenSymbolEnabled(tick) == true: "Token Symbol is not enabled"
    }

    execute {
        self.converter.convertFromIndexer(
            ins: self.ins,
            recipient: self.tokenReceiver
        )
        log("FRC20 Conversion completed successfully!")
    }
}
