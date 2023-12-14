import "MetadataViews"
import "FlowToken"

/// FIXES contract to store inscriptions
///
pub contract Fixes {
    /* --- Events --- */
    /// Event emitted when the contract is initialized
    pub event ContractInitialized()
    /// Event emitted when a new inscription is created
    pub event InscriptionCreated(
        id: UInt64,
        mimeType: String,
        metadata: [UInt8],
        value: UFix64,
        metaProtocol: String?,
        encoding: String?,
        parentId: UInt64?,
    )
    pub event InscriptionBurned(id: UInt64)
    pub event InscriptionExacted(id: UInt64, value: UFix64)
    pub event InscriptionFused(from: UInt64, to: UInt64, value: UFix64)

    /* --- Variable, Enums and Structs --- */
    access(contract)
    var totalInscriptions: UInt64

    /* --- Interfaces & Resources --- */

    /// The rarity of a Inscription value
    ///
    pub enum ValueRarity: UInt8 {
        pub case Common
        pub case Uncommon
        pub case Rare
        pub case SuperRare
        pub case Epic
        pub case Legendary
    }

    /// The data of an inscription
    ///
    pub struct InscriptionData {
        /// whose value is the MIME type of the inscription
        access(all) let mimeType: String
        /// The metadata content of the inscription
        access(all) let metadata: [UInt8]
        /// The protocol used to encode the metadata
        access(all) let metaProtocol: String?
        /// The encoding used to encode the metadata
        access(all) let encoding: String?

        init(
            _ mimeType: String,
            _ metadata: [UInt8],
            _ metaProtocol: String?,
            _ encoding: String?
        ) {
            self.mimeType = mimeType
            self.metadata = metadata
            self.metaProtocol = metaProtocol
            self.encoding = encoding
        }
    }

    /// The public interface to the inscriptions
    ///
    pub resource interface InscriptionPublic {
        // identifiers
        access(all) view
        fun getId(): UInt64
        access(all) view
        fun getParentId(): UInt64?
        // data
        access(all) view
        fun getData(): InscriptionData
        access(all) view
        fun getMimeType(): String
        access(all) view
        fun getMetadata(): [UInt8]
        access(all) view
        fun getMetaProtocol(): String?
        access(all) view
        fun getContentEncoding(): String?
        // attributes
        access(all) view
        fun getInscriptionMinValue(): UFix64
        access(all) view
        fun getInscriptionRarity(): ValueRarity
        access(all) view
        fun isExacted(): Bool
    }

    /// The resource that stores the inscriptions
    ///
    pub resource Inscription: InscriptionPublic, MetadataViews.Resolver {
        /// the id of the inscription
        access(self) let id: UInt64
        /// the id of the parent inscription
        access(self) let parentId: UInt64?
        /// the data of the inscription
        access(self) let data: InscriptionData
        /// the inscription value
        access(self) var value: @FlowToken.Vault?

        init(
            value: @FlowToken.Vault,
            mimeType: String,
            metadata: [UInt8],
            metaProtocol: String?,
            encoding: String?,
            parentId: UInt64?
        ) {
            post {
                self.value?.balance ?? panic("No value") >= self.getInscriptionMinValue(): "Inscription value should be bigger than minimium $FLOW at least."
            }
            self.id = Fixes.totalInscriptions
            Fixes.totalInscriptions = Fixes.totalInscriptions + 1
            self.parentId = parentId

            self.data = InscriptionData(mimeType, metadata, metaProtocol, encoding)
            self.value <- value
        }

        destroy() {
            destroy self.value
            emit InscriptionBurned(id: self.id)
        }

        /** ------ Functionality ------  */

        /// Check if the inscription is exacted
        ///
        access(all) view
        fun isExacted(): Bool {
            return self.value == nil
        }

        /// Fuse the inscription with another inscription
        ///
        access(all)
        fun fuse(_ other: @Inscription) {
            pre {
                !self.isExacted(): "Inscription already exacted"
            }
            let otherValue <- other.exact()
            let from = other.getId()
            let fusedValue = otherValue.balance
            destroy other
            let selfValue = (&self.value as &FlowToken.Vault?)!
            selfValue.deposit(from: <- otherValue)

            emit InscriptionFused(
                from: from,
                to: self.getId(),
                value: fusedValue
            )
        }

        /// Exact the inscription value
        ///
        access(all)
        fun exact(): @FlowToken.Vault {
            pre {
                !self.isExacted(): "Inscription already exacted"
            }
            post {
                self.isExacted(): "Inscription exacted"
            }
            let balance = self.value?.balance ?? panic("No value")
            let res <- self.value <- nil
            emit InscriptionExacted(id: self.id, value: balance)
            return <- res!
        }

        /// Get the minimum value of the inscription
        ///
        access(all) view
        fun getInscriptionMinValue(): UFix64 {
            return UFix64(self.data.metadata.length) * 0.001
        }

        /// Get the rarity of the inscription
        ///
        access(all) view
        fun getInscriptionRarity(): ValueRarity {
            let value = self.value?.balance ?? panic("No value")
            if value <= 0.1 { // 0.001 ~ 0.1
                return ValueRarity.Common
            } else if value <= 10.0 { // 0.1 ~ 10
                return ValueRarity.Uncommon
            } else if value <= 1000.0 { // 10 ~ 1000
                return ValueRarity.Rare
            } else if value <= 10000.0 { // 1000 ~ 10000
                return ValueRarity.SuperRare
            } else if value <= 100000.0 { // 10000 ~ 100000
                return ValueRarity.Epic
            } else { // 100000 ~
                return ValueRarity.Legendary
            }
        }

        /** ---- Implementation of InscriptionPublic ---- */

        access(all) view
        fun getId(): UInt64 {
            return self.id
        }

        access(all) view
        fun getParentId(): UInt64? {
            return self.parentId
        }

        access(all) view
        fun getData(): InscriptionData {
            return self.data
        }

        access(all) view
        fun getMimeType(): String {
            return self.data.mimeType
        }

        access(all) view
        fun getMetadata(): [UInt8] {
            return self.data.metadata
        }

        access(all) view
        fun getMetaProtocol(): String? {
            return self.data.metaProtocol
        }

        access(all) view
        fun getContentEncoding(): String? {
            return self.data.encoding
        }

        /** ---- Implementation of MetadataViews.Resolver ---- */

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Rarity>(),
                Type<MetadataViews.Traits>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            let rarity = self.getInscriptionRarity()
            let ratityView = MetadataViews.Rarity(
                UFix64(rarity.rawValue),
                UFix64(ValueRarity.Legendary.rawValue),
                nil
            )
            switch view {
            case Type<MetadataViews.Rarity>():
                return ratityView
            case Type<MetadataViews.Traits>():
                return MetadataViews.Traits([
                    MetadataViews.Trait(name: "mimeType", value: self.getMimeType(), nil, nil),
                    MetadataViews.Trait(name: "metaProtocol", value: self.getMetaProtocol(), nil, nil),
                    MetadataViews.Trait(name: "encoding", value: self.getContentEncoding(), nil, nil),
                    MetadataViews.Trait(
                        name: "rarity",
                        value: rarity.rawValue,
                        nil,
                        ratityView
                    )
                ])
            }
            return nil
        }
    }

    /* --- Methods --- */

    /// Create a new inscription
    ///
    access(all)
    fun createInscription(
        value: @FlowToken.Vault,
        mimeType: String,
        metadata: [UInt8],
        metaProtocol: String?,
        encoding: String?,
        parentId: UInt64?
    ): @Inscription {
        let bal = value.balance
        let ins <- create Inscription(
            value: <- value,
            mimeType: mimeType,
            metadata: metadata,
            metaProtocol: metaProtocol,
            encoding: encoding,
            parentId: parentId
        )
        // emit event
        emit InscriptionCreated(
            id: ins.getId(),
            mimeType: ins.getMimeType(),
            metadata: ins.getMetadata(),
            value: bal,
            metaProtocol: ins.getMetaProtocol(),
            encoding: ins.getContentEncoding(),
            parentId: ins.getParentId(),
        )
        return <- ins
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

        emit ContractInitialized()
    }
}
