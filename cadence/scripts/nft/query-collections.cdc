import "NonFungibleToken"
import "MetadataViews"

pub fun main(
    addr: Address
): {String: MetadataViews.NFTCollectionDisplay} {
    let acct = getAuthAccount(addr)

    let ret: {String: MetadataViews.NFTCollectionDisplay} = {}
    let requiredView = Type<MetadataViews.NFTCollectionDisplay>()
    acct.forEachStored(fun (path: StoragePath, type: Type): Bool {
        if type.isSubtype(of: Type<@NonFungibleToken.Collection>()) {
            if let ref = acct.borrow<&{NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(from: path) {
                let nftIds = ref.getIDs()
                if nftIds.length > 0 {
                    let viewResolver = ref.borrowViewResolver(id: nftIds[0])
                    if let view = viewResolver.resolveView(requiredView) {
                        if let display = view as? MetadataViews.NFTCollectionDisplay {
                            ret[display.name] = display
                        }
                    }
                }
            }
        }
        return true
    })
    return ret
}
