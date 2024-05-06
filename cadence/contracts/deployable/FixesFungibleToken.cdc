/**

> Author: FIXeS World <https://fixes.world/>

# FixesFungibleToken

This is the fungible token contract for a Mintable Fungible tokens with FixesAssetMeta.
It is the template contract that is used to deploy.

*/

import "FungibleToken"
import "ViewResolver"
import "MetadataViews"
import "FungibleTokenMetadataViews"
import "BlackHole"
// Fixes imports
import "Fixes"
import "FixesInscriptionFactory"
import "FixesFungibleTokenInterface"
import "FixesTraits"
import "FixesAssetMeta"
import "FRC20FTShared"
import "FRC20AccountsPool"

/// This is the template source for a Fixes Fungible Token
/// The contract is deployed in the child account of the FRC20AccountsPool
/// The Token is issued by Minter
access(all) contract FixesFungibleToken: FixesFungibleTokenInterface, FungibleToken, ViewResolver {
    // ------ Events -------

    /// The event that is emitted when the contract is created
    access(all) event TokensInitialized(initialSupply: UFix64)

    /// The event that is emitted when tokens are withdrawn from a Vault
    access(all) event TokensWithdrawn(amount: UFix64, from: Address?)

    /// The event that is emitted when tokens are deposited to a Vault
    access(all) event TokensDeposited(amount: UFix64, to: Address?)

    /// The event that is emitted when new tokens are minted
    access(all) event TokensMinted(amount: UFix64)

    /// The event that is emitted when tokens are destroyed
    access(all) event TokensBurned(amount: UFix64)

    /// The event that is emitted when a new minter resource is created
    access(all) event MinterCreated(allowedAmount: UFix64)

    /// The event that is emitted when the admin is updated
    access(all) event AdminUserUpdated(addr: Address, flag: Bool)

    /// The event that is emitted when the metadata is updated
    access(all) event TokensMetadataInitialized(typeIdentifier: String, id: String, value: String, owner: Address?)

    /// The event that is emitted when the metadata is updated
    access(all) event TokensMetadataUpdated(typeIdentifier: String, id: String, value: String, owner: Address?)

    /// The event that is emitted when the dna metadata is updated
    access(all) event TokenDNAGenerated(identifier: String, value: String, mutatableAmount: UInt64, owner: Address?)

    /// The event that is emitted when the dna mutatable is updated
    access(all) event TokenDNAMutatableCharged(identifier: String, mutatableAmount: UInt64, owner: Address?)

    /// -------- Parameters --------

    /// Total supply of FixesFungibleToken in existence
    /// This value is only a record of the quantity existing in the form of Flow Fungible Tokens.
    /// It does not represent the total quantity of the token that has been minted.
    /// The total quantity of the token that has been minted is loaded from the FRC20Indexer.
    access(all)
    var totalSupply: UFix64

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
    access(all) resource Vault: FixesFungibleTokenInterface.Metadata, FixesFungibleTokenInterface.MetadataGenerator, FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance, MetadataViews.Resolver {
        /// The total balance of this vault
        access(all)
        var balance: UFix64
        /// Metadata: Type of MergeableData => MergeableData
        access(contract)
        let metadata: {Type: {FixesTraits.MergeableData}}

        /// Initialize the balance at resource creation time
        init(balance: UFix64) {
            self.balance = balance
            self.metadata = {}
        }

        /// Called when a fungible token is burned via the `Burner.burn()` method
        ///
        access(contract) fun burnCallback() {
            if self.balance > 0.0 {
                // update the total supply for the FungibleToken
                FixesFungibleToken.totalSupply = FixesFungibleToken.totalSupply - self.balance
            }
            self.balance = 0.0
        }

        /// createEmptyVault
        ///
        /// Function that creates a new Vault with a balance of zero
        /// and returns it to the calling context. A user must call this function
        /// and store the returned Vault in their storage in order to allow their
        /// account to be able to receive deposits of this token type.
        ///
        access(all) fun createEmptyVault(): @Vault {
            return <- FixesFungibleToken.createEmptyVault()
        }

        /// ----- Internal Methods -----

        /// The initialize method for the Vault
        ///
        access(contract)
        fun initialize(
            _ ins: &Fixes.Inscription?,
            _ owner: Address?,
        ) {
            pre {
                ins != nil || owner != nil: "The inscription or owner must be provided"
            }
            let fromAddr = (ins != nil ? ins!.owner?.address : owner)
                ?? panic("Failed to get the owner address")

            /// init DNA to the metadata
            self.initializeMetadata(FixesAssetMeta.DNA(
                self.getDNAIdentifier(),
                fromAddr,
                // if inscription exists, init the DNA with 5 mutatable attempts
                ins != nil ? 5 : 0
            ))

            // Add deposit tax metadata
            if fromAddr != FixesFungibleToken.getAccountAddress() {
                self.initializeMetadata(FixesAssetMeta.DepositTax(nil))
            }
        }

        /// Set the metadata by key
        /// Using entitlement in Cadence 1.0
        ///
        access(contract)
        fun initializeMetadata(_ data: {FixesTraits.MergeableData}) {
            let key = data.getType()
            self.metadata[key] = data

            // emit the event
            emit TokensMetadataInitialized(
                typeIdentifier: key.identifier,
                id: data.getId(),
                value: data.toString(),
                owner: self.owner?.address
            )
        }

        /// --------- Implement Metadata --------- ///

        /// Get the symbol of the token
        access(all)
        view fun getSymbol(): String {
            return FixesFungibleToken.getSymbol()
        }

        /// DNA charging
        /// One inscription can activate 5 DNA mutatable attempts.
        ///
        access(all)
        fun chargeDNAMutatableAttempts(_ ins: &Fixes.Inscription) {
            let insOwner = ins.owner?.address ?? panic("The owner of the inscription is not found")
            assert(
                insOwner == self.owner?.address,
                message: "The owner of the inscription is not matched"
            )

            if !self.isValidVault() {
                // initialize the vault with the DNA metadata
                self.initialize(ins, nil)
            } else {
                // borrow the DNA metadata
                let dnaRef = self.borrowMergeableDataRef(Type<FixesAssetMeta.DNA>())
                    ?? panic("The DNA metadata is not found")
                let oldValue = dnaRef.getValue("mutatableAmount") as! UInt64
                // update the DNA mutatable amount
                let addAmt = self.getMaxGenerateGeneAttempts()
                dnaRef.setValue("mutatableAmount", oldValue + addAmt)

                // emit the event
                emit TokenDNAMutatableCharged(
                    identifier: self.getDNAIdentifier(),
                    mutatableAmount: oldValue + addAmt,
                    owner: self.owner?.address
                )
            }

            // execute the inscription
            FixesFungibleToken.executeInscription(ins: ins, usage: "charge")
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
        access(all)
        fun withdraw(amount: UFix64): @FungibleToken.Vault {
            pre {
                self.isAvailableToWithdraw(amount: amount): "The amount withdrawn must be less than or equal to the balance"
            }
            let oldBalance = self.balance
            // update the balance
            self.balance = self.balance - amount

            // initialize the new vault with the amount
            let newVault <- create Vault(balance: amount)

            // if current vault is valid vault(with DNA)
            if self.isValidVault() {
                newVault.initialize(nil, self.getDNAOwner())
            }

            // setup mergeable data, split from withdraw percentage
            let percentage = amount / oldBalance
            let mergeableKeys = self.getMergeableKeys()
            for key in mergeableKeys {
                if let dataRef = self.borrowMergeableDataRef(key) {
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

            // Is the vault has DNA, then attempt to generate a new gene
            self._attemptGenerateGene(amount, oldBalance)

            // update the balance ranking
            let ownerAddr = self.owner?.address
            if ownerAddr != nil {
                let adminRef = FixesFungibleToken.borrowAdminPublic()
                if let lastTopHolder = adminRef.getLastTopHolder() {
                    if lastTopHolder != ownerAddr {
                        let lastTopBalance = FixesFungibleToken.getTokenBalance(lastTopHolder)
                        if lastTopBalance > self.balance && adminRef.isInTop100(ownerAddr!) {
                            adminRef.onBalanceChanged(ownerAddr!)
                        }
                    }
                }
            }

            // emit the event
            emit TokensWithdrawn(
                amount: amount,
                from: ownerAddr
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
            // the interface ensured that the vault is of the same type
            // so we can safely cast it
            let vault <- from as! @FixesFungibleToken.Vault

            // try to get the current owner of the DNA
            let currentOwner = self.owner?.address ?? vault.getDNAOwner()

            // initialize current vault if it is not initialized
            if !self.isValidVault() && currentOwner != nil {
                self.initialize(nil, currentOwner!)
            }

            // check the deposit tax, if exists then charge the tax
            let tax = FixesFungibleToken.getDepositTaxRatio()
            if tax > 0.0 {
                if let depositTax = self.borrowMergeableDataRef(Type<FixesAssetMeta.DepositTax>())  {
                    let isEnabled = (depositTax.getValue("enabled") as? Bool) == true
                    let taxReceiver = FixesFungibleToken.getDepositTaxRecepient()
                    if isEnabled && self.owner?.address != taxReceiver {
                        let taxAmount = vault.balance * tax
                        let taxVault <- vault.withdraw(amount: taxAmount)
                        if taxReceiver != nil && FixesFungibleToken.borrowVaultReceiver(taxReceiver!) != nil {
                            let receiverRef = FixesFungibleToken.borrowVaultReceiver(taxReceiver!)!
                            receiverRef.deposit(from: <- taxVault)
                        } else {
                            // Send to the black hole instead of destroying.
                            // This can keep the totalSupply unchanged (In theory).
                            if BlackHole.isAnyBlackHoleAvailable() {
                                BlackHole.vanish(<- taxVault)
                            } else {
                                // Otherwise, destroy the taxVault
                                // TODO: Using Burner to burn the taxVault in Cadence 1.0
                                destroy taxVault
                            }
                        }
                    }
                } // end of deposit tax
            } // end of tax > 0.0

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
                emit TokensMetadataUpdated(
                    typeIdentifier: key.identifier,
                    id: dataRef.getId(),
                    value: dataRef.toString(),
                    owner: self.owner?.address
                )
            }

            // record the deposited balance
            let depositedBalance = vault.balance

            // update the balance
            self.balance = self.balance + vault.balance
            // reset the balance of the from vault
            vault.balance = 0.0
            // vault is useless now
            destroy vault

            // Is the vault has DNA, then attempt to generate a new gene
            self._attemptGenerateGene(depositedBalance, self.balance)

            // update the balance ranking
            let ownerAddr = self.owner?.address
            if ownerAddr != nil {
                let adminRef = FixesFungibleToken.borrowAdminPublic()
                if let lastTopHolder = adminRef.getLastTopHolder() {
                    if lastTopHolder != ownerAddr {
                        let lastTopBalance = FixesFungibleToken.getTokenBalance(lastTopHolder)
                        if lastTopBalance < self.balance {
                            adminRef.onBalanceChanged(ownerAddr!)
                        }
                    }
                }
            }

            emit TokensDeposited(
                amount: depositedBalance,
                to: ownerAddr
            )
        }

        /// --------- Implement MetadataViews.Resolver --------- ///

        /// The way of getting all the Metadata Views implemented by FixesFungibleToken
        ///
        /// @return An array of Types defining the implemented views. This value will be used by
        ///         developers to know which parameter to pass to the resolveView() method.
        ///
        access(all)
        fun getViews(): [Type] {
            let contractViews = FixesFungibleToken.getViews()
            return contractViews
        }

        /// The way of getting a Metadata View out of the FixesFungibleToken
        ///
        /// @param view: The Type of the desired view.
        /// @return A structure representing the requested view.
        ///
        access(all)
        fun resolveView(_ view: Type): AnyStruct? {
            return FixesFungibleToken.resolveView(view)
        }

        /// --------- Internal Methods --------- ///

        /// Borrow the mergeable data by key
        ///
        access(contract)
        view fun borrowMergeableDataRef(_ type: Type): &{FixesTraits.MergeableData}? {
            return &self.metadata[type] as &{FixesTraits.MergeableData}?
        }

        /// Attempt to generate a new gene, Max attempts is 10
        ///
        access(self)
        fun _attemptGenerateGene(_ transactedAmt: UFix64, _ totalAmt: UFix64) {
            if !self.isValidVault() || self.getDNAMutatableAmount() == 0 || totalAmt == 0.0 {
                return
            }
            // every 10% of balance change will get a new attempt to mutate the DNA
            let attempt = UInt64(transactedAmt / totalAmt / 0.1)
            // attempt to generate a new gene
            if let newMergedDNA = self.attemptGenerateGene(attempt) {
                // emit the event
                emit TokenDNAGenerated(
                    identifier: self.getDNAIdentifier(),
                    value: newMergedDNA.toString(),
                    mutatableAmount: newMergedDNA.mutatableAmount,
                    owner: self.owner?.address
                )
            }
        }
    }

    /// The admin resource for the FRC20 FT
    ///
    access(all) resource FungibleTokenAdmin: FixesFungibleTokenInterface.IGlobalPublic, FixesFungibleTokenInterface.IMinterHolder, FixesFungibleTokenInterface.IAdminWritable {
        access(self)
        let minter: @Minter
        /// The amount of tokens that all created minters are allowed to mint
        access(self)
        var grantedMintableAmount: UFix64
        /// The top 100 accounts sorted by balance
        access(self)
        let top100Accounts: [Address]
        /// All authorized users
        access(self)
        let authorizedUsers: {Address: Bool}

        init() {
            self.minter <- create Minter(allowedAmount: nil)
            self.grantedMintableAmount = 0.0
            self.top100Accounts = []
            self.authorizedUsers = {}
        }

        // @deprecated in Cadence 1.0
        destroy() {
            destroy self.minter
        }

        // ----- Implement AdminInterface -----

        access(all)
        view fun isAuthorizedUser(_ addr: Address): Bool {
            return self.authorizedUsers[addr] == true
        }

        /// Mint new tokens
        ///
        access(all)
        view fun getGrantedMintableAmount(): UFix64 {
            return self.grantedMintableAmount
        }

        /// Get the top 100 sorted array of holders, descending by balance
        ///
        access(all)
        view fun getEstimatedTop100Holders(): [Address]? {
            return self.top100Accounts
        }

        /// Get the top 1 holder
        ///
        access(all)
        view fun getTop1Holder(): Address? {
            if self.top100Accounts.length > 0 {
                return self.top100Accounts[0]
            }
            return nil
        }

        /// Get the last top holder
        ///
        access(all)
        view fun getLastTopHolder(): Address? {
            if self.top100Accounts.length > 0 {
                return self.top100Accounts[self.top100Accounts.length - 1]
            }
            return nil
        }

        /// Check if the address is in the top 100
        ///
        access(all)
        view fun isInTop100(_ address: Address): Bool {
            return self.top100Accounts.contains(address)
        }

        /// update the balance ranking
        ///
        access(account)
        fun onBalanceChanged(_ address: Address): Bool {
            // remove the address from the top 100
            if let idx = self.top100Accounts.firstIndex(of: address) {
                self.top100Accounts.remove(at: idx)
            }
            // now address is not in the top 100, we need to check balance and insert it
            let balance = FixesFungibleToken.getTokenBalance(address)
            var highBalanceIdx = 0
            var lowBalanceIdx = self.top100Accounts.length - 1
            // use binary search to find the position
            while lowBalanceIdx >= highBalanceIdx {
                let mid = (lowBalanceIdx + highBalanceIdx) / 2
                let midBalance = FixesFungibleToken.getTokenBalance(self.top100Accounts[mid])
                // find the position
                if balance > midBalance {
                    lowBalanceIdx = mid - 1
                } else if balance < midBalance {
                    highBalanceIdx = mid + 1
                } else {
                    break
                }
            }
            // insert the address
            self.top100Accounts.insert(at: highBalanceIdx, address)
            if self.top100Accounts.length >= 100 {
                self.top100Accounts.removeLast()
            }
            return true
        }

        // ----- Implement IMinterHolder -----

        /// Borrow the minter reference
        ///
        access(contract)
        view fun borrowMinter(): &{FixesFungibleTokenInterface.IMinter} {
            return self.borrowSuperMinter()
        }

        // ------ Private Methods ------

        /// Create a new Minter resource
        ///
        access(all)
        fun createMinter(allowedAmount: UFix64): @Minter {
            let minter <- create Minter(allowedAmount: allowedAmount)
            self.grantedMintableAmount = self.grantedMintableAmount + allowedAmount
            emit MinterCreated(allowedAmount: allowedAmount)
            return <- minter
        }

        /// Update the authorized users
        ///
        access(all)
        fun updateAuthorizedUsers(_ addr: Address, _ isAdd: Bool) {
            self.authorizedUsers[addr] = isAdd

            emit AdminUserUpdated(addr: addr, flag: isAdd)
        }

        /// Borrow the super minter resource
        ///
        access(all)
        fun borrowSuperMinter(): &Minter {
            return &self.minter as &Minter
        }
    }

    /// Resource object that token admin accounts can hold to mint new tokens.
    ///
    access(all) resource Minter: FixesFungibleTokenInterface.IMinter {
        /// The total allowed amount of the minting token, if nil means unlimited
        access(all)
        let totalAllowedAmount: UFix64?
        /// The amount of tokens that the minter is allowed to mint
        access(all)
        var allowedAmount: UFix64?

        init(allowedAmount: UFix64?) {
            self.totalAllowedAmount = allowedAmount
            self.allowedAmount = allowedAmount
        }

        // ----- Implement IMinter -----

        /// Get the symbol of the minting token
        ///
        access(all)
        view fun getSymbol(): String {
            return FixesFungibleToken.getSymbol()
        }

        /// Get the type of the minting token
        access(all)
        view fun getTokenType(): Type {
            return Type<@FixesFungibleToken.Vault>()
        }

        /// Get the key in the accounts pool
        access(all)
        view fun getAccountsPoolKey(): String? {
            return "$".concat(self.getSymbol())
        }

        /// Get the contract address of the minting token
        access(all)
        view fun getContractAddress(): Address {
            return FixesFungibleToken.getAccountAddress()
        }

        /// Get the max supply of the minting token
        access(all)
        view fun getMaxSupply(): UFix64 {
            return FixesFungibleToken.getMaxSupply() ?? UFix64.max
        }

        /// Get the total supply of the minting token
        ///
        access(all)
        view fun getTotalSupply(): UFix64 {
            return FixesFungibleToken.getTotalSupply()
        }

        /// Get the current mintable amount
        ///
        access(all)
        view fun getCurrentMintableAmount(): UFix64 {
            return self.allowedAmount ?? self.getUnsuppliedAmount()
        }

        /// Get the total allowed mintable amount
        ///
        access(all)
        view fun getTotalAllowedMintableAmount(): UFix64 {
            return self.totalAllowedAmount ?? self.getMaxSupply()
        }

        /// Get the vault data of the minting token
        ///
        access(all)
        view fun getVaultData(): FungibleTokenMetadataViews.FTVaultData {
            return FixesFungibleToken.resolveView(Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
                ?? panic("The vault data is not found")
        }

        /// Function that mints new tokens, adds them to the total supply,
        /// and returns them to the calling context.
        ///
        /// @param amount: The quantity of tokens to mint
        /// @return The Vault resource containing the minted tokens
        ///
        access(all)
        fun mintTokens(amount: UFix64): @FixesFungibleToken.Vault {
            pre {
                self.allowedAmount == nil || amount <= self.allowedAmount!: "Amount minted must be less than the allowed amount"
                amount > 0.0: "Amount minted must be greater than zero"
            }
            if self.allowedAmount != nil {
                self.allowedAmount = self.allowedAmount! - amount
            }

            let newVault <- create Vault(balance: amount)
            FixesFungibleToken.totalSupply = FixesFungibleToken.totalSupply + amount
            emit TokensMinted(amount: amount)
            return <- newVault
        }

        /// Mint tokens with user's inscription
        ///
        access(all)
        fun initializeVaultByInscription(
            vault: @FungibleToken.Vault,
            ins: &Fixes.Inscription
        ): @FungibleToken.Vault {
            pre {
                vault.isInstance(Type<@FixesFungibleToken.Vault>()): "The vault must be an instance of FixesFungibleToken.Vault"
            }
            let typedVault <- vault as! @FixesFungibleToken.Vault
            // ensure vault is initialized
            if !typedVault.isValidVault() {
                if ins.isExtractable() {
                    typedVault.initialize(ins, nil)
                    // execute the inscription
                    FixesFungibleToken.executeInscription(ins: ins, usage: "init")
                } else {
                    typedVault.initialize(nil, ins.owner?.address)
                }
            }
            return <- typedVault
        }
    }

    /// ------------ Internal Methods ------------

    /// Exuecte and extract FlowToken in the inscription
    ///
    access(contract)
    fun executeInscription(ins: &Fixes.Inscription, usage:String) {
        let meta = FixesInscriptionFactory.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
        assert(
            meta["usage"] == usage || meta["usage"] == "*",
            message: "The inscription usage must be ".concat(usage)
        )
        let tick = meta["tick"] ?? panic("The ticker name is not found")
        assert(
            tick[0] == "$" && tick == "$".concat(self.getSymbol()),
            message: "The ticker name is not matched"
        )
        // execute the inscription
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        acctsPool.executeInscription(type: FRC20AccountsPool.ChildAccountType.FungibleToken, ins)
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

    /// Function that resolves a metadata view for this contract.
    ///
    /// @param view: The Type of the desired view.
    /// @return A structure representing the requested view.
    ///
    access(all)
    view fun resolveView(_ view: Type): AnyStruct? {
        // external url
        let externalUrl = FixesFungibleToken.getExternalUrl()
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
                let store = FixesFungibleToken.borrowSharedStore()
                let tick = FixesFungibleToken.getSymbol()

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
                    name: FixesFungibleToken.getDisplayName() ?? tick,
                    symbol: tick,
                    description: FixesFungibleToken.getTokenDescription() ?? "No description",
                    externalURL: externalUrl != nil
                        ? MetadataViews.ExternalURL(externalUrl!)
                        : MetadataViews.ExternalURL("https://linktr.ee/fixes.world/"),
                    logos: medias.length > 0
                        ? MetadataViews.Medias(medias)
                        : MetadataViews.Medias([]),
                    socials: socialDict
                )
            case Type<FungibleTokenMetadataViews.FTVaultData>():
                let prefix = FixesFungibleToken.getPathPrefix()
                return FungibleTokenMetadataViews.FTVaultData(
                    storagePath: FixesFungibleToken.getVaultStoragePath(),
                    receiverPath: FixesFungibleToken.getReceiverPublicPath(),
                    metadataPath: FixesFungibleToken.getVaultPublicPath(),
                    providerPath: PrivatePath(identifier: prefix.concat("Vault"))!,
                    receiverLinkedType: Type<&FixesFungibleToken.Vault{FungibleToken.Receiver}>(),
                    metadataLinkedType: Type<&FixesFungibleToken.Vault{FungibleToken.Balance, MetadataViews.Resolver, FixesFungibleTokenInterface.Metadata}>(),
                    providerLinkedType: Type<&FixesFungibleToken.Vault{FungibleToken.Provider}>(),
                    createEmptyVaultFunction: (fun (): @FixesFungibleToken.Vault {
                        return <-FixesFungibleToken.createEmptyVault()
                    })
                )
            // case Type<FungibleTokenMetadataViews.TotalSupply>():
            //     let indexer = FRC20Indexer.getIndexer()
            //     let tick = FixesFungibleToken.getTickerName()
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

    /// Get the account address
    ///
    access(all)
    view fun getAccountAddress(): Address {
        return self.account.address
    }

    /// the real total supply is loaded from the FRC20Indexer
    ///
    access(all)
    view fun getTotalSupply(): UFix64 {
        return self.totalSupply
    }

    /// Get the prefix for the storage paths
    ///
    access(all)
    view fun getPathPrefix(): String {
        return "FixsStandardFT_".concat(self.account.address.toString()).concat(self.getSymbol()).concat("_")
    }

    /// Borrow the admin public reference
    ///
    access(all)
    view fun borrowAdminPublic(): &FungibleTokenAdmin{FixesFungibleTokenInterface.IGlobalPublic, FixesFungibleTokenInterface.IMinterHolder} {
        return self.account
            .getCapability<&FungibleTokenAdmin{FixesFungibleTokenInterface.IGlobalPublic, FixesFungibleTokenInterface.IMinterHolder}>(self.getAdminPublicPath())
            .borrow() ?? panic("The FungibleToken Admin is not found")
    }

    /// Initialize the contract with ticker name
    ///
    init() {
        // Initialize
        self.totalSupply = 0.0

        // Emit an event that shows that the contract was initialized
        emit TokensInitialized(initialSupply: self.totalSupply)

        // Singleton resources
        let globalStore = FRC20FTShared.borrowGlobalStoreRef()
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        let isSysmtemDeploy = self.account.address == globalStore.owner?.address
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
            var fixesFTKey: String? = nil
            // try load the ticker name from AccountPools
            let addrDict = acctsPool.getAddresses(type: FRC20AccountsPool.ChildAccountType.FungibleToken)
            let contractAddr = self.account.address
            addrDict.forEachKey(fun (key: String): Bool {
                if let addr = addrDict[key] {
                    if addr == contractAddr {
                        fixesFTKey = key
                        return false
                    }
                }
                return true
            })

            // set the ticker name
            if let foundKey = fixesFTKey {
                assert(
                    foundKey[0] == "$",
                    message: "The ticker name is invalid."
                )
                tickerName = foundKey.slice(from: 1, upTo: foundKey.length)
                store.setByEnum(FRC20FTShared.ConfigType.FungibleTokenSymbol, value: tickerName!)
            }
        }

        assert(
            tickerName != nil,
            message: "The ticker name is not found"
        )

        // setup admin resource
        let admin <- create FungibleTokenAdmin()
        let adminStoragePath = self.getAdminStoragePath()
        self.account.save(<-admin, to: adminStoragePath)
        // link the admin resource to the public path
        // @deprecated after Cadence 1.0
        self.account.link<&FixesFungibleToken.FungibleTokenAdmin{FixesFungibleTokenInterface.IGlobalPublic, FixesFungibleTokenInterface.IMinterHolder}>(
            self.getAdminPublicPath(),
            target: adminStoragePath
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
        self.account.link<&FixesFungibleToken.Vault{FungibleToken.Balance, MetadataViews.Resolver, FixesFungibleTokenInterface.Metadata}>(publicPath, target: storagePath)
    }
}
