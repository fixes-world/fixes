import "NonFungibleToken"
import "MetadataViews"
import "Fixes"
import "FixesWrappedNFT"
import "FRC20NFTWrapper"
import "FRC20Indexer"
import "FlowToken"

transaction(
    nftCollectionIdentifier: String,
    wrappedNftId: UInt64,
) {
    let wrapper: &FRC20NFTWrapper.Wrapper{FRC20NFTWrapper.WrapperPublic}
    let targetNFTCol: &{NonFungibleToken.CollectionPublic}
    let nftToUnwrap: @FixesWrappedNFT.NFT

    prepare(acct: AuthAccount) {
        let indexerAddr = FRC20Indexer.getAddress()
        self.wrapper = FRC20NFTWrapper.borrowWrapperPublic(addr: indexerAddr)

        let wrappedNFTCol = acct
            .borrow<&FixesWrappedNFT.Collection>(from: FixesWrappedNFT.CollectionStoragePath)
            ?? panic("Could not borrow FixesWrappedNFT collection")

        self.nftToUnwrap <- wrappedNFTCol.withdraw(withdrawID: wrappedNftId) as! @FixesWrappedNFT.NFT

        // Find the nft to wrap
        let nftColType = CompositeType(nftCollectionIdentifier)!
        var nftProviderRef: &{NonFungibleToken.CollectionPublic}? = nil
        acct.forEachStored(fun (path: StoragePath, type: Type): Bool {
            if type == nftColType {
                if let colRef = acct.borrow<&{NonFungibleToken.CollectionPublic}>(from: path) {
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
        self.targetNFTCol = nftProviderRef!
    }

    execute {
        let ins <- self.wrapper.unwrap(
            recipient: self.targetNFTCol,
            nftToUnwrap: <- self.nftToUnwrap
        )
        destroy ins
    }
}
