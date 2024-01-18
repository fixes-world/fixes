// Third party imports
import "NonFungibleToken"
import "MetadataViews"
import "ViewResolver"
import "FungibleToken"
import "FlowToken"
// Fixes Import
import "Fixes"
import "FRC20FTShared"

access(all) contract FRC20SemiNFT: NonFungibleToken, ViewResolver {

    /// Total supply of FRC20SemiNFTs in existence
    access(all) var totalSupply: UInt64

    /// The event that is emitted when the contract is created
    access(all) event ContractInitialized()

    /// The event that is emitted when an NFT is withdrawn from a Collection
    access(all) event Withdraw(id: UInt64, from: Address?)

    /// The event that is emitted when an NFT is deposited to a Collection
    access(all) event Deposit(id: UInt64, to: Address?)

    /// The event that is emitted when an NFT is wrapped
    access(all) event Wrapped(id: UInt64, srcType: Type, srcId: UInt64)

    /// The event that is emitted when an NFT is unwrapped
    access(all) event Unwrapped(id: UInt64, srcType: Type, srcId: UInt64)

    /// Storage and Public Paths
    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let CollectionPrivatePath: PrivatePath

    /// The core resource that represents a Non Fungible Token.
    /// New instances will be created using the NFTMinter resource
    /// and stored in the Collection resource
    ///
    access(all) resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        /// The unique ID that each NFT has
        access(all) let id: UInt64

        access(self)
        var wrappedChange: @FRC20FTShared.Change?

        init(
            change: @FRC20FTShared.Change
        ) {
            self.id = self.uuid
            self.wrappedChange <- change
        }

        destroy() {
            destroy self.wrappedChange
        }

        /** ----- MetadataViews.Resolver ----- */

        /// Function that returns all the Metadata Views implemented by a Non Fungible Token
        ///
        /// @return An array of Types defining the implemented views. This value will be used by
        ///         developers to know which parameter to pass to the resolveView() method.
        ///
        access(all)
        fun getViews(): [Type] {
            var nftViews: [Type] = [
                // collection data
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                // nft view data
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.Royalties>()
            ]
            return nftViews
        }

        /// Function that resolves a metadata view for this token.
        ///
        /// @param view: The Type of the desired view.
        /// @return A structure representing the requested view.
        ///
        access(all)
        fun resolveView(_ view: Type): AnyStruct? {
            let colViews = [
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>()
            ]
            if colViews.contains(view) {
                return FRC20SemiNFT.resolveView(view)
            } else {

                switch view {
                case Type<MetadataViews.Display>():
                    // TODO: add the display view
                    return nil
                case Type<MetadataViews.Traits>():
                    let traits = MetadataViews.Traits([])
                    if let changeRef: &FRC20FTShared.Change = &self.wrappedChange as &FRC20FTShared.Change? {
                        traits.addTrait(MetadataViews.Trait(name: "originTick", value: changeRef.getOriginalTick(), nil, nil))
                        traits.addTrait(MetadataViews.Trait(name: "tick", value: changeRef.tick, nil, nil))
                        traits.addTrait(MetadataViews.Trait(name: "balance", value: changeRef.getBalance(), nil, nil))
                        let isVault = changeRef.isBackedByVault()
                        traits.addTrait(MetadataViews.Trait(name: "isFlowFT", value: isVault, nil, nil))
                        if isVault {
                            traits.addTrait(MetadataViews.Trait(name: "ftType", value: changeRef.getVaultType()!.identifier, nil, nil))
                        }
                    }
                    return traits
                case Type<MetadataViews.Royalties>():
                    // Royalties for FRC20SemiNFT is 5% to Deployer account
                    let deployerAddr = FRC20SemiNFT.account.address
                    let flowCap = getAccount(deployerAddr)
                        .getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                    return MetadataViews.Royalties([
                        MetadataViews.Royalty(
                            receiver: flowCap,
                            cut: 0.05,
                            description: "5% of the sale price of this NFT goes to the FIXeS platform account"
                        )
                    ])
                }
                return nil
            }
        }

        /** ----- Semi-NFT Methods ----- */
    }

    /// Defines the methods that are particular to this NFT contract collection
    ///
    access(all) resource interface FRC20SemiNFTCollectionPublic {
        access(all)
        fun deposit(token: @NonFungibleToken.NFT)
        access(all)
        fun getIDs(): [UInt64]
        access(all)
        fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        access(all)
        fun borrowFRC20SemiNFT(id: UInt64): &FRC20SemiNFT.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow FRC20SemiNFT reference: the ID of the returned reference is incorrect"
            }
        }
    }

    /// The resource that will be holding the NFTs inside any account.
    /// In order to be able to manage NFTs any account will need to create
    /// an empty collection first
    ///
    access(all) resource Collection: FRC20SemiNFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        access(all) var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        /// Removes an NFT from the collection and moves it to the caller
        ///
        /// @param withdrawID: The ID of the NFT that wants to be withdrawn
        /// @return The NFT resource that has been taken out of the collection
        ///
        access(all)
        fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        /// Adds an NFT to the collections dictionary and adds the ID to the id array
        ///
        /// @param token: The NFT resource to be included in the collection
        ///
        access(all)
        fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @FRC20SemiNFT.NFT

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
        access(all)
        fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        /// Gets a reference to an NFT in the collection so that
        /// the caller can read its metadata and call its methods
        ///
        /// @param id: The ID of the wanted NFT
        /// @return A reference to the wanted NFT resource
        ///
        access(all)
        fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        /// Gets a reference to an NFT in the collection so that
        /// the caller can read its metadata and call its methods
        ///
        /// @param id: The ID of the wanted NFT
        /// @return A reference to the wanted NFT resource
        ///
        access(all)
        fun borrowFRC20SemiNFT(id: UInt64): &FRC20SemiNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &FRC20SemiNFT.NFT
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
        access(all)
        fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let FRC20SemiNFT = nft as! &FRC20SemiNFT.NFT
            return FRC20SemiNFT as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    /// Allows anyone to create a new empty collection
    ///
    /// @return The new Collection resource
    ///
    access(all)
    fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    /// Function that resolves a metadata view for this contract.
    ///
    /// @param view: The Type of the desired view.
    /// @return A structure representing the requested view.
    ///
    access(all)
    fun resolveView(_ view: Type): AnyStruct? {
        switch view {
            case Type<MetadataViews.ExternalURL>():
                return MetadataViews.ExternalURL("https://fixes.world/")
            case Type<MetadataViews.NFTCollectionData>():
                return MetadataViews.NFTCollectionData(
                    storagePath: FRC20SemiNFT.CollectionStoragePath,
                    publicPath: FRC20SemiNFT.CollectionPublicPath,
                    providerPath: FRC20SemiNFT.CollectionPrivatePath,
                    publicCollection: Type<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic}>(),
                    publicLinkedType: Type<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                    providerLinkedType: Type<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                    createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                        return <-FRC20SemiNFT.createEmptyCollection()
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
                    name: "The Fixes 𝔉rc20 Semi-NFT Collection",
                    description: "This collection is used to wrap 𝔉rc20 token as semi-NFTs.",
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
    access(all)
    fun getViews(): [Type] {
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
        let identifier = "FRC20SemiNFT_".concat(self.account.address.toString())
        self.CollectionStoragePath = StoragePath(identifier: identifier.concat("collection"))!
        self.CollectionPublicPath = PublicPath(identifier: identifier.concat("collection"))!
        self.CollectionPrivatePath = PrivatePath(identifier: identifier.concat("collection"))!

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // create a public capability for the collection
        self.account.link<&FRC20SemiNFT.Collection{NonFungibleToken.CollectionPublic, FRC20SemiNFT.FRC20SemiNFTCollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        emit ContractInitialized()
    }
}
