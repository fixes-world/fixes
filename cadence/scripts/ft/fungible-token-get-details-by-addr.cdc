import "FTViewUtils"
import "ViewResolver"
import "FungibleTokenMetadataViews"
// Fixes Imports
import "FixesFungibleTokenInterface"

access(all)
fun main(
    ftAddress: Address,
): FTViewUtils.StandardTokenView? {
    let ftAcct = getAccount(ftAddress)
    var ftName = "FixesFungibleToken"
    var ftContract = ftAcct.contracts.borrow<&FixesFungibleTokenInterface>(name: ftName)
    if ftContract == nil {
        ftName = "FRC20FungibleToken"
        ftContract = ftAcct.contracts.borrow<&FixesFungibleTokenInterface>(name: ftName)
    }
    if ftContract == nil {
        return nil
    }
    if let viewResolver = getAccount(ftAddress).contracts.borrow<&ViewResolver>(name: ftName) {
        let vaultData = viewResolver.resolveView(Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
        let display = viewResolver.resolveView(Type<FungibleTokenMetadataViews.FTDisplay>()) as! FungibleTokenMetadataViews.FTDisplay?
        if vaultData == nil || display == nil {
            return nil
        }
        return FTViewUtils.StandardTokenView(
            identity: FTViewUtils.FTIdentity(ftAddress, ftName),
            decimals: 8,
            tags: [],
            dataSource: ftAddress,
            paths: FTViewUtils.StandardTokenPaths(
                vaultPath: vaultData!.storagePath,
                balancePath: vaultData!.metadataPath,
                receiverPath: vaultData!.receiverPath,
            ),
            display: FTViewUtils.FTDisplayWithSource(ftAddress, display!),
        )
    }
    return nil
}
