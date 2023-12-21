import "Fixes"

pub fun main(
    mimeType: String,
    data: String,
    protocol: String
): UFix64 {
    return Fixes.estimateValue(
        index: Fixes.totalInscriptions + 1,
        mimeType: mimeType,
        data: data.utf8,
        protocol: protocol,
        encoding: nil
    ) + 0.0005
}
