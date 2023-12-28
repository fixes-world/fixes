import "NonFungibleToken"
import "MetadataViews"
import "Fixes"
import "FixesWrappedNFT"
import "FRC20NFTWrapper"

transaction(
    wrapperAddr: Address,
    nftCollectionIdentifier: String,
    nftId: UInt64,
    keepWrapped: Bool,
) {
    let wrapper: &FRC20NFTWrapper.Wrapper{FRC20NFTWrapper.WrapperPublic}
    let wrappedNFTCol: &FixesWrappedNFT.Collection
    let nftToWrap: @NonFungibleToken.NFT
    let nftProvider: &{NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic}

    prepare(acct: AuthAccount) {
        self.wrapper = FRC20NFTWrapper.borrowWrapperPublic(addr: wrapperAddr) ?? panic("Could not borrow public reference")

        // Create a new empty collection
        if acct.borrow<&FixesWrappedNFT.Collection>(from: FixesWrappedNFT.CollectionStoragePath) == nil {
            // Create a new empty collection
            let collection <- FixesWrappedNFT.createEmptyCollection()

            // save it to the account
            acct.save(<-collection, to: FixesWrappedNFT.CollectionStoragePath)

            // create a public capability for the collection
            acct.link<&FixesWrappedNFT.Collection{FixesWrappedNFT.FixesWrappedNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(
                FixesWrappedNFT.CollectionPublicPath,
                target: FixesWrappedNFT.CollectionStoragePath
            )
        }

        self.wrappedNFTCol = acct.borrow<&FixesWrappedNFT.Collection>(from: FixesWrappedNFT.CollectionStoragePath)!

        // Find the nft to wrap
        let nftColType = CompositeType(nftCollectionIdentifier)!
        var nftProviderRef: &{NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic}? = nil
        acct.forEachStored(fun (path: StoragePath, type: Type): Bool {
            if type == nftColType {
                if let colRef = acct.borrow<&{NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic}>(from: path) {
                    nftProviderRef = colRef
                    return false
                }
            }
            return true
        })
        assert(
            nftProviderRef != nil,
            message: "Could not find NFT collection with identifier: ".concat(nftCollectionIdentifier)
        )
        self.nftProvider = nftProviderRef!
        self.nftToWrap <- nftProviderRef!.withdraw(withdrawID: nftId)
    }

    execute {
        let newWrappedNFTId = self.wrapper.wrap(
            recipient: self.wrappedNFTCol,
            nftToWrap: <- self.nftToWrap
        )

        // If we don't want to keep the wrapped NFT, unwrap it
        // and destroy the inscription
        if !keepWrapped {
            let wrappedNft <- self.wrappedNFTCol.withdraw(withdrawID: newWrappedNFTId) as! @FixesWrappedNFT.NFT
            let ins <- FixesWrappedNFT.unwrap(
                recipient: self.nftProvider,
                nftToUnwrap: <- wrappedNft
            )
            destroy ins
        }
    }
}
