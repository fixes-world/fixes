/**

> Author: FIXeS World <https://fixes.world/>

# FRC20FungibleToken

This is the fungible token contract for all FRC20 tokens. It is the template contract that is used to deploy.

*/

import "FungibleToken"
import "ViewResolver"
import "MetadataViews"
import "FungibleTokenMetadataViews"
// Fixes imports
import "Fixes"
import "FixesTraits"
import "FixesAssetGenes"
import "FRC20FTShared"
import "FRC20Indexer"
import "FRC20AccountsPool"
import "FRC20Agents"

/// This is the template source for a FRC20 Fungible Token
/// The contract is deployed in the child account of the FRC20AccountsPool
/// All real FRC20 tokens are deployed in the FRC20Indexer, and
/// the FT Token issued by the FRC20FTShared.Change
access(all) contract FRC20FungibleToken: FungibleToken, ViewResolver {
    // ------ Events -------

    /// The event that is emitted when the contract is created
    access(all) event TokensInitialized(initialSupply: UFix64)

    /// The event that is emitted when tokens are withdrawn from a Vault
    access(all) event TokensWithdrawn(amount: UFix64, from: Address?)

    /// The event that is emitted when tokens are deposited to a Vault
    access(all) event TokensDeposited(amount: UFix64, to: Address?)

    /// The event that is emitted when new tokens are minted
    access(all) event TokensConvertedToStanard(amount: UFix64, by: Address)

    /// The event that is emitted when tokens are destroyed
    access(all) event TokensConvertedToFRC20(amount: UFix64, by: Address)

    /// The event that is emitted when the metadata is updated
    access(all) event TokensMetadataInitialized(typeIdentifier: String, id: String, value: String, owner: Address?)

    /// The event that is emitted when the metadata is updated
    access(all) event TokensMetadataUpdated(typeIdentifier: String, id: String, value: String, owner: Address?)

    /// The event that is emitted when the dna metadata is updated
    access(all) event TokenDNAGenerated(identifier: String, value: String, mutatableAmount: UInt64, owner: Address?)

    /// The event that is emitted when the dna mutatable is updated
    access(all) event TokenDNAMutatableCharged(identifier: String, mutatableAmount: UInt64, owner: Address?)

    /// -------- Parameters --------

    /// Total supply of FRC20FungibleToken in existence
    /// This value is only a record of the quantity existing in the form of Flow Fungible Tokens.
    /// It does not represent the total quantity of the token that has been minted.
    /// The total quantity of the token that has been minted is loaded from the FRC20Indexer.
    access(all)
    var totalSupply: UFix64
    access(all)
    var totalFungibleTokenSupply: UFix64

    /// -------- Resources and Interfaces --------

    /// The public interface for the FRC20 FT
    ///
    access(all) resource interface FRC20Metadata {
        /// Is the vault valid
        access(all)
        view fun isValidVault(): Bool
        /// Get the ticker name of the token
        access(all)
        view fun getTickerName(): String
        /// Get the change's from address
        access(all)
        view fun getSourceAddress(): Address
        /// Get mergeable metadata keys
        access(all)
        view fun getMergeableKeys(): [Type]
        /// Get the mergeable metadata by key
        access(all)
        view fun getMergeableData(_ key: Type): {FixesTraits.MergeableData}?
        /// Get DNA identifier
        access(all)
        view fun getDNAIdentifier(): String
        /// Get the total mutatable amount of DNA
        access(all)
        view fun getDNAMutatableAmount(): UInt64
        /// DNA charging
        access(all)
        fun chargeDNAMutatableAttempts(_ ins: &Fixes.Inscription)
    }

    /// Each user stores an instance of only the Vault in their storage
    /// The functions in the Vault and governed by the pre and post conditions
    /// in FungibleToken when they are called.
    /// The checks happen at runtime whenever a function is called.
    ///
    /// Resources can only be created in the context of the contract that they
    /// are defined in, so there is no way for a malicious user to create Vaults
    /// out of thin air. A special Minter resource needs to be defined to mint
    /// new tokens.
    ///
    access(all) resource Vault: FRC20Metadata, FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance, MetadataViews.Resolver {
        /// The total balance of this vault
        access(all)
        var balance: UFix64
        // The change should be inside the vault
        access(self)
        var change: @FRC20FTShared.Change?
        /// Metadata: Type of MergeableData => MergeableData
        access(self)
        let metadata: {Type: {FixesTraits.MergeableData}}

        /// Initialize the balance at resource creation time
        init(balance: UFix64) {
            pre {
                balance == 0.0: "For initialization, the balance must be zero"
            }
            // Initialize with a zero balance and nil change
            self.balance = balance
            self.change <- nil
            self.metadata = {}
        }

        /// @deprecated after Cadence 1.0
        destroy() {
            // You can not destroy a Change with a non-zero balance
            pre {
                self.balance == UFix64(0): "Balance must be zero for destroy"
            }
            destroy self.change
        }

        /// ----- Internal Methods -----

        /// Borrow the change reference
        ///
        access(contract)
        fun borrowChangeRef(): &FRC20FTShared.Change? {
            return &self.change as &FRC20FTShared.Change?
        }

        /// The initialize method for the Vault, a Vault for FRC20 must be initialized with a Change
        ///
        access(contract)
        fun initialize(
            _ change: @FRC20FTShared.Change,
            _ isInitedFromIndexer: Bool
        ) {
            pre {
                self.change == nil: "The change must be nil"
                change.isBackedByVault() == false: "The change must not be backed by a vault"
                change.isStakedTick() == false: "The change must not be staked"
                change.tick == FRC20FungibleToken.getSymbol(): "The change must be backed by the same ticker"
            }
            post {
                self.isValidVault(): "The vault must be valid"
            }
            let balance = change.getBalance()
            let from = change.from
            self.change <-! change
            // update balance
            self.syncBalance()
            /// init DNA to the metadata
            self.initializeMetadata(FixesAssetGenes.DNA(
                self.getDNAIdentifier(),
                from,
                // Only FungibleTokens initialized from the Indexer can have 5 mutation attempts.
                isInitedFromIndexer ? 5 : 0
            ))
        }

        /// Extract the change from the vault
        ///
        access(contract)
        fun extract(): @FRC20FTShared.Change {
            pre {
                self.isValidVault(): "The vault must be valid"
            }
            post {
                self.change == nil: "The change must be nil"
            }
            let balance = self.change?.getBalance()!

            var retChange: @FRC20FTShared.Change? <- nil
            retChange <-> self.change
            // update balance
            self.syncBalance()

            // return the change
            return <- retChange!
        }

        /// Set the metadata by key
        /// Using entitlement in Cadence 1.0
        ///
        access(contract)
        fun initializeMetadata(_ data: {FixesTraits.MergeableData}) {
            pre {
                self.isValidVault(): "The vault must be valid"
            }
            let key = data.getType()
            assert(
                self._borrowMergeableDataRef(key) == nil,
                message: "The metadata key already exists"
            )

            self.metadata[key] = data

            // emit the event
            emit TokensMetadataInitialized(
                typeIdentifier: key.identifier,
                id: data.getId(),
                value: data.toString(),
                owner: self.owner?.address
            )
        }

        /// The balance can be only updated by the change
        ///
        access(self)
        fun syncBalance() {
            if self.change == nil {
                self.balance = 0.0
            } else {
                self.balance = (self.change?.getBalance())!
            }
        }

        /// Borrow the mergeable data by key
        ///
        access(self)
        fun _borrowMergeableDataRef(_ type: Type): &{FixesTraits.MergeableData}? {
            return &self.metadata[type] as &{FixesTraits.MergeableData}?
        }

        /// --------- Implement FRC20Metadata --------- ///

        /// Is the vault valid
        access(all)
        view fun isValidVault(): Bool {
            return self.change != nil
        }

        /// Get the ticker name of the token
        ///
        access(all)
        view fun getTickerName(): String {
            return self.change?.tick ?? panic("The change must be initialized")
        }

        /// Get the change's from address
        ///
        access(all)
        view fun getSourceAddress(): Address {
            return self.change?.from ?? panic("The change must be initialized")
        }

        /// Get mergeable metadata keys
        ///
        access(all)
        view fun getMergeableKeys(): [Type] {
            return self.metadata.keys
        }

        /// Get the mergeable metadata by key
        ///
        access(all)
        view fun getMergeableData(_ key: Type): {FixesTraits.MergeableData}? {
            return self.metadata[key]
        }

        /// Get the DNA identifier
        ///
        access(all)
        view fun getDNAIdentifier(): String {
            return self.getType().identifier.concat("-").concat(self.getTickerName())
        }

        /// Get the total mutatable amount of DNA
        ///
        access(all)
        view fun getDNAMutatableAmount(): UInt64 {
            let dnaRef = self._borrowMergeableDataRef(Type<FixesAssetGenes.DNA>())
                ?? panic("The DNA metadata is not found")
            return dnaRef.getValue("mutatableAmount") as! UInt64
        }

        /// DNA charging
        /// One inscription can activate 5 DNA mutatable attempts.
        ///
        access(all)
        fun chargeDNAMutatableAttempts(_ ins: &Fixes.Inscription) {
            pre {
                ins.isExtractable(): "The inscription must be extractable"
            }

            let insOwner = ins.owner?.address ?? panic("The owner of the inscription is not found")
            assert(
                insOwner == self.owner?.address,
                message: "The owner of the inscription is not matched"
            )
            let frc20CtrlRef = FRC20FungibleToken.borrowFRC20Controller()
            let meta = frc20CtrlRef.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
            assert(
                meta["tick"]?.toLower() == self.getTickerName(),
                message: "The token tick is not matched"
            )
            assert(
                meta["amt"] == "0.0",
                message: "The inscription amount must be zero"
            )
            assert(
                meta["usage"] == "empty",
                message: "The inscription usage must be empty"
            )
            let ret <- frc20CtrlRef.withdrawChange(ins: ins)
            assert(
                ret.getBalance() == 0.0,
                message: "The returned change balance must be zero"
            )
            destroy ret

            // borrow the DNA metadata
            let dnaRef = self._borrowMergeableDataRef(Type<FixesAssetGenes.DNA>())
                ?? panic("The DNA metadata is not found")
            let oldValue = dnaRef.getValue("mutatableAmount") as! UInt64
            // update the DNA mutatable amount
            dnaRef.setValue("mutatableAmount", oldValue + 5)

            // emit the event
            emit TokenDNAMutatableCharged(
                identifier: self.getDNAIdentifier(),
                mutatableAmount: oldValue + 5,
                owner: self.owner?.address
            )
        }

        /// --------- Implement FungibleToken.Provider --------- ///

        /// Function that takes an amount as an argument
        /// and withdraws that amount from the Vault.
        /// It creates a new temporary Vault that is used to hold
        /// the money that is being transferred. It returns the newly
        /// created Vault to the context that called so it can be deposited
        /// elsewhere.
        ///
        /// @param amount: The amount of tokens to be withdrawn from the vault
        /// @return The Vault resource containing the withdrawn funds
        ///
        access(all)
        fun withdraw(amount: UFix64): @FungibleToken.Vault {
            pre {
                self.isValidVault(): "The vault must be valid, need to be initialized with FRC20Change"
            }
            let changeRef = self.borrowChangeRef()!
            let oldBalance = changeRef.getBalance()
            let newChange <- changeRef.withdrawAsChange(amount: amount)
            // update balance
            self.syncBalance()

            // initialize the new vault with the amount
            let newVault <- FRC20FungibleToken.createEmptyVault()
            newVault.initialize(<- newChange, false)

            // setup mergeable data, split from withdraw percentage
            let percentage = amount / oldBalance
            let mergeableKeys = self.getMergeableKeys()
            for key in mergeableKeys {
                if let dataRef = self._borrowMergeableDataRef(key) {
                    let splitData = dataRef.split(percentage)
                    newVault.metadata[key] = splitData

                    // emit the event
                    emit TokensMetadataUpdated(
                        typeIdentifier: key.identifier,
                        id: dataRef.getId(),
                        value: dataRef.toString(),
                        owner: self.owner?.address
                    )
                }
            }

            // every 10% of balance change will get a new attempt to mutate the DNA
            var attempt = UInt64(UFix64(amount) / UFix64(oldBalance) / 0.1)
            self._attemptGenerateGene(attempt)

            // emit the event
            emit TokensWithdrawn(
                amount: amount,
                from: self.owner?.address
            )
            return <- newVault
        }

        /// --------- Implement FungibleToken.Receiver --------- ///

        /// Function that takes a Vault object as an argument and adds
        /// its balance to the balance of the owners Vault.
        /// It is allowed to destroy the sent Vault because the Vault
        /// was a temporary holder of the tokens. The Vault's balance has
        /// been consumed and therefore can be destroyed.
        ///
        /// @param from: The Vault resource containing the funds that will be deposited
        ///
        access(all)
        fun deposit(from: @FungibleToken.Vault) {
            pre {
                self.isValidVault(): "The vault must be valid, need to be initialized with FRC20Change"
            }
            // the interface ensured that the vault is of the same type
            // so we can safely cast it
            let vault <- from as! @FRC20FungibleToken.Vault
            let change <- vault.extract()

            // merge the metadata
            let keys = vault.getMergeableKeys()
            for key in keys {
                let data = vault.getMergeableData(key)!
                if let selfData = self._borrowMergeableDataRef(key) {
                    selfData.merge(data)
                } else {
                    self.metadata[key] = data
                }

                let dataRef = self._borrowMergeableDataRef(key)!
                // emit the event
                emit TokensMetadataUpdated(
                    typeIdentifier: key.identifier,
                    id: dataRef.getId(),
                    value: dataRef.toString(),
                    owner: self.owner?.address
                )
            }

            // ensure that there is a record in the FRC20 Indexer
            let ownerAddr = self.owner?.address
            if ownerAddr != nil {
                let frc20CtrlRef = FRC20FungibleToken.borrowFRC20Controller()
                frc20CtrlRef.ensureBalanceExists(tick: self.getTickerName(), addr: ownerAddr!)
            }

            // when change extracted, the balance is updated and vault is useless
            destroy vault
            let depositedBalance = change.getBalance()

            // borrow the change reference
            let changeRef = self.borrowChangeRef()!
            FRC20FTShared.depositToChange(
                receiver: changeRef,
                change: <- change
            )
            // update balance
            self.syncBalance()

            // every 10% of balance change will get a new attempt to mutate the DNA
            let attempt = UInt64(UFix64(depositedBalance) / UFix64(self.balance) / 0.1)
            self._attemptGenerateGene(attempt)

            emit TokensDeposited(
                amount: depositedBalance,
                to: self.owner?.address
            )
        }

        /// --------- Implement MetadataViews.Resolver --------- ///

        /// The way of getting all the Metadata Views implemented by FRC20FungibleToken
        ///
        /// @return An array of Types defining the implemented views. This value will be used by
        ///         developers to know which parameter to pass to the resolveView() method.
        ///
        access(all)
        fun getViews(): [Type] {
            let contractViews = FRC20FungibleToken.getViews()
            return contractViews
        }

        /// The way of getting a Metadata View out of the FRC20FungibleToken
        ///
        /// @param view: The Type of the desired view.
        /// @return A structure representing the requested view.
        ///
        access(all)
        fun resolveView(_ view: Type): AnyStruct? {
            return FRC20FungibleToken.resolveView(view)
        }

        /// --------- Internal Methods --------- ///

        /// Attempt to generate a new gene, max 5 attempts for each action
        ///
        access(self)
        fun _attemptGenerateGene(_ attempt: UInt64) {
            var max = attempt
            if max > 5 {
                max = 5
            }
            if max == 0 {
                return
            }

            let dnaRef = self._borrowMergeableDataRef(Type<FixesAssetGenes.DNA>())
                ?? panic("The DNA metadata is not found")
            let mutatableAmt = dnaRef.getValue("mutatableAmount")
            if mutatableAmt == nil {
                return
            }
            // create a new DNA
            let newDNA = FixesAssetGenes.DNA(
                self.getDNAIdentifier(),
                self.getSourceAddress(),
                mutatableAmt! as! UInt64,
            )
            var anyAdded = false
            var i: UInt64 = 0
            while i < max && newDNA.isMutatable() {
                if let gene = FixesAssetGenes.attemptToGenerateGene() {
                    newDNA.addGene(gene)
                    anyAdded = true
                }
                i = i + 1
            }

            if anyAdded {
                // merge the DNA
                dnaRef.merge(newDNA)

                // update the DNA mutatable amount
                let newMutatableAmt = newDNA.getValue("mutatableAmount") as! UInt64
                dnaRef.setValue("mutatableAmount", newMutatableAmt)

                // emit the event
                emit TokenDNAGenerated(
                    identifier: self.getDNAIdentifier(),
                    value: newDNA.toString(),
                    mutatableAmount: newMutatableAmt,
                    owner: self.owner?.address
                )
            }
        }
    }

    /// The admin interface for the FRC20 FT
    ///
    access(all) resource interface AdminInterface {
        // Only access by the contract
        access(contract)
        fun borrowFRC20Controller(): &FRC20Agents.IndexerController{FRC20Agents.IndexerControllerInterface}
    }

    /// The admin resource for the FRC20 FT
    ///
    access(all) resource FungibleTokenAdmin: AdminInterface {
        access(contract)
        var frc20IndexerController: Capability<&FRC20Agents.IndexerController{FRC20Agents.IndexerControllerInterface}>

        init(
            cap: Capability<&FRC20Agents.IndexerController{FRC20Agents.IndexerControllerInterface}>
        ) {
            pre {
                cap.check(): "The capability must be valid"
            }
            self.frc20IndexerController = cap
        }

        /// Borrow the FRC20 Indexer Controller
        ///
        access(contract)
        fun borrowFRC20Controller(): &FRC20Agents.IndexerController{FRC20Agents.IndexerControllerInterface} {
            return self.frc20IndexerController.borrow() ?? panic("The FRC20 Indexer Controller is not found")
        }
    }

    /// ------------ FRC20 <> FungibleToken Methods ------------

    /// Issue new Fungible Tokens from a FRC20 FT Change
    ///
    access(all)
    fun convertFromIndexer(ins: &Fixes.Inscription): @FRC20FungibleToken.Vault {
        pre {
            ins.isExtractable(): "The inscription must be extractable"
        }

        let frc20CtrlRef = FRC20FungibleToken.borrowFRC20Controller()
        let meta = frc20CtrlRef.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
        // ensure tick is the same
        let tick = meta["tick"]?.toLower() ?? panic("The token tick is not found")
        assert(
            tick == FRC20FungibleToken.getSymbol(),
            message: "The token tick is not matched"
        )

        // ensure usage is 'convert'
        let usage = meta["usage"] ?? panic("The token usage is not found")
        assert(
            usage == "convert",
            message: "The token usage is not matched"
        )

        let insOwner = ins.owner?.address ?? panic("The owner of the inscription is not found")
        let beforeBalance = FRC20FungibleToken.getFRC20Balance(insOwner)

        // withdraw the change from indexer
        let change <- frc20CtrlRef.withdrawChange(ins: ins)

        let afterBalance = FRC20FungibleToken.getFRC20Balance(insOwner)
        // ensure the balance is matched
        assert(
            beforeBalance - afterBalance == change.getBalance(),
            message: "The balance is not matched"
        )

        let retVault <- self.createEmptyVault()
        retVault.initialize(<- change, true)

        // emit the event
        emit TokensConvertedToStanard(
            amount: retVault.balance,
            by: insOwner,
        )

        // update the total supply
        FRC20FungibleToken.totalFungibleTokenSupply = FRC20FungibleToken.totalFungibleTokenSupply + retVault.balance
        self._syncTotalSupply()

        // return the new vault
        return <- retVault
    }

    /// Burn Fungible Tokens and convert into a FRC20 FT Change
    ///
    access(all)
    fun convertBackToIndexer(ins: &Fixes.Inscription, vault: @FungibleToken.Vault) {
        pre {
            ins.isExtractable(): "The inscription must be extractable"
            vault.isInstance(Type<@FRC20FungibleToken.Vault>()): "The vault must be of the same type as the token"
        }

        let frc20CtrlRef = FRC20FungibleToken.borrowFRC20Controller()
        let meta = frc20CtrlRef.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
        // ensure tick is the same
        let tick = meta["tick"]?.toLower() ?? panic("The token tick is not found")
        assert(
            tick == FRC20FungibleToken.getSymbol(),
            message: "The token tick is not matched"
        )

        let fromVault <- vault as! @FRC20FungibleToken.Vault
        let retChange <- fromVault.extract()
        // no need to emit the event, it is emitted in the extract function
        destroy fromVault

        let convertBalance = retChange.getBalance()

        // before balance
        let insOwner = ins.owner?.address ?? panic("The owner of the inscription is not found")
        let beforeBalance = FRC20FungibleToken.getFRC20Balance(insOwner)

        frc20CtrlRef.depositChange(ins: ins, change: <- retChange)

        // after balance
        let afterBalance = FRC20FungibleToken.getFRC20Balance(insOwner)
        // ensure the balance is matched
        assert(
            afterBalance - beforeBalance == convertBalance,
            message: "The balance is not matched"
        )

        // emit the converted event
        emit TokensConvertedToFRC20(
            amount: convertBalance,
            by: insOwner,
        )

        // update the total supply
        FRC20FungibleToken.totalFungibleTokenSupply = FRC20FungibleToken.totalFungibleTokenSupply - convertBalance
        self._syncTotalSupply()
    }

    /// ------------ Internal Methods ------------

    /// Sync the total supply with the real total supply
    ///
    access(self)
    fun _syncTotalSupply() {
        let realSupply = self.getTotalSupply()
        if self.totalSupply != realSupply {
            self.totalSupply = realSupply
        }
    }

    /// Borrow the FRC20 Indexer Controller
    ///
    access(contract)
    fun borrowFRC20Controller(): &FRC20Agents.IndexerController{FRC20Agents.IndexerControllerInterface} {
        if let adminRef = getAccount(self.account.address)
            .getCapability<&FungibleTokenAdmin{AdminInterface}>(self.getAdminPublicPath())
            .borrow() {
            return adminRef.borrowFRC20Controller()
        }
        panic("The FRC20 Indexer Controller is not found")
    }

    /// ------------ General Functions ------------

    /// Function that creates a new Vault with a balance of zero
    /// and returns it to the calling context. A user must call this function
    /// and store the returned Vault in their storage in order to allow their
    /// account to be able to receive deposits of this token type.
    ///
    /// @return The new Vault resource
    ///
    access(all)
    fun createEmptyVault(): @Vault {
        return <-create Vault(balance: 0.0)
    }

    /// Borrow the shared store
    ///
    access(all)
    view fun borrowSharedStore(): &FRC20FTShared.SharedStore{FRC20FTShared.SharedStorePublic} {
        let addr = self.account.address
        return FRC20FTShared.borrowStoreRef(addr) ?? panic("Config store not found")
    }

    /// Function that resolves a metadata view for this contract.
    ///
    /// @param view: The Type of the desired view.
    /// @return A structure representing the requested view.
    ///
    access(all)
    fun resolveView(_ view: Type): AnyStruct? {
        // external url
        let externalUrl = FRC20FungibleToken.getExternalUrl()
        switch view {
            case Type<MetadataViews.ExternalURL>():
                return externalUrl != nil
                    ? MetadataViews.ExternalURL(externalUrl!)
                    : MetadataViews.ExternalURL("https://fixes.world/")
            case Type<FungibleTokenMetadataViews.FTView>():
                return FungibleTokenMetadataViews.FTView(
                    ftDisplay: self.resolveView(Type<FungibleTokenMetadataViews.FTDisplay>()) as! FungibleTokenMetadataViews.FTDisplay?,
                    ftVaultData: self.resolveView(Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
                )
            case Type<FungibleTokenMetadataViews.FTDisplay>():
                let frc20Indexer = FRC20Indexer.getIndexer()
                let store = FRC20FungibleToken.borrowSharedStore()
                let tick = FRC20FungibleToken.getSymbol()

                if let display = frc20Indexer.getTokenDisplay(tick: tick) {
                    // medias
                    let medias: [MetadataViews.Media] = []
                    let logoKey = store.getKeyByEnum(FRC20FTShared.ConfigType.FungibleTokenLogoPrefix)!
                    if let iconUrl = store.get(logoKey) as! String? {
                        medias.append(MetadataViews.Media(
                            file: MetadataViews.HTTPFile(url: iconUrl),
                            mediaType: "image/png" // default is png
                        ))
                    }
                    if let iconUrl = store.get(logoKey.concat("png")) as! String? {
                        medias.append(MetadataViews.Media(
                            file: MetadataViews.HTTPFile(url: iconUrl),
                            mediaType: "image/png"
                        ))
                    }
                    if let iconUrl = store.get(logoKey.concat("svg")) as! String? {
                        medias.append(MetadataViews.Media(
                            file: MetadataViews.HTTPFile(url: iconUrl),
                            mediaType: "image/svg+xml"
                        ))
                    }
                    if let iconUrl = store.get(logoKey.concat("jpg")) as! String? {
                        medias.append(MetadataViews.Media(
                            file: MetadataViews.HTTPFile(url: iconUrl),
                            mediaType: "image/jpeg"
                        ))
                    }
                    // socials
                    let socialDict: {String: MetadataViews.ExternalURL} = {}
                    let socialKey = store.getKeyByEnum(FRC20FTShared.ConfigType.FungibleTokenSocialPrefix)!
                    // load social infos
                    if let socialUrl = store.get(socialKey.concat("twitter")) {
                        socialDict["twitter"] = MetadataViews.ExternalURL((socialUrl as! String?)!)
                    }
                    if let socialUrl = store.get(socialKey.concat("telegram")) {
                        socialDict["telegram"] = MetadataViews.ExternalURL((socialUrl as! String?)!)
                    }
                    if let socialUrl = store.get(socialKey.concat("discord")) {
                        socialDict["discord"] = MetadataViews.ExternalURL((socialUrl as! String?)!)
                    }
                    if let socialUrl = store.get(socialKey.concat("github")) {
                        socialDict["github"] = MetadataViews.ExternalURL((socialUrl as! String?)!)
                    }
                    if let socialUrl = store.get(socialKey.concat("website")) {
                        socialDict["website"] = MetadataViews.ExternalURL((socialUrl as! String?)!)
                    }
                    // override all customized fields
                    return FungibleTokenMetadataViews.FTDisplay(
                        name: FRC20FungibleToken.getDisplayName() ?? display.name,
                        symbol: tick,
                        description: FRC20FungibleToken.getTokenDescription() ?? display.description,
                        externalURL: externalUrl != nil
                            ? MetadataViews.ExternalURL(externalUrl!)
                            : display.externalURL,
                        logos: medias.length > 0
                            ? MetadataViews.Medias(medias)
                            : display.logos,
                        socials: socialDict
                    )
                }
            case Type<FungibleTokenMetadataViews.FTVaultData>():
                let prefix = FRC20FungibleToken.getPathPrefix()
                return FungibleTokenMetadataViews.FTVaultData(
                    storagePath: FRC20FungibleToken.getVaultStoragePath(),
                    receiverPath: FRC20FungibleToken.getReceiverPublicPath(),
                    metadataPath: FRC20FungibleToken.getVaultPublicPath(),
                    providerPath: PrivatePath(identifier: prefix.concat("Vault"))!,
                    receiverLinkedType: Type<&FRC20FungibleToken.Vault{FungibleToken.Receiver}>(),
                    metadataLinkedType: Type<&FRC20FungibleToken.Vault{FungibleToken.Balance, MetadataViews.Resolver}>(),
                    providerLinkedType: Type<&FRC20FungibleToken.Vault{FungibleToken.Provider}>(),
                    createEmptyVaultFunction: (fun (): @FRC20FungibleToken.Vault {
                        return <-FRC20FungibleToken.createEmptyVault()
                    })
                )
            // case Type<FungibleTokenMetadataViews.TotalSupply>():
            //     let indexer = FRC20Indexer.getIndexer()
            //     let tick = FRC20FungibleToken.getTickerName()
            //     if let tokenMeta = indexer.getTokenMeta(tick: tick) {
            //         return FungibleTokenMetadataViews.TotalSupply(
            //             totalSupply: tokenMeta.max
            //         )
            //     } else {
            //         return nil
            //     }
        }
        return nil
    }

    /// Function that returns all the Metadata Views implemented by a Fungible Token
    ///
    /// @return An array of Types defining the implemented views. This value will be used by
    ///         developers to know which parameter to pass to the resolveView() method.
    ///
    access(all)
    view fun getViews(): [Type] {
        return [
            // Type<FungibleTokenMetadataViews.TotalSupply>(),
            Type<MetadataViews.ExternalURL>(),
            Type<FungibleTokenMetadataViews.FTView>(),
            Type<FungibleTokenMetadataViews.FTDisplay>(),
            Type<FungibleTokenMetadataViews.FTVaultData>()
        ]
    }

    /// the real total supply is loaded from the FRC20Indexer
    ///
    access(all)
    view fun getTotalSupply(): UFix64 {
        let frc20Indexer = FRC20Indexer.getIndexer()
        let tokenMeta = frc20Indexer.getTokenMeta(tick: self.getSymbol())!
        return tokenMeta.supplied - tokenMeta.burned
    }

    /// Get the total supply of the standard fungible token
    ///
    access(all)
    view fun getStandardFungibleTokenTotalSupply(): UFix64 {
        return self.totalFungibleTokenSupply
    }

    /// Get the ticker name of the token
    ///
    access(all)
    view fun getSymbol(): String {
        let store = self.borrowSharedStore()
        let tick = store.getByEnum(FRC20FTShared.ConfigType.FungibleTokenSymbol) as! String?
        return tick ?? panic("Ticker name not found")
    }

    /// Get the display name of the token
    ///
    access(all)
    view fun getDisplayName(): String? {
        let store = self.borrowSharedStore()
        return store.getByEnum(FRC20FTShared.ConfigType.FungibleTokenDisplayName) as! String?
    }

    /// Get the token description
    ///
    access(all)
    view fun getTokenDescription(): String? {
        let store = self.borrowSharedStore()
        return store.getByEnum(FRC20FTShared.ConfigType.FungibleTokenDescription) as! String?
    }

    /// Get the external URL of the token
    ///
    access(all)
    view fun getExternalUrl(): String? {
        let store = self.borrowSharedStore()
        return store.getByEnum(FRC20FTShared.ConfigType.FungibleTokenExternalUrl) as! String?
    }

    /// Get the icon URL of the token
    ///
    access(all)
    view fun getLogoUrl(): String? {
        let store = self.borrowSharedStore()
        let key = store.getKeyByEnum(FRC20FTShared.ConfigType.FungibleTokenLogoPrefix)!
        let iconDefault = store.get(key) as! String?
        let iconPng = store.get(key.concat("png")) as! String?
        let iconSvg = store.get(key.concat("svg")) as! String?
        let iconJpg = store.get(key.concat("jpg")) as! String?
        return iconPng ?? iconSvg ?? iconJpg ?? iconDefault
    }

    /// Get the Token Balance of the address
    /// Including FRC20 and FungibleToken
    ///
    access(all)
    view fun getTotalBalance(_ addr: Address): UFix64 {
        return self.getFRC20Balance(addr) + self.getTokenBalance(addr)
    }

    /// Get the fungible token balance of the address
    ///
    access(all)
    view fun getTokenBalance(_ addr: Address): UFix64 {
        if let ref = getAccount(addr)
            .getCapability<&FRC20FungibleToken.Vault{FungibleToken.Balance}>(self.getVaultPublicPath())
            .borrow() {
            return ref.balance
        }
        return 0.0
    }

    /// Get the FRC20 Balance of the address
    ///
    access(all)
    view fun getFRC20Balance(_ addr: Address): UFix64 {
        let frc20Indexer = FRC20Indexer.getIndexer()
        return frc20Indexer.getBalance(tick: self.getSymbol(), addr: addr)
    }

    /// Get the prefix for the storage paths
    ///
    access(all)
    view fun getPathPrefix(): String {
        return "FRC20FT_".concat(self.account.address.toString()).concat(self.getSymbol()).concat("_")
    }

    /// Get the storage path for the Vault
    ///
    access(all)
    view fun getVaultStoragePath(): StoragePath {
        let prefix = FRC20FungibleToken.getPathPrefix()
        return StoragePath(identifier: prefix.concat("Vault"))!
    }

    /// Get the public path for the Vault
    ///
    access(all)
    view fun getVaultPublicPath(): PublicPath {
        let prefix = FRC20FungibleToken.getPathPrefix()
        return PublicPath(identifier: prefix.concat("Metadata"))!
    }

    /// Get the public path for the Receiver
    ///
    access(all)
    view fun getReceiverPublicPath(): PublicPath {
        let prefix = FRC20FungibleToken.getPathPrefix()
        return PublicPath(identifier: prefix.concat("Receiver"))!
    }

    /// Get the admin storage path
    ///
    access(all)
    view fun getAdminStoragePath(): StoragePath {
        let prefix = FRC20FungibleToken.getPathPrefix()
        return StoragePath(identifier: prefix.concat("Admin"))!
    }

    /// Get the admin public path
    ///
    access(all)
    view fun getAdminPublicPath(): PublicPath {
        let prefix = FRC20FungibleToken.getPathPrefix()
        return PublicPath(identifier: prefix.concat("Admin"))!
    }

    /// ----- Internal Methods -----

    /// Initialize the contract with ticker name
    ///
    init() {
        // Initialize
        self.totalSupply = 0.0
        self.totalFungibleTokenSupply = 0.0

        // Singleton resources
        let frc20Indexer = FRC20Indexer.getIndexer()
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        let isSysmtemDeploy = self.account.address == frc20Indexer.owner?.address
        if isSysmtemDeploy {
            // DO NOTHING, It will be a template contract for deploying new FRC20 Fungible tokens
            return
        }

        // Step.0 Ensure shared store exists

        // Initialize the shared store
        if self.account.borrow<&AnyResource>(from: FRC20FTShared.SharedStoreStoragePath) == nil {
            let sharedStore <- FRC20FTShared.createSharedStore()
            self.account.save(<- sharedStore, to: FRC20FTShared.SharedStoreStoragePath)
        }
        // link the resource to the public path
        // @deprecated after Cadence 1.0
        if self.account
            .getCapability<&FRC20FTShared.SharedStore{FRC20FTShared.SharedStorePublic}>(FRC20FTShared.SharedStorePublicPath)
            .borrow() == nil {
            self.account.unlink(FRC20FTShared.SharedStorePublicPath)
            self.account.link<&FRC20FTShared.SharedStore{FRC20FTShared.SharedStorePublic}>(FRC20FTShared.SharedStorePublicPath, target: FRC20FTShared.SharedStoreStoragePath)
        }
        // borrow the shared store
        let store = self.borrowSharedStore()

        // Step.1 Try get the ticker name from the shared store
        var tickerName = store.getByEnum(FRC20FTShared.ConfigType.FungibleTokenSymbol) as! String?
        if tickerName == nil {
            // try load the ticker name from AccountPools
            let addrDict = acctsPool.getFRC20Addresses(type: FRC20AccountsPool.ChildAccountType.FungibleToken)
            let contractAddr = self.account.address
            addrDict.forEachKey(fun (key: String): Bool {
                if let addr = addrDict[key] {
                    if addr == contractAddr {
                        tickerName = key
                        return false
                    }
                }
                return true
            })

            // set the ticker name
            if tickerName != nil {
                store.setByEnum(FRC20FTShared.ConfigType.FungibleTokenSymbol, value: tickerName!)
            }
        }

        // ensure frc20 metadata exists
        assert(
            tickerName != nil && frc20Indexer.getTokenMeta(tick: tickerName!) != nil,
            message: "The FRC20 token does not exist"
        )

        // set the total supply
        self._syncTotalSupply()

        // Emit an event that shows that the contract was initialized
        emit TokensInitialized(initialSupply: self.totalSupply)

        // setup the indexer controller
        let controlerPath = FRC20Agents.getIndexerControllerStoragePath()
        assert(
            self.account.check<&FRC20Agents.IndexerController>(from: controlerPath),
            message: "The FRC20 Indexer Controller is not found"
        )
        // @deprecated in Cadence 1.0
        let privPath = /private/FRC20IndxerController
        self.account.link<&FRC20Agents.IndexerController{FRC20Agents.IndexerControllerInterface}>(
            privPath,
            target: controlerPath
        )

        // setup admin resource
        let cap = self.account.getCapability<&FRC20Agents.IndexerController{FRC20Agents.IndexerControllerInterface}>(privPath)
        let admin <- create FungibleTokenAdmin(cap: cap)
        let adminStoragePath = self.getAdminStoragePath()
        self.account.save(<-admin, to: adminStoragePath)
        // link the admin resource to the public path
        // @deprecated after Cadence 1.0
        self.account.link<&FRC20FungibleToken.FungibleTokenAdmin{FRC20FungibleToken.AdminInterface}>(
            self.getAdminPublicPath(),
            target: adminStoragePath
        )

        // Ensure frc20 controller exists
        let ctrlRef = self.borrowFRC20Controller()
        assert(
            ctrlRef.isTickAccepted(tick: tickerName!),
            message: "The FRC20 token is not accepted by the controller"
        )

        // Step.2 Setup the vault and receiver for the contract account

        let storagePath = self.getVaultStoragePath()
        let publicPath = self.getVaultPublicPath()
        let receiverPath = self.getReceiverPublicPath()

        // Create the Vault with the total supply of tokens and save it in storage.
        let vault <- create Vault(balance: self.totalSupply)
        self.account.save(<-vault, to: storagePath)

        // @deprecated after Cadence 1.0
        // Create a public capability to the stored Vault that exposes
        // the `deposit` method through the `Receiver` interface.
        self.account.link<&{FungibleToken.Receiver}>(receiverPath, target: storagePath)
        // Create a public capability to the stored Vault that only exposes
        // the `balance` field and the `resolveView` method through the `Balance` interface
        self.account.link<&FRC20FungibleToken.Vault{FungibleToken.Balance, MetadataViews.Resolver}>(publicPath, target: storagePath)
    }
}
