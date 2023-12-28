// Third party imports
import NonFungibleToken from "NonFungibleToken"
import MetadataViews from "MetadataViews"
import ViewResolver from "ViewResolver"
// Fixes Import
import "Fixes"

pub contract FixesWrappedNFT: NonFungibleToken, ViewResolver {

    /// Total supply of FixesWrappedNFTs in existence
    pub var totalSupply: UInt64

    /// The event that is emitted when the contract is created
    pub event ContractInitialized()

    /// The event that is emitted when an NFT is withdrawn from a Collection
    pub event Withdraw(id: UInt64, from: Address?)

    /// The event that is emitted when an NFT is deposited to a Collection
    pub event Deposit(id: UInt64, to: Address?)

    /// The event that is emitted when an NFT is wrapped
    pub event Wrapped(id: UInt64, srcType: Type, srcId: UInt64, inscriptionId: UInt64?)

    /// The event that is emitted when an NFT is unwrapped
    pub event Unwrapped(id: UInt64, srcType: Type, srcId: UInt64)

    /// Storage and Public Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath
    pub let CollectionPrivatePath: PrivatePath
    pub let MinterPrivatePath: PrivatePath

    /// The core resource that represents a Non Fungible Token.
    /// New instances will be created using the NFTMinter resource
    /// and stored in the Collection resource
    ///
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        /// The unique ID that each NFT has
        pub let id: UInt64

        access(self)
        var wrappedNFT: @NonFungibleToken.NFT?
        access(self)
        var wrappedInscription: @Fixes.Inscription?

        init(
            nft: @NonFungibleToken.NFT,
            inscription: @Fixes.Inscription?,
        ) {
            self.id = self.uuid
            self.wrappedNFT <- nft
            self.wrappedInscription <- inscription
        }

        destroy () {
            destroy self.wrappedNFT
            destroy self.wrappedInscription
        }

        /// Function that returns all the Metadata Views implemented by a Non Fungible Token
        ///
        /// @return An array of Types defining the implemented views. This value will be used by
        ///         developers to know which parameter to pass to the resolveView() method.
        ///
        pub fun getViews(): [Type] {
            if let nftRef = &self.wrappedNFT as &NonFungibleToken.NFT? {
                let nftViews = nftRef.getViews()
                if !nftViews.contains(Type<MetadataViews.ExternalURL>()) {
                    nftViews.append(Type<MetadataViews.ExternalURL>())
                }
                if !nftViews.contains(Type<MetadataViews.NFTCollectionData>()) {
                    nftViews.append(Type<MetadataViews.NFTCollectionData>())
                }
                if !nftViews.contains(Type<MetadataViews.NFTCollectionDisplay>()) {
                    nftViews.append(Type<MetadataViews.NFTCollectionDisplay>())
                }
                return nftViews
            }
            return []
        }

        /// Function that resolves a metadata view for this token.
        ///
        /// @param view: The Type of the desired view.
        /// @return A structure representing the requested view.
        ///
        pub fun resolveView(_ view: Type): AnyStruct? {
            let colViews = [
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>()
            ]
            if colViews.contains(view) {
                return FixesWrappedNFT.resolveView(view)
            } else {
                if let nftRef = &self.wrappedNFT as &NonFungibleToken.NFT? {
                    return nftRef.resolveView(view)
                }
                return nil
            }
        }

        /// Borrow the NFT's type
        access(all)
        fun getWrappedType(): Type? {
            if let nftRef = &self.wrappedNFT as &NonFungibleToken.NFT? {
                return nftRef.getType()
            }
            return nil
        }

        /// Check if the NFT has an NFT
        ///
        access(all)
        fun hasWrappedNFT(): Bool {
            return self.wrappedNFT != nil
        }

        /// Check if the NFT has an inscription
        ///
        access(all)
        fun hasWrappedInscription(): Bool {
            return self.wrappedInscription != nil
        }

        /// Borrow the NFT's injected inscription
        ///
        access(all)
        fun borrowInscriptionPublic(): &Fixes.Inscription{Fixes.InscriptionPublic}? {
            return self.borrowInscription()
        }

        /// Borrow the NFT's injected inscription
        ///
        access(account)
        fun borrowInscription(): &Fixes.Inscription? {
            return &self.wrappedInscription as &Fixes.Inscription?
        }

        /// Return the NFT's injected inscription
        ///
        access(account)
        fun unwrapInscription(): @Fixes.Inscription {
            pre {
                self.wrappedInscription != nil:
                    "Cannot unwrap Fixes.Inscription: the FixesWrappedNFT does not have an inscription"
            }
            post {
                self.wrappedInscription == nil:
                    "Cannot unwrap Fixes.Inscription: the FixesWrappedNFT still has an inscription"
            }
            var out: @Fixes.Inscription? <- nil
            self.wrappedInscription <-> out
            return <- out!
        }

        /// Return the NFT's injected NFT
        ///
        access(contract)
        fun unwrapNFT(): @NonFungibleToken.NFT {
            pre {
                self.wrappedNFT != nil:
                    "Cannot unwrap NFT: the FixesWrappedNFT does not have an NFT"
            }
            post {
                self.wrappedNFT == nil:
                    "Cannot unwrap NFT: the FixesWrappedNFT still has an NFT"
            }
            var out: @NonFungibleToken.NFT? <- nil
            self.wrappedNFT <-> out
            return <- out!
        }
    }

    /// Defines the methods that are particular to this NFT contract collection
    ///
    pub resource interface FixesWrappedNFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowFixesWrappedNFT(id: UInt64): &FixesWrappedNFT.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow FixesWrappedNFT reference: the ID of the returned reference is incorrect"
            }
        }
    }

    /// The resource that will be holding the NFTs inside any account.
    /// In order to be able to manage NFTs any account will need to create
    /// an empty collection first
    ///
    pub resource Collection: FixesWrappedNFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        /// Removes an NFT from the collection and moves it to the caller
        ///
        /// @param withdrawID: The ID of the NFT that wants to be withdrawn
        /// @return The NFT resource that has been taken out of the collection
        ///
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        /// Adds an NFT to the collections dictionary and adds the ID to the id array
        ///
        /// @param token: The NFT resource to be included in the collection
        ///
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @FixesWrappedNFT.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        /// Helper method for getting the collection IDs
        ///
        /// @return An array containing the IDs of the NFTs in the collection
        ///
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        /// Gets a reference to an NFT in the collection so that
        /// the caller can read its metadata and call its methods
        ///
        /// @param id: The ID of the wanted NFT
        /// @return A reference to the wanted NFT resource
        ///
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        /// Gets a reference to an NFT in the collection so that
        /// the caller can read its metadata and call its methods
        ///
        /// @param id: The ID of the wanted NFT
        /// @return A reference to the wanted NFT resource
        ///
        pub fun borrowFixesWrappedNFT(id: UInt64): &FixesWrappedNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &FixesWrappedNFT.NFT
            }

            return nil
        }

        /// Gets a reference to the NFT only conforming to the `{MetadataViews.Resolver}`
        /// interface so that the caller can retrieve the views that the NFT
        /// is implementing and resolve them
        ///
        /// @param id: The ID of the wanted NFT
        /// @return The resource reference conforming to the Resolver interface
        ///
        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let FixesWrappedNFT = nft as! &FixesWrappedNFT.NFT
            return FixesWrappedNFT as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    /// Allows anyone to create a new empty collection
    ///
    /// @return The new Collection resource
    ///
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    /// Mints a new NFT with a new ID and deposit it in the
    /// recipients collection using their collection reference
    /// -- recipient, the collection of FixesWrappedNFTs
    ///
    pub fun wrap(
        recipient: &FixesWrappedNFT.Collection{NonFungibleToken.CollectionPublic},
        nftToWrap: @NonFungibleToken.NFT,
        inscription: @Fixes.Inscription?,
    ): UInt64 {
        // info to emit
        let srcType = nftToWrap.getType()
        assert(
            srcType.identifier != Type<@FixesWrappedNFT.NFT>().identifier,
            message: "You cannot wrap a FixesWrappedNFT"
        )
        let srcId = nftToWrap.id
        let insId = inscription?.getId()

        // create a new NFT
        var newNFT <- create NFT(
            nft: <-nftToWrap,
            inscription: <-inscription,
        )
        let nftId = newNFT.id
        // deposit it in the recipient's account using their reference
        recipient.deposit(token: <-newNFT)

        FixesWrappedNFT.totalSupply = FixesWrappedNFT.totalSupply + UInt64(1)

        // emit the event
        emit Wrapped(
            id: nftId,
            srcType: srcType, srcId: srcId,
            inscriptionId: insId
        )
        return nftId
    }

    /// Unwraps an NFT and deposits it in the recipients collection
    /// using their collection reference
    /// -- recipient, the collection of wrapped NFTs
    ///
    pub fun unwrap(
        recipient: &{NonFungibleToken.CollectionPublic},
        nftToUnwrap: @FixesWrappedNFT.NFT,
    ): @Fixes.Inscription? {
        let nftId = nftToUnwrap.id
        // unwrap the NFT
        let unwrappedNFT <- nftToUnwrap.unwrapNFT()
        // info to emit
        let srcType = unwrappedNFT.getType()
        let srcId = unwrappedNFT.id
        // deposit it in the recipient's account using their reference
        recipient.deposit(token: <-unwrappedNFT)

        var out: @Fixes.Inscription? <- nil
        var insId: UInt64? = nil
        if nftToUnwrap.hasWrappedInscription() {
            // unwrap the inscription
            var ins: @Fixes.Inscription? <- nftToUnwrap.unwrapInscription()
            insId = ins?.getId()
            out <-> ins
            destroy ins
        }
        // destroy the FixesWrappedNFT
        destroy nftToUnwrap
        // decrease the total supply
        FixesWrappedNFT.totalSupply = FixesWrappedNFT.totalSupply - UInt64(1)

        // emit the event
        emit Unwrapped(
            id: nftId,
            srcType: srcType,
            srcId: srcId,
        )
        // return the inscription
        return <- out
    }

    /// Function that resolves a metadata view for this contract.
    ///
    /// @param view: The Type of the desired view.
    /// @return A structure representing the requested view.
    ///
    pub fun resolveView(_ view: Type): AnyStruct? {
        switch view {
            case Type<MetadataViews.ExternalURL>():
                return MetadataViews.ExternalURL("https://fixes.world/")
            case Type<MetadataViews.NFTCollectionData>():
                return MetadataViews.NFTCollectionData(
                    storagePath: FixesWrappedNFT.CollectionStoragePath,
                    publicPath: FixesWrappedNFT.CollectionPublicPath,
                    providerPath: FixesWrappedNFT.CollectionPrivatePath,
                    publicCollection: Type<&FixesWrappedNFT.Collection{FixesWrappedNFT.FixesWrappedNFTCollectionPublic}>(),
                    publicLinkedType: Type<&FixesWrappedNFT.Collection{FixesWrappedNFT.FixesWrappedNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                    providerLinkedType: Type<&FixesWrappedNFT.Collection{FixesWrappedNFT.FixesWrappedNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                    createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                        return <-FixesWrappedNFT.createEmptyCollection()
                    })
                )
            case Type<MetadataViews.NFTCollectionDisplay>():
                let bannerMedia = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "https://i.imgur.com/Wdy3GG7.jpg"
                    ),
                    mediaType: "image/jpeg"
                )
                let squareMedia = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "https://i.imgur.com/hs3U5CY.png"
                    ),
                    mediaType: "image/png"
                )
                return MetadataViews.NFTCollectionDisplay(
                    name: "The Fixes Wrapped NFT Collection",
                    description: "This collection is used to wrap any Flow NFT.",
                    externalURL: MetadataViews.ExternalURL("https://fixes.world/"),
                    squareImage: squareMedia,
                    bannerImage: bannerMedia,
                    socials: {
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/fixesOnFlow")
                    }
                )
        }
        return nil
    }

    /// Function that returns all the Metadata Views implemented by a Non Fungible Token
    ///
    /// @return An array of Types defining the implemented views. This value will be used by
    ///         developers to know which parameter to pass to the resolveView() method.
    ///
    pub fun getViews(): [Type] {
        return [
            Type<MetadataViews.ExternalURL>(),
            Type<MetadataViews.NFTCollectionData>(),
            Type<MetadataViews.NFTCollectionDisplay>()
        ]
    }

    init() {
        // Initialize the total supply
        self.totalSupply = 0

        // Set the named paths
        let identifier = "FixesWrappedNFT_".concat(self.account.address.toString())
        self.CollectionStoragePath = StoragePath(identifier: identifier.concat("collection"))!
        self.CollectionPublicPath = PublicPath(identifier: identifier.concat("collection"))!
        self.MinterStoragePath = StoragePath(identifier: identifier.concat("minter"))!
        self.CollectionPrivatePath = PrivatePath(identifier: identifier.concat("collection"))!
        self.MinterPrivatePath = PrivatePath(identifier: identifier.concat("minter"))!

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // create a public capability for the collection
        self.account.link<&FixesWrappedNFT.Collection{NonFungibleToken.CollectionPublic, FixesWrappedNFT.FixesWrappedNFTCollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        emit ContractInitialized()
    }
}
