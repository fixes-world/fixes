import "Fixes"

pub contract FRC20Indexer {
    /* --- Events --- */
    /// Event emitted when the contract is initialized
    pub event ContractInitialized()

    /// Event emitted when the owner of an inscription is updated
    pub event InscriptionOwnerUpdated(
        id: UInt64,
        owner: Address
    )

    /* --- Variable, Enums and Structs --- */
    access(all)
    let IndexerStoragePath: StoragePath
    access(all)
    let IndexerPublicPath: PublicPath

    /* --- Interfaces & Resources --- */

    /// The resource that stores the inscriptions mapping
    ///
    pub resource InscriptionIndexer {
        /// The mapping between the inscription id and the owner
        ///
        access(self)
        let mapping: {UInt64: Address}

        init() {
            self.mapping = {}
        }

        access(all)
        fun updateInscriptionOwner(ref: &Fixes.Inscription) {
            let owner = ref.owner?.address ?? panic("Inscription must have an owner to be registered")
            let id = ref.getId()

            if let oldOwner = self.mapping[id] {
                if oldOwner != owner {
                    self.mapping[id] = owner

                    emit InscriptionOwnerUpdated(
                        id: id,
                        owner: owner
                    )
                }
            }
        }

        access(all)
        fun getOwner(id: UInt64): Address? {
            return self.mapping[id]
        }
    }

    /// Get the inscription indexer
    ///
    access(all)
    fun getIndexer(): &InscriptionIndexer {
        let addr = self.account.address
        let cap = getAccount(addr)
            .capabilities
            .borrow<&InscriptionIndexer>(self.IndexerPublicPath)
        return cap ?? panic("Could not borrow InscriptionIndexer")
    }

    init() {

        let identifier = "FRC20Indexer_".concat(self.account.address.toString())
        self.IndexerStoragePath = StoragePath(identifier: identifier)!
        self.IndexerPublicPath = PublicPath(identifier: identifier)!
        // create the indexer
        self.account.save<@InscriptionIndexer>(<- create InscriptionIndexer(), to: self.IndexerStoragePath)
        let cap = self.account.capabilities.storage.issue<&InscriptionIndexer>(self.IndexerStoragePath)
        self.account.capabilities.publish(cap, at: self.IndexerPublicPath)
    }
}
