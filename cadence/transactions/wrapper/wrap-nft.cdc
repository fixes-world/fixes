import "NonFungibleToken"
import "MetadataViews"
import "Fixes"
import "FixesWrappedNFT"
import "FRC20NFTWrapper"
import "FRC20Indexer"
import "FlowToken"

transaction(
    nftCollectionIdentifier: String,
    nftId: UInt64,
) {
    let wrapper: &FRC20NFTWrapper.Wrapper{FRC20NFTWrapper.WrapperPublic}
    let wrappedNFTCol: &FixesWrappedNFT.Collection
    let nftToWrap: @NonFungibleToken.NFT

    prepare(acct: AuthAccount) {
        let indexerAddr = FRC20Indexer.getAddress()
        self.wrapper = FRC20NFTWrapper.borrowWrapperPublic(addr: indexerAddr)

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
        var nftProviderRef: &{NonFungibleToken.Provider}? = nil
        acct.forEachStored(fun (path: StoragePath, type: Type): Bool {
            if type == nftColType {
                if let colRef = acct.borrow<&{NonFungibleToken.Provider}>(from: path) {
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
        self.nftToWrap <- nftProviderRef!.withdraw(withdrawID: nftId)
    }

    execute {
        self.wrapper.wrap(
            recipient: self.wrappedNFTCol,
            nftToWrap: <- self.nftToWrap
        )
    }
}
