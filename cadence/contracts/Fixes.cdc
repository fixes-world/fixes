/// FIXES contract to store inscriptions
///
pub contract Fixes {
    /* --- Events --- */

    pub event ContractInitialized()

    /* --- Enums and Structs --- */

    /* --- Interfaces & Resources --- */

    pub resource interface InscriptionPublic {

    }

    pub resource Inscription: InscriptionPublic {

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
