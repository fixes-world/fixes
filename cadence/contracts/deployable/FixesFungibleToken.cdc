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
import "TokenList"
import "Burner"
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

    /// The event that is emitted when new tokens are minted
    access(all) event TokensMinted(amount: UFix64)

    /// The event that is emitted when tokens are destroyed
    access(all) event TokensBurned(amount: UFix64)

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
    access(all) resource Vault: FixesFungibleTokenInterface.Vault, FungibleToken.Vault {
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

            // init with ExclusiveMeta, this meta will be removed if the initialize method is called
            let initmeta = FixesAssetMeta.ExclusiveMeta()
            self.metadata[initmeta.getType()] = initmeta
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
            return <- FixesFungibleToken.createEmptyVault(vaultType: Type<@Vault>())
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

            // remove the ExclusiveMeta
            let exclusiveMetaType = Type<FixesAssetMeta.ExclusiveMeta>()
            if self.metadata[exclusiveMetaType] != nil {
                self.metadata.remove(key: exclusiveMetaType)
            }

            /// init DNA to the metadata
            self.initializeMetadata(FixesAssetMeta.DNA(
                self.getDNAIdentifier(),
                fromAddr,
                // if inscription exists, init the DNA with the mutatable attempts
                ins != nil ? self.getMaxGenerateGeneAttempts() : 0
            ))
        }

        /// Set the metadata by key
        /// Using entitlement in Cadence 1.0
        ///
        access(contract)
        fun initializeMetadata(_ data: {FixesTraits.MergeableData}) {
            let key = data.getType()
            self.metadata[key] = data
        }

        /// --------- Implement Metadata --------- ///

        /// Get the symbol of the token
        access(all)
        view fun getSymbol(): String {
            return FixesFungibleToken.getSymbol()
        }

        /// DNA charging
        /// One inscription can activate DNA mutatable attempts.
        ///
        access(all)
        fun chargeDNAMutatableAttempts(_ ins: auth(Fixes.Extractable) &Fixes.Inscription) {
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
                let oldValue = (dnaRef.getValue("mutatableAmount") as! UInt64?) ?? 0
                // update the DNA mutatable amount
                let addAmt = self.getMaxGenerateGeneAttempts()
                dnaRef.setValue("mutatableAmount", oldValue + addAmt)
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
        access(FungibleToken.Withdraw)
        fun withdraw(amount: UFix64): @{FungibleToken.Vault} {
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

            // check if the vault has PureVault
            let isPureVault = self.borrowMergeableDataRef(Type<FixesAssetMeta.ExclusiveMeta>()) != nil
            // update metadata if the vault is not PureVault
            if !isPureVault {
                // setup mergeable data, split from withdraw percentage
                let percentage = amount / oldBalance
                let mergeableKeys = self.getMergeableKeys()
                for key in mergeableKeys {
                    if let dataRef = self.borrowMergeableDataRef(key) {
                        let splitData = dataRef.split(percentage)
                        newVault.metadata[key] = splitData

                        // emit the event
                        FixesFungibleToken.emitMetadataUpdated(
                            &self as auth(FixesFungibleTokenInterface.MetadataUpdate) &{FixesFungibleTokenInterface.Vault},
                            dataRef
                        )
                    }
                }

                // Is the vault has DNA, then attempt to generate a new gene
                self._attemptGenerateGene(amount, oldBalance)
            }

            // update the balance ranking
            let ownerAddr = self.owner?.address
            if ownerAddr != nil {
                let adminRef = FixesFungibleToken.borrowAdminPublic()
                let lastTopHolder = adminRef.getLastTopHolder()
                if lastTopHolder != ownerAddr || lastTopHolder == nil {
                    let lastTopBalance = lastTopHolder != nil ? FixesFungibleToken.getTokenBalance(lastTopHolder!) : 0.0
                    if lastTopBalance == 0.0 || (lastTopBalance > self.balance && adminRef.isInTop100(ownerAddr!)) {
                        adminRef.onBalanceChanged(ownerAddr!)
                    }
                }
                // if balance is greater than 0, then update the token holder
                if self.balance > 0.0 && !adminRef.isTokenHolder(ownerAddr!) {
                    adminRef.onTokenDeposited(ownerAddr!)
                }
            }

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
            // the interface ensured that the vault is of the same type
            // so we can safely cast it
            let vault <- from as! @FixesFungibleToken.Vault

            // try to get the current owner of the DNA
            let selfOwner = self.owner?.address
            let dnaOwner = vault.getDNAOwner()
            let currentOwner = selfOwner ?? dnaOwner

            // initialize current vault if it is not initialized
            if !self.isValidVault() && currentOwner != nil {
                self.initialize(nil, currentOwner!)
            }

            // check if the vault has PureVault
            let isPureVault = self.borrowMergeableDataRef(Type<FixesAssetMeta.ExclusiveMeta>()) != nil
            // update metadata if the vault is not PureVault
            if !isPureVault {
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
                    FixesFungibleToken.emitMetadataUpdated(
                        &self as auth(FixesFungibleTokenInterface.MetadataUpdate) &{FixesFungibleTokenInterface.Vault},
                        dataRef
                    )
                }
            }

            // record the deposited balance
            let depositedBalance = vault.balance

            // update the balance
            self.balance = self.balance + vault.balance
            // reset the balance of the from vault
            vault.balance = 0.0
            // vault is useless now
            Burner.burn(<- vault)

            // update metadata if the vault is not PureVault
            if !isPureVault {
                // Is the vault has DNA, then attempt to generate a new gene
                self._attemptGenerateGene(depositedBalance, self.balance)
            }

            // update the balance ranking
            let ownerAddr = self.owner?.address
            if ownerAddr != nil {
                let adminRef = FixesFungibleToken.borrowAdminPublic()
                let lastTopHolder = adminRef.getLastTopHolder()
                if lastTopHolder != ownerAddr || lastTopHolder == nil {
                    let lastTopBalance = lastTopHolder != nil ? FixesFungibleToken.getTokenBalance(lastTopHolder!) : 0.0
                    if lastTopBalance < self.balance {
                        adminRef.onBalanceChanged(ownerAddr!)
                    }
                }
            }
        }

        /// --------- Implement ViewResolver.Resolver --------- ///

        /// The way of getting all the Metadata Views implemented by FixesFungibleToken
        ///
        /// @return An array of Types defining the implemented views. This value will be used by
        ///         developers to know which parameter to pass to the resolveView() method.
        ///
        access(all)
        view fun getViews(): [Type] {
            let contractViews = FixesFungibleToken.getContractViews(resourceType: Type<@Vault>())
            return contractViews
        }

        /// The way of getting a Metadata View out of the FixesFungibleToken
        ///
        /// @param view: The Type of the desired view.
        /// @return A structure representing the requested view.
        ///
        access(all)
        fun resolveView(_ view: Type): AnyStruct? {
            return FixesFungibleToken.resolveContractView(resourceType: nil, viewType: view)
        }

        /// --------- Internal Methods --------- ///

        /// Borrow the mergeable data by key
        ///
        access(contract)
        view fun borrowMergeableDataRef(_ type: Type): auth(FixesTraits.Write) &{FixesTraits.MergeableData}? {
            return &self.metadata[type]
        }

        /// Attempt to generate a new gene, Max attempts is 10
        ///
        access(self)
        fun _attemptGenerateGene(_ transactedAmt: UFix64, _ totalAmt: UFix64) {
            log("-> Attempt to generate gene:"
                .concat(" Owner: ").concat(self.owner?.address?.toString() ?? "Unknown")
                .concat(" Valid: ").concat(self.isValidVault() ? "true" : "false")
                .concat(" DNA: ").concat(self.getDNAIdentifier())
                .concat(" Mutatable: ").concat(self.getDNAMutatableAmount().toString())
                .concat(" Transacted: ").concat(transactedAmt.toString())
                .concat(" Total: ").concat(totalAmt.toString()))

            let remainingAmt = self.getDNAMutatableAmount()
            if !self.isValidVault() || remainingAmt == 0 || transactedAmt == 0.0 || totalAmt == 0.0 {
                return
            }
            // every 10% of balance change will get a new attempt to mutate the DNA
            // attempt to generate a new gene
            self.attemptGenerateGene(remainingAmt)
        }
    }

    /// The interface for the FungibleTokenAdmin's global internal writable methods
    ///
    access(all) resource interface GlobalInternalWritable {
        /// update the token holder
        access(contract)
        fun onTokenDeposited(_ address: Address): Bool

        /// update the balance ranking
        access(contract)
        fun onBalanceChanged(_ address: Address): Bool
    }

    /// The admin resource for the FRC20 FT
    ///
    access(all) resource FungibleTokenAdmin: GlobalInternalWritable, FixesFungibleTokenInterface.IGlobalPublic, FixesFungibleTokenInterface.IMinterHolder, FixesFungibleTokenInterface.IAdminWritable {
        access(self)
        let minter: @Minter
        /// The amount of tokens that all created minters are allowed to mint
        access(self)
        var grantedMintableAmount: UFix64
        /// The top 100 accounts sorted by balance
        access(self)
        let top100Accounts: [Address]
        /// All token holders
        access(self)
        let tokenHolders: {Address: Bool}
        /// All authorized users
        access(self)
        let authorizedUsers: {Address: Bool}

        init() {
            self.minter <- create Minter(allowedAmount: nil)
            self.grantedMintableAmount = 0.0
            self.top100Accounts = []
            self.authorizedUsers = {}
            self.tokenHolders = {}
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

        /// Check if the address is the token holder
        access(all)
        view fun isTokenHolder(_ addr: Address): Bool {
            return self.tokenHolders[addr] == true
        }

        /// Get the holders amount
        access(all)
        view fun getHoldersAmount(): UInt64 {
            return UInt64(self.tokenHolders.length)
        }

        /// update the token holder
        access(contract)
        fun onTokenDeposited(_ address: Address): Bool {
            var isUpdated = false
            if self.tokenHolders[address] == nil {
                self.tokenHolders[address] = true
                isUpdated = true
            }
            return isUpdated
        }

        /// update the balance ranking
        ///
        access(contract)
        fun onBalanceChanged(_ address: Address): Bool {
            log("onBalanceChanged - Start - ".concat(address.toString()))
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
            log("onBalanceChanged - End - ".concat(address.toString())
                .concat(" balance: ").concat(balance.toString())
                .concat(" rank: ").concat(highBalanceIdx.toString()))
            // remove the last one if the length is greater than 100
            if self.top100Accounts.length > 100 {
                self.top100Accounts.removeLast()
            }
            return true
        }

        // ----- Implement IMinterHolder -----

        /// Borrow the minter reference
        ///
        access(contract)
        view fun borrowMinter(): auth(FixesFungibleTokenInterface.Manage) &Minter {
            return self.borrowSuperMinter()
        }

        // ------ Implement IAdminWritable ------

        /// Create a new Minter resource
        ///
        access(FixesFungibleTokenInterface.Manage)
        fun createMinter(allowedAmount: UFix64): @Minter {
            let minter <- create Minter(allowedAmount: allowedAmount)
            self.grantedMintableAmount = self.grantedMintableAmount + allowedAmount
            return <- minter
        }

        /// Update the authorized users
        ///
        access(FixesFungibleTokenInterface.Manage)
        fun updateAuthorizedUsers(_ addr: Address, _ isAdd: Bool) {
            self.authorizedUsers[addr] = isAdd
        }

        /// Borrow the super minter resource
        ///
        access(FixesFungibleTokenInterface.Manage)
        view fun borrowSuperMinter(): auth(FixesFungibleTokenInterface.Manage) &Minter {
            return &self.minter
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
        fun getVaultData(): FungibleTokenMetadataViews.FTVaultData {
            return FixesFungibleToken.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
                ?? panic("The vault data is not found")
        }

        /// Function that mints new tokens, adds them to the total supply,
        /// and returns them to the calling context.
        ///
        /// @param amount: The quantity of tokens to mint
        /// @return The Vault resource containing the minted tokens
        ///
        access(FixesFungibleTokenInterface.Manage)
        fun mintTokens(amount: UFix64): @FixesFungibleToken.Vault {
            pre {
                amount > 0.0: "Amount minted must be greater than zero"
                self.allowedAmount == nil || amount <= self.allowedAmount!: "Amount minted must be less than the allowed amount"
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
        access(FixesFungibleTokenInterface.Manage)
        fun initializeVaultByInscription(
            vault: @{FungibleToken.Vault},
            ins: auth(Fixes.Extractable) &Fixes.Inscription
        ): @{FungibleToken.Vault} {
            pre {
                vault.isInstance(Type<@FixesFungibleToken.Vault>()): "The vault must be an instance of FixesFungibleToken.Vault"
            }
            post {
                before(vault.balance) == result.balance: "The vault balance must be the same"
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

        /// Burn tokens with user's inscription
        ///
        access(FixesFungibleTokenInterface.Manage)
        fun burnTokenWithInscription(
            vault: @{FungibleToken.Vault},
            ins: auth(Fixes.Extractable) &Fixes.Inscription
        ) {
            pre {
                vault.isInstance(Type<@FixesFungibleToken.Vault>()): "The vault must be an instance of FixesFungibleToken.Vault"
            }
            // execute the inscription
            if ins.isExtractable() {
                FixesFungibleToken.executeInscription(ins: ins, usage: "burn")
            }
            Burner.burn(<- vault)
        }
    }

    /// ------------ Internal Methods ------------

    /// Exuecte and extract FlowToken in the inscription
    ///
    access(contract)
    fun executeInscription(ins: auth(Fixes.Extractable) &Fixes.Inscription, usage:String) {
        let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
        assert(
            meta["usage"] == usage || meta["usage"] == "*",
            message: "The inscription usage must be ".concat(usage)
        )
        let tick = meta["tick"] ?? panic("The ticker name is not found")
        assert(
            tick.length > 0 && tick[0] == "$" && tick == "$".concat(self.getSymbol()),
            message: "The ticker name is not matched"
        )

        // register token to the tokenlist
        TokenList.ensureFungibleTokenRegistered(self.account.address, "FixesFungibleToken")

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
        let externalUrl = FixesFungibleToken.getExternalUrl()
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
                    receiverLinkedType: Type<&{FungibleToken.Receiver}>(),
                    metadataLinkedType: Type<&FixesFungibleToken.Vault>(),
                    createEmptyVaultFunction: (fun (): @FixesFungibleToken.Vault {
                        return <-FixesFungibleToken.createEmptyVault(vaultType: Type<@Vault>())
                    })
                )
            case Type<FungibleTokenMetadataViews.TotalSupply>():
                return FungibleTokenMetadataViews.TotalSupply(
                    totalSupply: FixesFungibleToken.totalSupply
                )
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
            Type<MetadataViews.ExternalURL>(),
            Type<FungibleTokenMetadataViews.TotalSupply>(),
            Type<FungibleTokenMetadataViews.FTView>(),
            Type<FungibleTokenMetadataViews.FTDisplay>(),
            Type<FungibleTokenMetadataViews.FTVaultData>()
        ]
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
    access(contract)
    view fun borrowAdminPublic(): &FungibleTokenAdmin {
        return self.account
            .capabilities.get<&FungibleTokenAdmin>(self.getAdminPublicPath())
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
        log("Init the Fungible Token symbol:".concat(tickerName!))

        // setup admin resource
        let admin <- create FungibleTokenAdmin()
        let adminStoragePath = self.getAdminStoragePath()
        self.account.storage.save(<-admin, to: adminStoragePath)
        // link the admin resource to the public path
        let adminPublicPath = self.getAdminPublicPath()
        self.account.capabilities.publish(
            self.account.capabilities.storage.issue<&FungibleTokenAdmin>(adminStoragePath),
            at: adminPublicPath
        )

        // ensure the admin resource exists
        let adminRef = self.account.storage
            .borrow<auth(FixesFungibleTokenInterface.Manage) &FungibleTokenAdmin>(from: adminStoragePath)
            ?? panic("The FungibleToken Admin is not found")
        let deployer = self.getDeployerAddress()
        // add the deployer as the authorized user
        adminRef.updateAuthorizedUsers(deployer, true)

        // Step.2 Setup the vault and receiver for the contract account

        let storagePath = self.getVaultStoragePath()
        let publicPath = self.getVaultPublicPath()
        let receiverPath = self.getReceiverPublicPath()

        // Create the Vault with the total supply of tokens and save it in storage.
        let vault <- create Vault(balance: self.totalSupply)
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
            self.account.capabilities.storage.issue<&FixesFungibleToken.Vault>(storagePath),
            at: publicPath
        )
    }
}
