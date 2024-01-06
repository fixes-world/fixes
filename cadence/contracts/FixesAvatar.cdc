// Thirdparty Imports
import "NonFungibleToken"
import "FungibleToken"
import "MetadataViews"
// Fixes Imports
// import "Fixes"
import "FixesTraits"
import "FRC20FTShared"

/// The `FixesTraits` contract
///
pub contract FixesAvatar {
    /* --- Events --- */
    /// Event emitted when the contract is initialized
    pub event ContractInitialized()

    /* --- Variable, Enums and Structs --- */

    pub let AvatarStoragePath: StoragePath
    pub let AvatarPublicPath: PublicPath

    /* --- Interfaces & Resources --- */

    pub resource TraitHolder: MetadataViews.Resolver {

        // ---- implement Resolver ----

        /// Function that returns all the Metadata Views available for this profile
        ///
        pub fun getViews(): [Type] {
            // TODO
            return []
        }

        /// Function that resolves a metadata view for this profile
        ///
        pub fun resolveView(_ view: Type): AnyStruct? {
            // TODO
            return nil
        }
    }

    /// The resource that stores the metadata for this contract
    ///
    pub resource Profile: FRC20FTShared.TransactionHook, MetadataViews.Resolver {
        // Holds the properties for this profile, key is the property name, value is the property value
        access(self)
        let props: {String: String}
        // Holds NFTs for this profile, key is the NFT type, value is a map of NFT ID to NFT
        access(self)
        let nfts: @{Type: {UInt64: NonFungibleToken.NFT}}

        init() {
            self.props = {}
            self.nfts <- {}
        }

        destroy() {
            destroy self.nfts
        }

        // ---- implement TransactionHook ----

        /// The method that is invoked when the transaction is executed
        ///
        access(account)
        fun onDeal(
            storefront: Address,
            listingId: UInt64,
            seller: Address,
            buyer: Address,
            tick: String,
            dealAmount: UFix64,
            dealPrice: UFix64,
            totalAmountInListing: UFix64,
        ) {
            // TODO
        }

        // ---- implement Resolver ----

        /// Function that returns all the Metadata Views available for this profile
        ///
        pub fun getViews(): [Type] {
            // TODO
            return []
        }

        /// Function that resolves a metadata view for this profile
        ///
        pub fun resolveView(_ view: Type): AnyStruct? {
            // TODO
            return nil
        }
    }

    init() {
        let identifier = "FixesAvatar_".concat(self.account.address.toString())
        self.AvatarStoragePath  = StoragePath(identifier: identifier)!
        self.AvatarPublicPath = PublicPath(identifier: identifier)!

        emit ContractInitialized()
    }
}
