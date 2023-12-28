import "NonFungibleToken"
import "MetadataViews"
import "StringUtils"

pub fun main(
    addr: Address
): {String: MetadataViews.NFTCollectionDisplay} {
    let acct = getAuthAccount(addr)

    // set default values
    let defaultBannerMedia = MetadataViews.Media(
        file: MetadataViews.HTTPFile(url: "https://i.imgur.com/Wdy3GG7.jpg"),
        mediaType: "image/jpeg"
    )
    let defaultSquareMedia = MetadataViews.Media(
        file: MetadataViews.HTTPFile(url: "https://i.imgur.com/hs3U5CY.png"),
        mediaType: "image/png"
    )
    let defaultUrl = MetadataViews.ExternalURL("https://fixes.world/")
    let defaultSocial = {
        "twitter": MetadataViews.ExternalURL("https://twitter.com/fixesOnFlow")
    }

    let ret: {String: MetadataViews.NFTCollectionDisplay} = {}
    acct.forEachStored(fun (path: StoragePath, type: Type): Bool {
        if type.isSubtype(of: Type<@NonFungibleToken.Collection>()) {
            let valid = acct.check<@AnyResource{MetadataViews.ResolverCollection}>(from: path)
            if !valid {
                return true
            }
            if let ref = acct.borrow<&AnyResource{MetadataViews.ResolverCollection}>(from: path) {
                let nftIds = ref.getIDs()
                if nftIds.length > 0 {
                    // use the first NFT to get the collection display
                    let viewResolver = ref.borrowViewResolver(id: nftIds[0])
                    // if the collection has a display, use it
                    if let display = MetadataViews.getNFTCollectionDisplay(viewResolver) {
                        ret[type.identifier] = display
                    }
                    // if the collection has an NFT display, use it
                    else if let nftDisplay = MetadataViews.getDisplay(viewResolver) {
                        let media = MetadataViews.Media(
                            file: nftDisplay.thumbnail,
                            mediaType: "image/*"
                        )
                        ret[type.identifier] = MetadataViews.NFTCollectionDisplay(
                            name: nftDisplay.name,
                            description: nftDisplay.description,
                            externalURL: defaultUrl,
                            squareImage: media,
                            bannerImage: defaultBannerMedia,
                            socials: defaultSocial
                        )
                    } else {
                        let ids = StringUtils.split(type.identifier, ".")
                        ret[type.identifier] = MetadataViews.NFTCollectionDisplay(
                            name: ids[2],
                            description: "NFT Collection built by address ".concat(ids[1]),
                            externalURL: defaultUrl,
                            squareImage: defaultSquareMedia,
                            bannerImage: defaultSquareMedia,
                            socials: defaultSocial
                        )
                    }
                }
            }
        }
        return true
    })
    return ret
}
