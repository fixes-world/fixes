/**

> Author: FIXeS World <https://fixes.world/>

# FRC20FungibleToken

This is the fungible token contract for all FRC20 tokens. It is the template contract that is used to deploy.

*/

import "FungibleToken"
import "ViewResolver"
import "MetadataViews"
import "FungibleTokenMetadataViews"
import "TokenList"
import "Burner"
// Fixes imports
import "Fixes"
import "FixesInscriptionFactory"
import "FixesFungibleTokenInterface"
import "FixesTraits"
import "FixesAssetMeta"
import "FRC20FTShared"
import "FRC20Indexer"
import "FRC20AccountsPool"
import "FRC20Agents"

/// This is the template source for a FRC20 Fungible Token
/// The contract is deployed in the child account of the FRC20AccountsPool
/// All real FRC20 tokens are deployed in the FRC20Indexer, and
/// the FT Token issued by the FRC20FTShared.Change
access(all) contract FRC20FungibleToken: FixesFungibleTokenInterface, FungibleToken, ViewResolver {
    // ------ Events -------

    /// The event that is emitted when the contract is created
    access(all) event TokensInitialized(initialSupply: UFix64)

    /// The event that is emitted when new tokens are minted
    access(all) event TokensConvertedToStanard(amount: UFix64, by: Address)

    /// The event that is emitted when tokens are destroyed
    access(all) event TokensConvertedToFRC20(amount: UFix64, by: Address)

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
    access(all) resource Vault: FixesFungibleTokenInterface.Vault, FungibleToken.Vault {
        /// The total balance of this vault
        access(all)
        var balance: UFix64
        /// Metadata: Type of MergeableData => MergeableData
        access(contract)
        let metadata: {Type: {FixesTraits.MergeableData}}
        // The change should be inside the vault
        access(self)
        var change: @FRC20FTShared.Change?

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

        /// The destroy method for the Vault
        ///
        access(contract)
        fun burnCallback() {
            pre {
                self.change == nil: "The change must be nil"
            }
            if self.balance > 0.0 {
                // update the total supply for the FungibleToken
                FRC20FungibleToken.totalFungibleTokenSupply = FRC20FungibleToken.totalFungibleTokenSupply - self.balance
            }
        }

        /// createEmptyVault
        ///
        /// Function that creates a new Vault with a balance of zero
        /// and returns it to the calling context. A user must call this function
        /// and store the returned Vault in their storage in order to allow their
        /// account to be able to receive deposits of this token type.
        ///
        access(all) fun createEmptyVault(): @Vault {
            return <- FRC20FungibleToken.createEmptyVault(vaultType: Type<@Vault>())
        }

        /// ----- Internal Methods -----

        /// Borrow the change reference
        ///
        access(contract)
        fun borrowChangeRef(): auth(FRC20FTShared.Write) &FRC20FTShared.Change? {
            return &self.change
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
            self.initializeMetadata(FixesAssetMeta.DNA(
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
            post {
                self.isValidVault(): "The vault must be valid"
            }
            let key = data.getType()
            self.metadata[key] = data
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

        /// --------- Implement FRC20Metadata --------- ///

        /// Is the vault valid
        access(all)
        view fun isValidVault(): Bool {
            return self.change != nil && self.borrowMergeableDataRef(Type<FixesAssetMeta.DNA>()) != nil
        }

        /// Get the symbol of the token
        access(all)
        view fun getSymbol(): String {
            return FRC20FungibleToken.getSymbol()
        }

        /// DNA charging
        /// One inscription can activate 5 DNA mutatable attempts.
        ///
        access(all)
        fun chargeDNAMutatableAttempts(_ ins: auth(Fixes.Extractable) &Fixes.Inscription) {
            pre {
                ins.isExtractable(): "The inscription must be extractable"
            }
            post {
                self.isValidVault(): "The vault must be valid before charge"
            }

            let insOwner = ins.owner?.address ?? panic("The owner of the inscription is not found")
            assert(
                insOwner == self.owner?.address,
                message: "The owner of the inscription is not matched"
            )

            // singleton FRC20 controller
            let frc20CtrlRef = FRC20FungibleToken.borrowFRC20Controller()
            // ensure the vault is valid
            if !self.isValidVault() {
                let newChange <- frc20CtrlRef.createEmptyChange(
                    tick: self.getSymbol(),
                    from: insOwner
                )
                self.initialize(<- newChange, false)
            }

            let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
            assert(
                meta["tick"]?.toLower() == self.getSymbol(),
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
            Burner.burn(<- ret)

            // borrow the DNA metadata
            let dnaRef = self.borrowMergeableDataRef(Type<FixesAssetMeta.DNA>())
                ?? panic("The DNA metadata is not found")
            let oldValue = dnaRef.getValue("mutatableAmount") as! UInt64
            // update the DNA mutatable amount
            let addAmt = self.getMaxGenerateGeneAttempts()
            dnaRef.setValue("mutatableAmount", oldValue + addAmt)
        }

        /// --------- Implement FungibleToken.Provider --------- ///

        /// Asks if the amount can be withdrawn from this vault
        ///
        access(all) view fun isAvailableToWithdraw(amount: UFix64): Bool {
            return amount <= self.balance
        }

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
        access(FungibleToken.Withdraw)
        fun withdraw(amount: UFix64): @{FungibleToken.Vault} {
            pre {
                self.isValidVault(): "The vault must be valid before withdraw"
            }
            let changeRef = self.borrowChangeRef()!
            let oldBalance = changeRef.getBalance()
            let newChange <- changeRef.withdrawAsChange(amount: amount)
            // update balance
            self.syncBalance()

            // initialize the new vault with the amount
            let newVault <- FRC20FungibleToken.createEmptyVault(vaultType: Type<@Vault>())
            newVault.initialize(<- newChange, false)

            // setup mergeable data, split from withdraw percentage
            let percentage = amount / oldBalance
            let mergeableKeys = self.getMergeableKeys()
            for key in mergeableKeys {
                if let dataRef = self.borrowMergeableDataRef(key) {
                    let splitData = dataRef.split(percentage)
                    newVault.metadata[key] = splitData

                    // emit the event
                    FRC20FungibleToken.emitMetadataUpdated(
                        &self as auth(FixesFungibleTokenInterface.MetadataUpdate) &{FixesFungibleTokenInterface.Vault},
                        dataRef
                    )
                }
            }

            // Is the vault has DNA, then attempt to generate a new gene
            self._attemptGenerateGene(amount, oldBalance)

            return <- newVault
        }

        /// --------- Implement FungibleToken.Receiver --------- ///

        /// Function that takes a Vault object as an argument and adds
        /// its balance to the balance of the owners Vault.
        /// It is allowed to Burner.burn(the sent Vault because the Vault
        /// was a temporary holder of the tokens. The Vault's balance has
        /// been consumed and therefore can be destroyed.
        ///
        /// @param from: The Vault resource containing the funds that will be deposited
        ///
        access(all)
        fun deposit(from: @{FungibleToken.Vault}) {
            post {
                self.isValidVault(): "The vault must be valid after deposit"
            }
            // the interface ensured that the vault is of the same type
            // so we can safely cast it
            let vault <- from as! @FRC20FungibleToken.Vault
            let change <- vault.extract()

            // singleton FRC20 controller
            let frc20CtrlRef = FRC20FungibleToken.borrowFRC20Controller()
            // initialize current vault if it is not initialized
            if !self.isValidVault() {
                let newChange <- frc20CtrlRef.createEmptyChange(
                    tick: change.tick,
                    from: change.from
                )
                self.initialize(<- newChange, false)
            }

            // merge the metadata
            let keys = vault.getMergeableKeys()
            for key in keys {
                let data = vault.getMergeableData(key)!
                if let selfData = self.borrowMergeableDataRef(key) {
                    selfData.merge(data)
                } else {
                    self.metadata[key] = data
                }

                let dataRef = self.borrowMergeableDataRef(key)!
                // emit the event
                FRC20FungibleToken.emitMetadataUpdated(
                    &self as auth(FixesFungibleTokenInterface.MetadataUpdate) &{FixesFungibleTokenInterface.Vault},
                    dataRef
                )
            }

            // ensure that there is a record in the FRC20 Indexer
            let ownerAddr = self.owner?.address
            if ownerAddr != nil {
                let frc20CtrlRef = FRC20FungibleToken.borrowFRC20Controller()
                frc20CtrlRef.ensureBalanceExists(tick: FRC20FungibleToken.getSymbol(), addr: ownerAddr!)
            }

            // when change extracted, the balance is updated and vault is useless
            Burner.burn(<- vault)
            let depositedBalance = change.getBalance()

            // borrow the change reference
            let changeRef = self.borrowChangeRef()!
            changeRef.forceMerge(from: <- change)

            // update balance
            self.syncBalance()

            // Is the vault has DNA, then attempt to generate a new gene
            self._attemptGenerateGene(depositedBalance, self.balance)
        }

        /// --------- Implement ViewResolver.Resolver --------- ///

        /// The way of getting all the Metadata Views implemented by FRC20FungibleToken
        ///
        /// @return An array of Types defining the implemented views. This value will be used by
        ///         developers to know which parameter to pass to the resolveView() method.
        ///
        access(all)
        view fun getViews(): [Type] {
            let contractViews = FRC20FungibleToken.getContractViews(resourceType: Type<@Vault>())
            return contractViews
        }

        /// The way of getting a Metadata View out of the FRC20FungibleToken
        ///
        /// @param view: The Type of the desired view.
        /// @return A structure representing the requested view.
        ///
        access(all)
        fun resolveView(_ view: Type): AnyStruct? {
            return FRC20FungibleToken.resolveContractView(resourceType: nil, viewType: view)
        }

        /// --------- Internal Methods --------- ///

        /// Borrow the mergeable data by key
        ///
        access(contract)
        view fun borrowMergeableDataRef(_ type: Type): auth(FixesTraits.Write) &{FixesTraits.MergeableData}? {
            return &self.metadata[type]
        }

        /// Attempt to generate a new gene, max 5 attempts for each action
        ///
        access(self)
        fun _attemptGenerateGene(_ transactedAmt: UFix64, _ totalAmt: UFix64) {
            if !self.isValidVault() || self.getDNAMutatableAmount() == 0 || totalAmt == 0.0 {
                return
            }
            // every 10% of balance change will get a new attempt to mutate the DNA
            let attempt = UInt64(transactedAmt / totalAmt / 0.1)
            self.attemptGenerateGene(attempt)
        }
    }

    /// The admin interface for the FRC20 FT
    ///
    access(all) resource interface AdminInterface {
        // Only access by the contract
        access(contract)
        view fun borrowFRC20Controller(): auth(FRC20Agents.Manage) &FRC20Agents.IndexerController
    }

    /// The admin resource for the FRC20 FT
    ///
    access(all) resource FungibleTokenAdmin: AdminInterface, FixesFungibleTokenInterface.IGlobalPublic, FixesFungibleTokenInterface.IMinterHolder, FixesFungibleTokenInterface.IAdminWritable {
        access(self)
        let minter: @Minter
        access(contract)
        var frc20IndexerController: Capability<auth(FRC20Agents.Manage) &FRC20Agents.IndexerController>

        init(
            cap: Capability<auth(FRC20Agents.Manage) &FRC20Agents.IndexerController>
        ) {
            pre {
                cap.check(): "The capability must be valid"
            }
            self.minter <- create Minter()
            self.frc20IndexerController = cap
        }

        // ----- Implement AdminInterface -----

        /// Borrow the FRC20 Indexer Controller
        ///
        access(contract)
        view fun borrowFRC20Controller(): auth(FRC20Agents.Manage) &FRC20Agents.IndexerController {
            return self.frc20IndexerController.borrow() ?? panic("The FRC20 Indexer Controller is not found")
        }

        // ----- Implement IGlobalPublic -----

        /// Check if the address is the admin
        access(all)
        view fun isAuthorizedUser(_ addr: Address): Bool {
            let frc20Indexer = FRC20Indexer.getIndexer()
            let tick = FRC20FungibleToken.getSymbol()
            let meta = frc20Indexer.getTokenMeta(tick: tick)
            return meta?.deployer == addr
        }

        /// Check if the address is the token holder
        ///
        access(all)
        view fun isTokenHolder(_ addr: Address): Bool {
            let tick = FRC20FungibleToken.getSymbol()
            return FRC20FungibleToken.getTokenBalance(addr) > 0.0
        }

        /// Get the holders amount
        ///
        access(all)
        view fun getHoldersAmount(): UInt64 {
            let frc20Indexer = FRC20Indexer.getIndexer()
            let tick = FRC20FungibleToken.getSymbol()
            return frc20Indexer.getHoldersAmount(tick: tick)
        }

        // ----- Implement IAdminWritable -----

        /// Create a new Minter resource
        ///
        access(FixesFungibleTokenInterface.Manage)
        fun createMinter(allowedAmount: UFix64): @Minter {
            panic("This method is invalid for FRC20FundibleToken")
        }

        /// Update the authorized users
        ///
        access(FixesFungibleTokenInterface.Manage)
        fun updateAuthorizedUsers(_ addr: Address, _ isAdd: Bool) {
            panic("This method is invalid for FRC20FundibleToken")
        }

        /// Borrow the super minter resource
        ///
        access(FixesFungibleTokenInterface.Manage)
        view fun borrowSuperMinter(): auth(FixesFungibleTokenInterface.Manage) &{FixesFungibleTokenInterface.IMinter} {
            return &self.minter
        }

        // ----- Implement IMinterHolder -----

        /// Borrow the minter reference
        ///
        access(contract)
        view fun borrowMinter(): auth(FixesFungibleTokenInterface.Manage) &{FixesFungibleTokenInterface.IMinter} {
            return self.borrowSuperMinter()
        }
    }

    /// Resource object that token admin accounts can hold to mint new tokens.
    ///
    access(all) resource Minter: FixesFungibleTokenInterface.IMinter {
        // ----- Implement IMinter -----

        /// Get the symbol of the minting token
        ///
        access(all)
        view fun getSymbol(): String {
            return FRC20FungibleToken.getSymbol()
        }

        /// Get the type of the minting token
        access(all)
        view fun getTokenType(): Type {
            return Type<@FRC20FungibleToken.Vault>()
        }

        /// Get the key in the accounts pool
        access(all)
        view fun getAccountsPoolKey(): String? {
            return self.getSymbol()
        }

        /// Get the contract address of the minting token
        access(all)
        view fun getContractAddress(): Address {
            return FRC20FungibleToken.getAccountAddress()
        }

        /// Get the max supply of the minting token
        access(all)
        view fun getMaxSupply(): UFix64 {
            return FRC20FungibleToken.getMaxSupply()!
        }

        /// Get the total supply of the minting token
        ///
        access(all)
        view fun getTotalSupply(): UFix64 {
            return FRC20FungibleToken.getTotalSupply()
        }

        /// Get the current mintable amount
        ///
        access(all)
        view fun getCurrentMintableAmount(): UFix64 {
            return 0.0
        }

        /// Get the total allowed mintable amount
        ///
        access(all)
        view fun getTotalAllowedMintableAmount(): UFix64 {
            return 0.0
        }

        /// Get the vault data of the minting token
        ///
        access(all)
        fun getVaultData(): FungibleTokenMetadataViews.FTVaultData {
            return FRC20FungibleToken.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
                ?? panic("The vault data is not found")
        }

        /// Fake mint tokens
        ///
        access(FixesFungibleTokenInterface.Manage)
        fun mintTokens(amount: UFix64): @FRC20FungibleToken.Vault {
            pre {
                amount == 0.0: "The amount must be zero"
            }
            // Whatever the amount is, it is not mintable, always return empty vault
            return <- FRC20FungibleToken.createEmptyVault(vaultType: Type<@Vault>())
        }

        /// Mint tokens with user's inscription
        ///
        access(FixesFungibleTokenInterface.Manage)
        fun initializeVaultByInscription(
            vault: @{FungibleToken.Vault},
            ins: auth(Fixes.Extractable) &Fixes.Inscription
        ): @{FungibleToken.Vault} {
            let convertedVault <- FRC20FungibleToken.convertFromIndexer(ins: ins)
            assert(
                convertedVault.isValidVault(),
                message: "The converted vault must be valid"
            )
            assert(
                convertedVault.getType() == vault.getType(),
                message: "The converted vault must be of the same type as the token"
            )
            if vault.balance == 0.0 {
                Burner.burn(<- vault)
            } else {
                convertedVault.deposit(from: <- vault)
            }
            return <- convertedVault
        }

        /// Burn tokens with user's inscription
        ///
        access(FixesFungibleTokenInterface.Manage)
        fun burnTokenWithInscription(
            vault: @{FungibleToken.Vault},
            ins: auth(Fixes.Extractable) &Fixes.Inscription
        ) {
            FRC20FungibleToken.convertBackToIndexer(ins: ins, vault: <- vault)
        }
    }

    /// ------------ FRC20 <> FungibleToken Methods ------------

    /// Issue new Fungible Tokens from a FRC20 FT Change
    ///
    access(contract)
    fun convertFromIndexer(
        ins: auth(Fixes.Extractable) &Fixes.Inscription
    ): @FRC20FungibleToken.Vault {
        pre {
            ins.isExtractable(): "The inscription must be extractable"
        }

        // register token to the tokenlist
        TokenList.ensureFungibleTokenRegistered(self.account.address, "FRC20FungibleToken")

        let frc20CtrlRef = FRC20FungibleToken.borrowFRC20Controller()
        let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
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

        let retVault <- self.createEmptyVault(vaultType: Type<@Vault>())
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
    access(contract)
    fun convertBackToIndexer(
        ins: auth(Fixes.Extractable) &Fixes.Inscription,
        vault: @{FungibleToken.Vault}
    ) {
        pre {
            ins.isExtractable(): "The inscription must be extractable"
            vault.isInstance(Type<@FRC20FungibleToken.Vault>()): "The vault must be of the same type as the token"
        }

        let frc20CtrlRef = FRC20FungibleToken.borrowFRC20Controller()
        let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
        // ensure tick is the same
        let tick = meta["tick"]?.toLower() ?? panic("The token tick is not found")
        assert(
            tick == FRC20FungibleToken.getSymbol(),
            message: "The token tick is not matched"
        )

        let fromVault <- vault as! @FRC20FungibleToken.Vault
        let retChange <- fromVault.extract()
        // no need to emit the event, it is emitted in the extract function
        Burner.burn(<- fromVault)

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
    view fun borrowFRC20Controller(): auth(FRC20Agents.Manage) &FRC20Agents.IndexerController {
        let adminRef = self.borrowAdminPublic()
        return adminRef.borrowFRC20Controller()
    }

    /// Borrow the admin public reference
    ///
    access(contract)
    view fun borrowAdminPublic(): &FungibleTokenAdmin {
        return self.account
            .capabilities.get<&FungibleTokenAdmin>(self.getAdminPublicPath())
            .borrow() ?? panic("The FungibleToken Admin is not found")
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
    fun createEmptyVault(vaultType: Type): @Vault {
        return <-create Vault(balance: 0.0)
    }

    /// Function that resolves a metadata view for this contract.
    ///
    /// @param view: The Type of the desired view.
    /// @return A structure representing the requested view.
    ///
    access(all)
    fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        // external url
        let externalUrl = FRC20FungibleToken.getExternalUrl()
        switch viewType {
            case Type<MetadataViews.ExternalURL>():
                return externalUrl != nil
                    ? MetadataViews.ExternalURL(externalUrl!)
                    : MetadataViews.ExternalURL("https://fixes.world/")
            case Type<FungibleTokenMetadataViews.FTView>():
                return FungibleTokenMetadataViews.FTView(
                    ftDisplay: self.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTDisplay>()) as! FungibleTokenMetadataViews.FTDisplay?,
                    ftVaultData: self.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
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
                    if let iconUrl = store.get(logoKey.concat("gif")) as! String? {
                        medias.append(MetadataViews.Media(
                            file: MetadataViews.HTTPFile(url: iconUrl),
                            mediaType: "image/gif"
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
                    receiverLinkedType: Type<&{FungibleToken.Receiver}>(),
                    metadataLinkedType: Type<&FRC20FungibleToken.Vault>(),
                    createEmptyVaultFunction: (fun (): @FRC20FungibleToken.Vault {
                        return <-FRC20FungibleToken.createEmptyVault(vaultType: Type<@Vault>())
                    })
                )
            case Type<FungibleTokenMetadataViews.TotalSupply>():
                let indexer = FRC20Indexer.getIndexer()
                let tick = FRC20FungibleToken.getSymbol()
                if let tokenMeta = indexer.getTokenMeta(tick: tick) {
                    return FungibleTokenMetadataViews.TotalSupply(
                        totalSupply: tokenMeta.max
                    )
                } else {
                    return nil
                }
        }
        return nil
    }

    /// Function that returns all the Metadata Views implemented by a Fungible Token
    ///
    /// @return An array of Types defining the implemented views. This value will be used by
    ///         developers to know which parameter to pass to the resolveView() method.
    ///
    access(all)
    view fun getContractViews(resourceType: Type?): [Type] {
        return [
            Type<FungibleTokenMetadataViews.TotalSupply>(),
            Type<MetadataViews.ExternalURL>(),
            Type<FungibleTokenMetadataViews.FTView>(),
            Type<FungibleTokenMetadataViews.FTDisplay>(),
            Type<FungibleTokenMetadataViews.FTVaultData>()
        ]
    }

    /// Get the max supply of the token
    ///
    access(all)
    view fun getMaxSupply(): UFix64? {
        let frc20Indexer = FRC20Indexer.getIndexer()
        let tokenMeta = frc20Indexer.getTokenMeta(tick: self.getSymbol())!
        return tokenMeta.max
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

    /// Get the Token Balance of the address
    /// Including FRC20 and FungibleToken
    ///
    access(all)
    view fun getTotalBalance(_ addr: Address): UFix64 {
        return self.getFRC20Balance(addr) + self.getTokenBalance(addr)
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
        if self.account.storage.borrow<&AnyResource>(from: FRC20FTShared.SharedStoreStoragePath) == nil {
            let sharedStore <- FRC20FTShared.createSharedStore()
            self.account.storage.save(<- sharedStore, to: FRC20FTShared.SharedStoreStoragePath)
        }
        // link the resource to the public path
        if self.account
            .capabilities.get<&FRC20FTShared.SharedStore>(FRC20FTShared.SharedStorePublicPath)
            .borrow() == nil {
            self.account.capabilities.unpublish(FRC20FTShared.SharedStorePublicPath)
            self.account.capabilities.publish(
                self.account.capabilities.storage.issue<&FRC20FTShared.SharedStore>(FRC20FTShared.SharedStoreStoragePath),
                at: FRC20FTShared.SharedStorePublicPath
            )
        }
        // borrow the shared store
        let store = self.account.storage
            .borrow<auth(FRC20FTShared.Write) &FRC20FTShared.SharedStore>(from: FRC20FTShared.SharedStoreStoragePath)
            ?? panic("The shared store is not found")

        // Step.1 Try get the ticker name from the shared store
        var tickerName = store.getByEnum(FRC20FTShared.ConfigType.FungibleTokenSymbol) as! String?
        if tickerName == nil {
            // try load the ticker name from AccountPools
            let addrDict = acctsPool.getAddresses(type: FRC20AccountsPool.ChildAccountType.FungibleToken)
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
            self.account.storage.check<@FRC20Agents.IndexerController>(from: controlerPath),
            message: "The FRC20 Indexer Controller is not found"
        )

        // setup admin resource
        let cap = self.account.capabilities.storage
            .issue<auth(FRC20Agents.Manage) &FRC20Agents.IndexerController>(controlerPath)
        assert(
            cap.check(),
            message: "The capability must be valid"
        )
        let admin <- create FungibleTokenAdmin(cap: cap)
        let adminStoragePath = self.getAdminStoragePath()
        self.account.storage.save(<-admin, to: adminStoragePath)
        // link the admin resource to the public path
        self.account.capabilities.publish(
            self.account.capabilities.storage.issue<&FungibleTokenAdmin>(adminStoragePath),
            at: self.getAdminPublicPath()
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
        let vault <- create Vault(balance: 0.0)
        self.account.storage.save(<-vault, to: storagePath)

        // Create a public capability to the stored Vault that exposes
        // the `deposit` method through the `Receiver` interface.
        self.account.capabilities.publish(
            self.account.capabilities.storage.issue<&{FungibleToken.Receiver}>(storagePath),
            at: receiverPath
        )
        // Create a public capability to the stored Vault that only exposes
        // the `balance` field and the `resolveView` method through the `Balance` interface
        self.account.capabilities.publish(
            self.account.capabilities.storage.issue<&FRC20FungibleToken.Vault>(storagePath),
            at: publicPath
        )
    }
}
