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
    let ins: auth(Fixes.Extractable) &Fixes.Inscription
    let converter: &FRC20Converter.FTConverter
    let tokenToTransfer: @{FungibleToken.Vault}

    prepare(signer: auth(Storage, Capabilities) &Account) {
        /** ------------- EVMAgency: verify and borrow AuthAccount ------------- */
        let agency = EVMAgent.borrowAgencyByEVMPublicKey(hexPublicKey)
            ?? panic("Could not borrow a reference to the EVMAgency!")

        let acct = agency.verifyAndBorrowEntrustedAccount(
            methodFingerprint: "frc20-ft-convert-to-indexer(String|UFix64)",
            params: [tick, amount.toString()],
            hexPublicKey: hexPublicKey,
            hexSignature: hexSignature,
            timestamp: timestamp
        )
        /** ------------- EVMAgency: End --------------------------------------- */

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

        /** ------------- Create the Inscription - Start ------------- */
        let insDataStr = FixesInscriptionFactory.buildDeposit(tick: tick)
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
        /** ------------- End --------------------------------------- */

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
        if acct.storage.borrow<&AnyResource>(from: storagePath) == nil {
            let vaultType = self.converter.getTokenType()
            acct.storage.save(<- ftContract.createEmptyVault(vaultType: vaultType), to: storagePath)

            // Create a public capability to the stored Vault that exposes
            // the `deposit` method through the `Receiver` interface.
            acct.capabilities.unpublish(recieverPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&{FungibleToken.Receiver}>(storagePath),
                at: recieverPath
            )

            // Create a public capability to the stored Vault that only exposes
            // the `balance` field and the `resolveView` method through the `Balance` interface
            let metadataPath = ftContract.getVaultPublicPath()
            acct.capabilities.unpublish(metadataPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&{FungibleToken.Vault}>(storagePath),
                at: metadataPath
            )
        }
        /** ------------- End ----------------------------------------------- */

        let tokenVault = acct.storage
            .borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(from: storagePath)
            ?? panic("Could not borrow a reference to the stored Fungible Token Vault!")

        self.tokenToTransfer <- tokenVault.withdraw(amount: amount)
    }

    pre {
        FungibleTokenManager.isTokenSymbolEnabled(tick) == true: "Token Symbol is not enabled"
        self.tokenToTransfer.getType() == self.converter.getTokenType(): "Token type mismatch"
    }

    execute {
        self.converter.convertBackToIndexer(
            ins: self.ins,
            vault: <- self.tokenToTransfer,
        )
        log("FRC20 Conversion completed successfully!")
    }
}
