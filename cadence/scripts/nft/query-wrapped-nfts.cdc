import "NonFungibleToken"
import "MetadataViews"
import "StringUtils"
import "FixesWrappedNFT"

pub fun main(
    addr: Address,
    page: Int,
    size: Int,
): [WrappedNFTView] {
    let standardViews = [
        // WrappedNFT not including this one
        Type<MetadataViews.Display>(),
        // WrappedNFT including all of these
        Type<MetadataViews.ExternalURL>(),
        Type<MetadataViews.NFTCollectionData>(),
        Type<MetadataViews.NFTCollectionDisplay>(),
        Type<MetadataViews.Royalties>(),
        Type<MetadataViews.Traits>()
    ]

    let collection = getAccount(addr)
        .getCapability<&FixesWrappedNFT.Collection{FixesWrappedNFT.FixesWrappedNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(
            FixesWrappedNFT.CollectionPublicPath
        ).borrow()
        ?? panic("Could not borrow capability from public collection")

    let nftIDs = collection.getIDs()
    var endIdx = page * size + size
    if endIdx > nftIDs.length {
        endIdx = nftIDs.length
    }
    let sliced = nftIDs.slice(from: page * size, upTo: endIdx)
    let ret: [WrappedNFTView] = []
    for id in sliced {
        if let nft = collection.borrowFixesWrappedNFT(id: id) {
            let nftView = MetadataViews.getNFTView(id: id, viewResolver: nft)
            let extras: [AnyStruct] = []
            if nftView.display == nil {
                let views = nft.getViews()
                for view in views {
                    if standardViews.contains(view) {
                        continue
                    }
                    extras.append(nft.resolveView(view))
                }
            }
            ret.append(WrappedNFTView(basic: nftView, extras: extras))
        }
    }
    return ret
}

pub struct WrappedNFTView {
    pub let id: UInt64
    pub let uuid: UInt64
    pub let display: MetadataViews.Display?
    pub let externalURL: MetadataViews.ExternalURL?
    pub let traits: [MetadataViews.Trait]
    pub let extras: [AnyStruct]
    init(
        basic: MetadataViews.NFTView,
        extras: [AnyStruct],
    ) {
        self.id = basic.id
        self.uuid = basic.uuid
        self.display = basic.display
        self.externalURL = basic.externalURL
        self.traits = basic.traits?.traits ?? []
        self.extras = extras
    }
}
