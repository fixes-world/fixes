import "MetadataViews"

/// FIXES contract to store inscriptions
///
pub contract Fixes {
    /* --- Events --- */
    /// Event emitted when the contract is initialized
    pub event ContractInitialized()
    /// Event emitted when a new inscription is created
    pub event NewInscriptionCreated(
        id: UInt64,
        mimeType: String,
        metadata: [UInt8],
        metaProtocol: String?,
        encoding: String?,
        parentId: UInt64?
    )
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

    access(contract)
    var totalInscriptions: UInt64

    /* --- Interfaces & Resources --- */

    /// The public interface to the inscriptions
    ///
    pub resource interface InscriptionPublic {
        access(all) fun getId(): UInt64
        access(all) fun getParentId(): UInt64?
        access(all) fun getMimeType(): String
        access(all) fun getMetadata(): [UInt8]
        access(all) fun getMetaProtocol(): String?
        access(all) fun getContentEncoding(): String?
    }

    /// The resource that stores the inscriptions
    ///
    pub resource Inscription: InscriptionPublic, MetadataViews.Resolver {
        /// the id of the inscription
        access(self) let id: UInt64
        /// the id of the parent inscription
        access(self) let parentId: UInt64?
        /// whose value is the MIME type of the inscription
        access(self) let mimeType: String
        /// The metadata content of the inscription
        access(self) let metadata: [UInt8]
        /// The protocol used to encode the metadata
        access(self) let metaProtocol: String?
        /// The encoding used to encode the metadata
        access(self) let encoding: String?

        init(
            mimeType: String,
            metadata: [UInt8],
            metaProtocol: String?,
            encoding: String?,
            parentId: UInt64?
        ) {
            self.id = Fixes.totalInscriptions
            Fixes.totalInscriptions = Fixes.totalInscriptions + 1

            self.mimeType = mimeType
            self.metadata = metadata
            self.metaProtocol = metaProtocol
            self.encoding = encoding
            self.parentId = parentId
        }

        /** ---- Implementation of InscriptionPublic ---- */

        access(all)
        fun getId(): UInt64 {
            return self.id
        }

        access(all)
        fun getParentId(): UInt64? {
            return self.parentId
        }

        access(all)
        fun getMimeType(): String {
            return self.mimeType
        }

        access(all)
        fun getMetadata(): [UInt8] {
            return self.metadata
        }

        access(all)
        fun getMetaProtocol(): String? {
            return self.metaProtocol
        }

        access(all)
        fun getContentEncoding(): String? {
            return self.encoding
        }

        /** ---- Implementation of MetadataViews.Resolver ---- */

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Traits>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
            case Type<MetadataViews.Traits>():
                return MetadataViews.Traits([
                    MetadataViews.Trait(name: "id", value: self.getId(), nil, nil),
                    MetadataViews.Trait(name: "parentId", value: self.getParentId(), nil, nil),
                    MetadataViews.Trait(name: "mimeType", value: self.getMimeType(), nil, nil),
                    MetadataViews.Trait(name: "metaProtocol", value: self.getMetaProtocol(), nil, nil),
                    MetadataViews.Trait(name: "encoding", value: self.getContentEncoding(), nil, nil)
                ])
            }
            return nil
        }
    }

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
        fun updateInscriptionOwner(ref: &Inscription) {
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

    /* --- Methods --- */

    /// Create a new inscription
    ///
    access(all)
    fun createInscription(
        mimeType: String,
        metadata: [UInt8],
        metaProtocol: String?,
        encoding: String?,
        parentId: UInt64?
    ): @Inscription {
        let ins <- create Inscription(
            mimeType: mimeType,
            metadata: metadata,
            metaProtocol: metaProtocol,
            encoding: encoding,
            parentId: parentId
        )
        // emit event
        emit NewInscriptionCreated(
            id: ins.getId(),
            mimeType: ins.getMimeType(),
            metadata: ins.getMetadata(),
            metaProtocol: ins.getMetaProtocol(),
            encoding: ins.getContentEncoding(),
            parentId: ins.getParentId()
        )
        return <- ins
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

    /// Get the storage path of a inscription
    ///
    access(all)
    fun getFixesStoragePath(index: UInt64): StoragePath {
        let prefix = "Fixes_".concat(self.account.address.toString())
        return StoragePath(
            identifier: prefix.concat("_").concat(index.toString())
        )!
    }

    init() {
        self.totalInscriptions = 0

        let identifier = "FixesIndexer_".concat(self.account.address.toString())
        self.IndexerStoragePath = StoragePath(identifier: identifier)!
        self.IndexerPublicPath = PublicPath(identifier: identifier)!
        // create the indexer
        self.account.save<@InscriptionIndexer>(<- create InscriptionIndexer(), to: self.IndexerStoragePath)
        let cap = self.account.capabilities.storage.issue<&InscriptionIndexer>(self.IndexerStoragePath)
        self.account.capabilities.publish(cap, at: self.IndexerPublicPath)

        emit ContractInitialized()
    }
}
