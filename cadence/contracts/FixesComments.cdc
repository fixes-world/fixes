/**

> Author: FIXeS World <https://fixes.world/>

# FixesComments

This is a simple comments contract that add social media like comments to the blockchain.

*/
import "StringUtils"
import "Fixes"
import "FixesFungibleTokenInterface"

/// The contract definition
///
access(all) contract FixesComments {

    // ------ Events -------

    access(all) event CommentAdded(
        comment: String,
        image: String?,
        by: Address,
        at: UFix64,
    )

    // ---- Resource ----

    // --- Public Methods ---

    /// Get the prefix for the storage paths
    ///
    access(all)
    view fun getPathPrefix(_ minterHolder: &{FixesFungibleTokenInterface.IMinterHolder}): String {
        let identifier = StringUtils.split(minterHolder.getType().identifier, ".")
        return StringUtils.join([
            "FixesComments",
            self.account.address.toString(),
            "For",
            identifier[1],
            identifier[2],
            minterHolder.uuid.toString()
        ], "_")
    }

    /// Get the storage path for the Vault
    ///
    access(all)
    view fun getVaultStoragePath(_ res: &{FixesFungibleTokenInterface.IMinterHolder}): StoragePath {
        let prefix = self.getPathPrefix(res)
        return StoragePath(identifier: prefix.concat("Collection"))!
    }

    /// Get the public path for the Vault
    ///
    access(all)
    view fun getVaultPublicPath(_ res: &{FixesFungibleTokenInterface.IMinterHolder}): PublicPath {
        let prefix = self.getPathPrefix(res)
        return PublicPath(identifier: prefix.concat("Collection"))!
    }
}
