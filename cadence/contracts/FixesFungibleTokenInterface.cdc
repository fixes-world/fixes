/**

> Author: FIXeS World <https://fixes.world/>

# FixesFungibleTokenInterface

This is the fungible token contract interface for a Fungible tokens with FixesAssetGenes.DNA metadata.

*/

import "FungibleToken"
// Fixes imports
import "Fixes"
import "FixesTraits"
import "FixesAssetGenes"
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
            return self.borrowMergeableDataRef(Type<FixesAssetGenes.DNA>()) != nil
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
        view fun getDNAOwner(): Address {
            let dnaRef = self.borrowMergeableDataRef(Type<FixesAssetGenes.DNA>())
                ?? panic("The DNA metadata is not found")
            return dnaRef.getValue("owner") as! Address
        }

        /// Get the total mutatable amount of DNA
        ///
        access(all)
        view fun getDNAMutatableAmount(): UInt64 {
            let dnaRef = self.borrowMergeableDataRef(Type<FixesAssetGenes.DNA>())
                ?? panic("The DNA metadata is not found")
            return dnaRef.getValue("mutatableAmount") as! UInt64
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
        fun attemptGenerateGene(_ attempt: UInt64): FixesAssetGenes.DNA?
    }

    /// The Implementation some method for the Metadata
    ///
    access(all) resource Vault: Metadata, MetadataGenerator {
        /// Attempt to generate a new gene
        ///
        access(all)
        fun attemptGenerateGene(_ attempt: UInt64): FixesAssetGenes.DNA? {
            var max = attempt
            if max == 0 {
                return nil
            }

            let maxLimit = self.getMaxGenerateGeneAttempts()
            if max > maxLimit {
                max = maxLimit
            }

            let dnaRef = self.borrowMergeableDataRef(Type<FixesAssetGenes.DNA>())
                ?? panic("The DNA metadata is not found")
            let mutatableAmt = dnaRef.getValue("mutatableAmount")
            if mutatableAmt == nil {
                return nil
            }
            // create a new DNA
            let newDNA = FixesAssetGenes.DNA(
                self.getDNAIdentifier(),
                dnaRef.getValue("owner") as! Address,
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
        /// Function that mints new tokens, adds them to the total supply,
        /// and returns them to the calling context.
        ///
        access(all)
        fun mintTokens(amount: UFix64): @FungibleToken.Vault
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