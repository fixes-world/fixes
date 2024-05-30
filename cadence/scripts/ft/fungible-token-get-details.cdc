import "FTViewUtils"
import "ViewResolver"
import "FungibleTokenMetadataViews"
// Fixes Imports
import "FRC20AccountsPool"

access(all)
fun main(
    symbol: String,
): FTViewUtils.StandardTokenView? {
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    if let ftAddress = acctsPool.getFTContractAddress(symbol) {
        let ftName = symbol[0] == "$" ? "FixesFungibleToken" : "FRC20FungibleToken"
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
    }
    return nil
}
