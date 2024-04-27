/**

> Author: FIXeS World <https://fixes.world/>

# FixesFungibleTokenInterface

This is the fungible token contract interface for a Fungible tokens with FixesAssetMeta.DNA metadata.

*/

import "FungibleToken"
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
            return 5
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
                ?? panic("The DNA metadata is not found")
            // create a new DNA
            let newDNA = FixesAssetMeta.DNA(
                self.getDNAIdentifier(),
                self.getDNAOwner() ?? panic("The DNA owner is not found"),
                mutatableAmt,
            )
            let maxLimit = self.getMaxGenerateGeneAttempts()
            if max > maxLimit {
                max = maxLimit
            }
            var anyAdded = false
            var i: UInt64 = 0
            while i < max && newDNA.isMutatable() {
                if let gene = FixesAssetMeta.attemptToGenerateGene() {
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
            }
            return newDNA
        }
    }

    /// The admin interface for the FT
    ///
    access(all) resource interface IAdmin {
        /// How many tokens will be mintable
        access(all)
        view fun getGrantedMintableAmount(): UFix64 {
            return 0.0
        }
    }

    /// The minter resource interface
    ///
    access(all) resource interface IMinter {
        /// Get the max supply of the minting token
        access(all)
        view fun getMaxSupply(): UFix64

        /// Get the total supply of the minting token
        access(all)
        view fun getTotalSupply(): UFix64

        /// Create an empty vault of the minting token
        access(all)
        fun createEmptyVault(): @FungibleToken.Vault {
            post {
                result.balance == 0.0: "The balance of the vault must be zero"
            }
        }

        /// Function that mints new tokens, adds them to the total supply,
        /// and returns them to the calling context.
        ///
        access(all)
        fun mintTokens(amount: UFix64): @FungibleToken.Vault {
            pre {
                amount > 0.0: "The amount must be greater than zero"
            }
        }

        /// Mint tokens with user's inscription
        ///
        access(all)
        fun mintTokensWithInscription(
            amount: UFix64,
            ins: &Fixes.Inscription?
        ): @FungibleToken.Vault {
            return <- self.mintTokens(amount: amount)
        }
    }

    /// ------------ Public Functions - no default implementation ------------

    /// Get the prefix for the storage paths
    ///
    access(all)
    view fun getPathPrefix(): String

    /// ------------ Public Functions - with default implementation ------------

    /// Borrow the shared store
    ///
    access(all)
    view fun borrowSharedStore(): &FRC20FTShared.SharedStore{FRC20FTShared.SharedStorePublic} {
        log("Borrowing shared store: ".concat(self.account.address.toString()))
        return FRC20FTShared.borrowStoreRef(self.account.address) ?? panic("Config store not found")
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
        return iconPng ?? iconSvg ?? iconJpg ?? iconDefault
    }

    /// Get the deposit tax of the Fungible Token
    ///
    access(all)
    view fun getDepositTaxRatio(): UFix64 {
        post {
            result >= 0.0: "The deposit tax ratio must be greater than or equal to 0"
            result < 1.0: "The deposit tax ratio must be less than 1"
        }
        let store = self.borrowSharedStore()
        if let tax = store.get("fungibleToken:Settings:DepositTax") {
            return tax as? UFix64 ?? 0.0
        }
        return 0.0
    }

    /// Get the deposit tax recepient
    ///
    access(all)
    view fun getDepositTaxRecepient(): Address? {
        let store = self.borrowSharedStore()
        if let addr = store.get("fungibleToken:Settings:DepositTaxRecepient") {
            return addr as? Address
        }
        return self.account.address
    }

    /// Get the fungible token balance of the address
    ///
    access(all)
    view fun getTokenBalance(_ addr: Address): UFix64 {
        if let ref = getAccount(addr)
            .getCapability<&{FungibleToken.Balance}>(self.getVaultPublicPath())
            .borrow() {
            return ref.balance
        }
        return 0.0
    }

    /// Borrow the vault receiver of the address
    ///
    access(all)
    view fun borrowVaultReceiver(_ addr: Address): &AnyResource{FungibleToken.Receiver}? {
        return getAccount(addr)
            .getCapability<&AnyResource{FungibleToken.Receiver}>(self.getReceiverPublicPath())
            .borrow()
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
}
