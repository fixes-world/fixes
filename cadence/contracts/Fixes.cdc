import "MetadataViews"

/// FIXES contract to store inscriptions
///
pub contract Fixes {
    /* --- Events --- */

    pub event ContractInitialized()

    /* --- Enums and Structs --- */

    /* --- Interfaces & Resources --- */

    /// The public interface to the inscriptions
    pub resource interface InscriptionPublic {
        fun getId(): UInt64
        fun getParentId(): UInt64
        fun getMetadata(): [UInt8]
    }

    /// The resource that stores the inscriptions
    pub resource Inscription: InscriptionPublic, MetadataViews.Resolver {

        pub fun getViews(): [Type] {
            return []
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            return nil
        }
    }

    /* --- Methods --- */

    pub fun getFixesStoragePath(index: UInt64): StoragePath {
        let prefix = "Fixes_".concat(self.account.address.toString())
        return StoragePath(
            identifier: prefix.concat("_").concat(index.toString())
        )!
    }

    init() {

        emit ContractInitialized()
    }
}
