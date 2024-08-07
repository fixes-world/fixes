/**

> Author: FIXeS World <https://fixes.world/>

# FixesFungibleTokenInterface

This is the fungible token contract interface for a Fungible tokens with FixesAssetMeta.DNA metadata.

*/
import "FlowToken"
import "FungibleToken"
import "FungibleTokenMetadataViews"
// Fixes imports
import "Fixes"
import "FixesTraits"
import "FixesAssetMeta"
import "FRC20FTShared"

/// This is the contract interface for all Fixes Fungible Token
///
access(all) contract interface FixesFungibleTokenInterface {
    // ------ Events -------

    /// The event that is emitted when the metadata is updated
    access(all) event TokensMetadataInitialized(typeIdentifier: String, id: String, value: String, owner: Address?)

    /// The event that is emitted when the metadata is updated
    access(all) event TokensMetadataUpdated(typeIdentifier: String, id: String, value: String, owner: Address?)

    /// The event that is emitted when the dna metadata is updated
    access(all) event TokenDNAGenerated(identifier: String, value: String, mutatableAmount: UInt64, owner: Address?)

    /// The event that is emitted when the dna mutatable is updated
    access(all) event TokenDNAMutatableCharged(identifier: String, mutatableAmount: UInt64, owner: Address?)

    /// -------- Resources and Interfaces --------

    /// The public interface for the Fungible Token
    ///
    access(all) resource interface Metadata {
        /// Metadata: Type of MergeableData => MergeableData
        access(contract)
        let metadata: {Type: {FixesTraits.MergeableData}}

        // ----- Public Methods - implement required -----

        /// Get the symbol of the token
        access(all)
        view fun getSymbol(): String

        /// DNA charging
        access(all)
        fun chargeDNAMutatableAttempts(_ ins: &Fixes.Inscription)

        // ----- Public Methods - default implementation exsits -----

        /// Check if the vault is valid
        access(all)
        view fun isValidVault(): Bool {
            return self.borrowMergeableDataRef(Type<FixesAssetMeta.DNA>()) != nil
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

        /// Get DNA identifier
        ///
        access(all)
        view fun getDNAIdentifier(): String {
            return self.getType().identifier.concat("-").concat(self.getSymbol())
        }

        /// Get DNA owner
        ///
        access(all)
        view fun getDNAOwner(): Address? {
            if let dnaRef = self.borrowMergeableDataRef(Type<FixesAssetMeta.DNA>()) {
                if let owner = dnaRef.getValue("owner") {
                    return owner as! Address
                }
            }
            return nil
        }

        /// Get the total mutatable amount of DNA
        ///
        access(all)
        view fun getDNAMutatableAmount(): UInt64 {
            if let dnaRef = self.borrowMergeableDataRef(Type<FixesAssetMeta.DNA>()) {
                if let mutatableAmount = dnaRef.getValue("mutatableAmount") {
                    return mutatableAmount as! UInt64
                }
            }
            return 0
        }

        /// get the max mutatable amount
        ///
        access(all)
        view fun getMaxGenerateGeneAttempts(): UInt64 {
            return 2
        }

        // ---- Internal methods - implement required ----

        /// Set the metadata by key
        /// Using entitlement in Cadence 1.0
        ///
        access(contract)
        fun initializeMetadata(_ data: {FixesTraits.MergeableData}) {
            pre {
                self.borrowMergeableDataRef(data.getType()) == nil: "The metadata key already exists"
            }
        }

        /// Borrow the mergeable data by key
        ///
        access(contract)
        view fun borrowMergeableDataRef(_ type: Type): &{FixesTraits.MergeableData}? {
            return &self.metadata[type] as &{FixesTraits.MergeableData}?
        }
    }

    /// The interface for the Fungible Token MetadataGenerator
    ///
    access(all) resource interface MetadataGenerator {
        /// Attempt to generate a new gene
        ///
        access(all)
        fun attemptGenerateGene(_ attempt: UInt64): FixesAssetMeta.DNA?
    }

    /// The Implementation some method for the Metadata
    ///
    access(all) resource Vault: Metadata, MetadataGenerator {
        /// Attempt to generate a new gene
        ///
        access(all)
        fun attemptGenerateGene(_ attempt: UInt64): FixesAssetMeta.DNA? {
            var max = attempt
            if max == 0 {
                return nil
            }
            let mutatableAmt = self.getDNAMutatableAmount()
            if mutatableAmt < 1 {
                return nil
            }

            let dnaRef = self.borrowMergeableDataRef(Type<FixesAssetMeta.DNA>())
            if dnaRef == nil {
                return nil
            }

            // create a new DNA
            let newDNA = FixesAssetMeta.DNA(
                self.getDNAIdentifier(),
                self.getDNAOwner() ?? panic("The DNA owner is not found"),
                mutatableAmt,
            )
            // limit the max attempt
            if max > 10 {
                max = 10
            }
            var anyAdded = false
            var i: UInt64 = 0
            while i < max && newDNA.isMutatable() {
                if let gene = FixesAssetMeta.attemptToGenerateGene() {
                    newDNA.addGene(gene)
                    anyAdded = true
                    // break if newDNA generated
                    break
                }
                i = i + 1
            }

            if anyAdded {
                // merge the DNA
                dnaRef!.merge(newDNA)

                // update the DNA mutatable amount
                if let newMutatableAmt = newDNA.getValue("mutatableAmount") as! UInt64? {
                    dnaRef!.setValue("mutatableAmount", newMutatableAmt)
                    log("".concat(" Account: ").concat(self.getDNAOwner()?.toString() ?? "Unknown")
                        .concat("NewMutatable: ").concat(newMutatableAmt.toString()))
                }
            }
            return newDNA
        }
    }

    /// The admin interface for the FT
    ///
    access(all) resource interface IGlobalPublic {
        // ---- Readonly ----

        /// Check if the address is the admin
        access(all)
        view fun isAuthorizedUser(_ addr: Address): Bool

        /// How many tokens will be mintable
        access(all)
        view fun getGrantedMintableAmount(): UFix64 {
            return 0.0
        }

        /// Get the top 100 sorted array of holders, descending by balance
        access(all)
        view fun getEstimatedTop100Holders(): [Address]? {
            return nil
        }

        /// Get the top 1 holder
        access(all)
        view fun getTop1Holder(): Address? {
            return nil
        }

        /// Get the last top holder
        access(all)
        view fun getLastTopHolder(): Address? {
            return nil
        }

        /// Check if the address is in the top 100
        access(all)
        view fun isInTop100(_ address: Address): Bool {
            return false
        }

        /// Check if the address is the token holder
        access(all)
        view fun isTokenHolder(_ addr: Address): Bool {
            return false
        }

        /// Get the holders amount
        access(all)
        view fun getHoldersAmount(): UInt64 {
            return 0
        }
    }

    /// The admin interface for the FT
    ///
    access(all) resource interface IAdminWritable {
        /// Check if the address is the admin
        access(all)
        view fun isAuthorizedUser(_ addr: Address): Bool

        /// Borrow the super minter resource
        ///
        access(all)
        view fun borrowSuperMinter(): &{IMinter}

        /// Update the authorized users
        ///
        access(all)
        fun updateAuthorizedUsers(_ addr: Address, _ isAdd: Bool)

        /// Create a new Minter resource
        ///
        access(all)
        fun createMinter(allowedAmount: UFix64): @{IMinter}
    }

    /// The minter resource interface
    ///
    access(all) resource interface IMinter {
        /// Get the symbol of the minting token
        access(all)
        view fun getSymbol(): String

        /// Get the type of the minting token
        access(all)
        view fun getTokenType(): Type

        /// Get the key in the accounts pool
        access(all)
        view fun getAccountsPoolKey(): String?

        /// Get the contract address of the minting token
        access(all)
        view fun getContractAddress(): Address

        /// Get the max supply of the minting token
        access(all)
        view fun getMaxSupply(): UFix64

        /// Get the total supply of the minting token
        access(all)
        view fun getTotalSupply(): UFix64

        /// Get the unsupplied amount
        access(all)
        view fun getUnsuppliedAmount(): UFix64 {
            return self.getMaxSupply() - self.getTotalSupply()
        }

        /// Get the current mintable amount
        access(all)
        view fun getCurrentMintableAmount(): UFix64

        /// Get the total allowed mintable amount
        access(all)
        view fun getTotalAllowedMintableAmount(): UFix64

        /// Get the vault data of the minting token
        access(all)
        view fun getVaultData(): FungibleTokenMetadataViews.FTVaultData

        /// Function that mints new tokens, adds them to the total supply,
        /// and returns them to the calling context.
        ///
        access(all)
        fun mintTokens(amount: UFix64): @FungibleToken.Vault {
            pre {
                amount <= self.getMaxSupply() - self.getTotalSupply(): "The amount must be less than or equal to the remaining supply"
            }
        }

        /// Mint tokens with user's inscription
        ///
        access(all)
        fun initializeVaultByInscription(
            vault: @FungibleToken.Vault,
            ins: &Fixes.Inscription
        ): @FungibleToken.Vault {
            pre {
                vault.getType() == self.getTokenType(): "The vault type must be the same"
            }
            post {
                ins.isExtracted(): "The inscription must be extracted"
                before(vault.getType()) == result.getType(): "The vault type must be the same"
            }
        }

        /// Burn tokens with user's inscription
        ///
        access(all)
        fun burnTokenWithInscription(
            vault: @FungibleToken.Vault,
            ins: &Fixes.Inscription
        ) {
            pre {
                vault.getType() == self.getTokenType(): "The vault type must be the same"
            }
            post {
                ins.isExtracted(): "The inscription must be extracted"
            }
        }
    }

    /// The minter holder resource interface
    ///
    access(all) resource interface IMinterHolder {
        /// Get the total minted amount
        access(all)
        view fun getTotalMintedAmount(): UFix64 {
            let minterRef = self.borrowMinter()
            return minterRef.getTotalAllowedMintableAmount() - minterRef.getCurrentMintableAmount()
        }

        access(all)
        view fun getCurrentMintableAmount(): UFix64 {
            let minterRef = self.borrowMinter()
            return minterRef.getCurrentMintableAmount()
        }

        /// Get the total allowed mintable amount
        access(all)
        view fun getTotalAllowedMintableAmount(): UFix64 {
            let minterRef = self.borrowMinter()
            return minterRef.getTotalAllowedMintableAmount()
        }

        access(all)
        view fun isMintable(): Bool {
            return self.getCurrentMintableAmount() > 0.0
        }

        /// Get the token type
        access(all)
        view fun getTokenType(): Type {
            let minterRef = self.borrowMinter()
            return minterRef.getTokenType()
        }

        /// Get the token vault data
        access(all)
        view fun getTokenVaultData(): FungibleTokenMetadataViews.FTVaultData {
            let minterRef = self.borrowMinter()
            return minterRef.getVaultData()
        }

        /// Get the max supply of the token
        access(all)
        view fun getMaxSupply(): UFix64 {
            let minterRef = self.borrowMinter()
            return minterRef.getMaxSupply()
        }

        /// Get the circulating supply of the token
        access(all)
        view fun getCirculatingSupply(): UFix64 {
            let minterRef = self.borrowMinter()
            return minterRef.getTotalSupply()
        }

        /// Borrow the minter reference
        access(contract)
        view fun borrowMinter(): &{IMinter}
    }

    /// The public interface for the liquidity holder
    ///
    access(all) resource interface LiquidityHolder {
        // --- read methods ---

        /// Check if the address is authorized user for the liquidity holder
        access(all)
        view fun isAuthorizedUser(_ addr: Address): Bool

        /// Get the token type
        access(all)
        view fun getTokenType(): Type

        /// Get the token symbol
        access(all)
        view fun getTokenSymbol(): String

        /// Get the key in the accounts pool
        access(all)
        view fun getAccountsPoolKey(): String?

        /// Get the liquidity market cap
        access(all)
        view fun getLiquidityMarketCap(): UFix64

        /// Get the liquidity pool value
        access(all)
        view fun getLiquidityValue(): UFix64

        /// Get the flow balance in pool
        access(all)
        view fun getFlowBalanceInPool(): UFix64

        /// Get the token balance in pool
        access(all)
        view fun getTokenBalanceInPool(): UFix64

        /// Get the token price in flow
        access(all)
        view fun getTokenPriceInFlow(): UFix64

        /// Get the token price by current liquidity
        access(all)
        view fun getTokenPriceByInPoolLiquidity(): UFix64 {
            let tokenBalance = self.getTokenBalanceInPool()
            if tokenBalance == 0.0 {
                return 0.0
            }
            let currentFlowBalance = self.getFlowBalanceInPool()
            return currentFlowBalance / tokenBalance
        }

        /// Get the token price with extra liquidity
        access(all)
        view fun getTokenPriceWithExtraLiquidity(_ extraLiquidity: UFix64): UFix64 {
            let tokenBalance = self.getTokenBalanceInPool()
            if tokenBalance == 0.0 {
                return 0.0
            }
            let currentFlowBalance = self.getFlowBalanceInPool() + extraLiquidity
            return currentFlowBalance / tokenBalance
        }

        /// Get the total token market cap
        access(all)
        view fun getTotalTokenMarketCap(): UFix64

        /// Get the total token supply value
        access(all)
        view fun getTotalTokenValue(): UFix64

        /// Get the token holders
        access(all)
        view fun getHolders(): UInt64
        /// Get the trade count
        access(all)
        view fun getTrades(): UInt64

        // --- write methods ---

        /// Pull liquidity from the pool
        access(account)
        fun pullLiquidity(): @FungibleToken.Vault {
            pre {
                self.getLiquidityValue() > 0.0: "No liquidity to pull"
            }
            post {
                result.balance == before(self.getLiquidityValue()): "Invalid result balance"
                result.isInstance(Type<@FlowToken.Vault>()): "Invalid result type"
            }
        }
        /// Push liquidity to the pool
        access(account)
        fun addLiquidity(_ vault: @FungibleToken.Vault) {
            pre {
                vault.balance > 0.0: "No liquidity to push"
                vault.isInstance(Type<@FlowToken.Vault>()): "Invalid result type"
            }
        }
        /// Transfer liquidity to swap pair
        access(account)
        fun transferLiquidity(): Bool {
            post {
                result == false || self.getLiquidityValue() == 0.0: "Liquidity not transferred"
            }
        }
    }

    /// ------------ Public Functions - no default implementation ------------

    /// Get the prefix for the storage paths
    ///
    access(all)
    view fun getPathPrefix(): String

    /// ------------ Public Functions - with default implementation ------------

    /// Get the account address
    ///
    access(all)
    view fun getAccountAddress(): Address {
        return self.account.address
    }

    /// Borrow the shared store
    ///
    access(all)
    view fun borrowSharedStore(): &FRC20FTShared.SharedStore{FRC20FTShared.SharedStorePublic} {
        return FRC20FTShared.borrowStoreRef(self.account.address) ?? panic("Config store not found")
    }

    /// Get the deployer address
    ///
    access(all)
    view fun getDeployerAddress(): Address {
        let store = self.borrowSharedStore()
        let deployer = store.getByEnum(FRC20FTShared.ConfigType.FungibleTokenDeployer) as! Address?
        return deployer ?? panic("Deployer address not found")
    }

    /// Get the deployed at time
    ///
    access(all)
    view fun getDeployedAt(): UFix64 {
        let store = self.borrowSharedStore()
        let deployedAt = store.getByEnum(FRC20FTShared.ConfigType.FungibleTokenDeployedAt) as! UFix64?
        return deployedAt ?? 0.0 // Default time is 0
    }

    /// Get the ticker name of the token
    ///
    access(all)
    view fun getSymbol(): String {
        let store = self.borrowSharedStore()
        let tick = store.getByEnum(FRC20FTShared.ConfigType.FungibleTokenSymbol) as! String?
        return tick ?? panic("Ticker name not found")
    }

    /// Get the max supply of the token
    ///
    access(all)
    view fun getMaxSupply(): UFix64? {
        let store = self.borrowSharedStore()
        return store.getByEnum(FRC20FTShared.ConfigType.FungibleTokenMaxSupply) as! UFix64?
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
        let iconGif = store.get(key.concat("gif")) as! String?
        return iconPng ?? iconSvg ?? iconJpg ?? iconGif ?? iconDefault
    }

    /// Get the fungible token balance of the address
    ///
    access(all)
    view fun getTokenBalance(_ addr: Address): UFix64 {
        if let ref = self.borrowTokenMetadata(addr) {
            return ref.balance
        }
        return 0.0
    }

    /// Get the token metadata of the address
    ///
    access(all)
    view fun borrowTokenMetadata(_ addr: Address): &{FungibleToken.Balance, FixesFungibleTokenInterface.Metadata}? {
        return getAccount(addr)
            .getCapability<&{FungibleToken.Balance, FixesFungibleTokenInterface.Metadata}>(self.getVaultPublicPath())
            .borrow()
    }

    /// Borrow the vault receiver of the address
    ///
    access(all)
    view fun borrowVaultReceiver(_ addr: Address): &{FungibleToken.Receiver}? {
        return getAccount(addr)
            .getCapability<&{FungibleToken.Receiver}>(self.getReceiverPublicPath())
            .borrow()
    }

    /// Borrow the global public reference
    ///
    access(all)
    view fun borrowGlobalPublic(): &{IGlobalPublic} {
        return self.account
            .getCapability<&{IGlobalPublic}>(self.getAdminPublicPath())
            .borrow() ?? panic("The FungibleToken Admin is not found")
    }

    /// Get the storage path for the Vault
    ///
    access(all)
    view fun getVaultStoragePath(): StoragePath {
        let prefix = self.getPathPrefix()
        return StoragePath(identifier: prefix.concat("Vault"))!
    }

    /// Get the public path for the Vault
    ///
    access(all)
    view fun getVaultPublicPath(): PublicPath {
        let prefix = self.getPathPrefix()
        return PublicPath(identifier: prefix.concat("Balance"))!
    }

    /// Get the public path for the Receiver
    ///
    access(all)
    view fun getReceiverPublicPath(): PublicPath {
        let prefix = self.getPathPrefix()
        return PublicPath(identifier: prefix.concat("Receiver"))!
    }

    /// Get the admin storage path
    ///
    access(all)
    view fun getAdminStoragePath(): StoragePath {
        let prefix = self.getPathPrefix()
        return StoragePath(identifier: prefix.concat("Admin"))!
    }

    /// Get the admin public path
    ///
    access(all)
    view fun getAdminPublicPath(): PublicPath {
        let prefix = self.getPathPrefix()
        return PublicPath(identifier: prefix.concat("Admin"))!
    }

    /// Create a new vault
    access(all)
    fun createEmptyVault(): @FungibleToken.Vault
}
