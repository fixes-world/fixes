/**
> Author: FIXeS World <https://fixes.world/>

# FixesAvatar

TODO: Add description

*/

// Thirdparty Imports
import "NonFungibleToken"
import "FungibleToken"
import "MetadataViews"
import "ViewResolver"
// Fixes Imports
import "FixesTraits"
import "FRC20FTShared"

/// The `FixesAvatar` contract
///
access(all) contract FixesAvatar {

    access(all) entitlement Manage

    /* --- Events --- */

    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()

    /// Event emitted when a new trait entry is added
    access(all) event TraitEntryAdd(owner: Address?, traitId: UInt64, series: String, value: UInt8, rarity: UInt8, offset: Int8)

    /* --- Variable, Enums and Structs --- */

    access(all)
    let AvatarStoragePath: StoragePath
    access(all)
    let AvatarPublicPath: PublicPath

    /* --- Interfaces & Resources --- */

    access(all) resource interface ProfilePublic {
        access(all)
        view fun getProperty(_ name: String): String?

        access(all)
        view fun getOwnedTraitIDs(): [UInt64]

        access(all)
        view fun getOwnedTrait(_ id: UInt64): FixesTraits.TraitWithOffset?

        access(all)
        fun getOwnedTraitView(_ id: UInt64): MetadataViews.Trait?

        access(all)
        fun getEnabledTraits(): [MetadataViews.Trait]
    }

    /// The resource that stores the metadata for this contract
    ///
    access(all) resource Profile: ProfilePublic, FRC20FTShared.TransactionHook, ViewResolver.Resolver {
        // Holds the properties for this profile, key is the property name, value is the property value
        access(self)
        let properties: {String: String}
        // Holds NFTs for this profile, key is the NFT type, value is a map of NFT ID to NFT
        access(self)
        let nfts: @{Type: {UInt64: {NonFungibleToken.NFT}}}
        // Holds the owned entities for this profile
        access(self)
        let ownedEntities: @{UInt64: FixesTraits.Entry}
        // Holds the enabled entities for this profile
        access(self)
        let enabledEntities: [UInt64]

        init() {
            self.properties = {}
            self.nfts <- {}
            self.ownedEntities <- {}
            self.enabledEntities = []
        }

        // ---- implement TransactionHook ----

        /// The method that is invoked when the transaction is executed
        ///
        access(account)
        fun onDeal(
            seller: Address,
            buyer: Address,
            tick: String,
            dealAmount: UFix64,
            dealPrice: UFix64,
            storefront: Address,
            listingId: UInt64?,
        ) {
            // For season 0, we only support the following tick
            // "flows", the default tick
            // "fixes", the tick for the FIXeS platform
            let availableTicks = [
                FRC20FTShared.getPlatformStakingTickerName(),
                FRC20FTShared.getPlatformUtilityTickerName()
            ]
            if availableTicks.contains(tick) {
                if let entry <- FixesTraits.attemptToGenerateRandomEntryForSeason0() {
                    log("Generated a random entry for season 0".concat(entry.uuid.toString()))
                    self.addTraitEntry(<- entry)
                }
            }
        }

        // ---- implement Resolver ----

        /// Function that returns all the Metadata Views available for this profile
        ///
        access(all)
        view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Traits>()
            ]
        }

        /// Function that resolves a metadata view for this profile
        ///
        access(all)
        fun resolveView(_ view: Type): AnyStruct? {
            switch view {
            case Type<MetadataViews.Traits>():
                return MetadataViews.Traits(self.getEnabledTraits())
            }
            return nil
        }

        // ---- Public methods ----

        /// Get the property with the given name
        ///
        access(all)
        view fun getProperty(_ name: String): String? {
            return self.properties[name]
        }

        access(all)
        view fun getOwnedTraitIDs(): [UInt64] {
            return self.ownedEntities.keys
        }

        access(all)
        view fun getOwnedTrait(_ id: UInt64): FixesTraits.TraitWithOffset? {
            if let entry = self.borrowEntry(id) {
                return entry.getTrait()
            }
            return nil
        }

        access(all)
        fun getOwnedTraitView(_ id: UInt64): MetadataViews.Trait? {
            if let entry = self.borrowEntry(id) {
                return entry.resolveView(Type<MetadataViews.Trait>()) as! MetadataViews.Trait?
            }
            return nil
        }

        access(all)
        fun getEnabledTraits(): [MetadataViews.Trait] {
            let traits: [MetadataViews.Trait] = []
            for traitId in self.enabledEntities {
                if let entry = self.borrowEntry(traitId) {
                    if let view = entry.resolveView(Type<MetadataViews.Trait>()) {
                        traits.append(view as! MetadataViews.Trait)
                    }
                }
            }
            return traits
        }

        // ---- Account Access methods ----

        access(account)
        fun addTraitEntry(_ entry: @FixesTraits.Entry) {
            let uuid = entry.uuid
            if self.ownedEntities[uuid] != nil {
                destroy entry
                return
            }

            let trait = entry.getTrait()

            // Add the entry to the owned entities
            self.ownedEntities[uuid] <-! entry

            // emit the event
            emit TraitEntryAdd(
                owner: self.owner?.address,
                traitId: uuid,
                series: trait.series.identifier,
                value: trait.value,
                rarity: trait.rarity,
                offset: trait.offset
            )
        }

        // ---- Private methods ----

        /// Set the property with the given name to the given value
        ///
        access(Manage)
        fun setProperty(_ name: String, _ value: String) {
            self.properties[name] = value
        }

        // ---- Internal methods ----

        access(self)
        view fun borrowEntry(_ id: UInt64): auth(FixesTraits.Write) &FixesTraits.Entry? {
            return &self.ownedEntities[id]
        }
    }

    /* --- Public Functions --- */

    /// Creates a new `Profile` resource
    ///
    access(all)
    fun createProfile(): @Profile {
        return <-create Profile()
    }

    /// Returns the `Profile` public capability for the given address
    ///
    access(all)
    view fun getProfileCap(_ addr: Address): Capability<&Profile> {
        return getAccount(addr).capabilities.get<&Profile>(self.AvatarPublicPath)
    }

    /// Borrow the `Profile` reference
    ///
    access(all)
    view fun borrowProfile(_ addr: Address): &Profile? {
        return self.getProfileCap(addr).borrow()
    }

    init() {
        let identifier = "FixesAvatar_".concat(self.account.address.toString())
        self.AvatarStoragePath  = StoragePath(identifier: identifier)!
        self.AvatarPublicPath = PublicPath(identifier: identifier)!

        // Register the hooks
        FRC20FTShared.registerHookType(Type<@FixesAvatar.Profile>())

        emit ContractInitialized()
    }
}
