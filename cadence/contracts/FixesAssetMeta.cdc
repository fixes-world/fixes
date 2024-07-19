/**

> Author: FIXeS World <https://fixes.world/>

# FixesFungibleTokenGenes

This is a sub-feature contract for Fixes Asset, which implements a way to generate on-chain genes.
It is used by all Fixes' Asset.

*/
import "FungibleToken"
import "StringUtils"
import "FixesTraits"

/// The Fixes Asset Genes contract
///
access(all) contract FixesAssetMeta {

    // ----------------- DNA and Gene -----------------

    /// The gene quality level
    ///
    access(all) enum GeneQuality: UInt8 {
        // Quality scopes 0~4
        access(all) case Nascent
        access(all) case Basic
        access(all) case Enhanced
        access(all) case Augmented
        access(all) case Empowered
        // Quality scopes 5~9
        access(all) case Breakthrough
        access(all) case Advanced
        access(all) case Potent
        access(all) case Exemplary
        access(all) case Evolution
        // Quality scopes 10~15
        access(all) case Mystic
        access(all) case Arcane
        access(all) case Miraculous
        access(all) case Celestial
        access(all) case Cosmic
        access(all) case Eternal
    }

    /// Get the quality level up threshold
    /// @param from The quality level
    access(all)
    view fun getQualityLevelUpThreshold(_ from: GeneQuality): UInt64 {
        // The quality up threshold, using a 0~15 scale
        if from.rawValue < GeneQuality.Breakthrough.rawValue {
            // 0~4 Basic linear: Threshold = QualityLevel * 100 + 100 -> 100, 200, 300, 400, 500
            return UInt64(from.rawValue) * 100 + 100
        } else if from.rawValue < GeneQuality.Mystic.rawValue {
            // 5~9 Square: Threshold = (QualityLevel - 4) ^ 2 * 1000 + 1000 -> 2000, 5000, 10000, 17000, 26000
            let argValue = from.rawValue - GeneQuality.Empowered.rawValue
            return UInt64(argValue * argValue) * 1000 + 1000
        } else {
            // 10~15 Cubic: Threshold = (QualityLevel - 9) ^ 3 * 10000 + 20000
            let argValue = from.rawValue - GeneQuality.Evolution.rawValue
            return UInt64(argValue * argValue * argValue) * 10000 + 20000
        }
    }

    /// Get the quality level down threshold
    /// @param from The quality level
    /// @param to The quality level
    access(all)
    view fun getGeneMergeLossOrGain(_ from: GeneQuality, _ to: GeneQuality): UFix64 {
        // Larger quality level merge to lower quality level means gain rate
        // The gain rate = LevelDiff * 6% + 10%
        if from.rawValue > to.rawValue {
            let levelDiff = from.rawValue.saturatingSubtract(to.rawValue)
            return 1.1 + UFix64(levelDiff) * 0.06
        } else if from.rawValue < to.rawValue {
            // Otherwise, loss rate
            // The loss rate = LevelDiff * 3% + 5%
            let levelDiff = to.rawValue.saturatingSubtract(from.rawValue)
            return 0.95 - UFix64(levelDiff) * 0.03
        } else {
            return 1.0
        }
    }

    /// The gene data structure
    ///
    access(all) struct Gene: FixesTraits.MergeableData {
        access(all) let id: [Character;4]
        access(all) var quality: GeneQuality
        access(all) var exp: UInt64

        init(
            id: [Character;4]?,
            quality: GeneQuality?,
            exp: UInt64?
        ) {
            if id != nil {
                self.id = id!
            } else {
                let dnaKeys: [Character] = ["A", "C", "G", "T"]
                self.id = [
                    dnaKeys[revertibleRandom<UInt32>(modulo: 4)],
                    dnaKeys[revertibleRandom<UInt32>(modulo: 4)],
                    dnaKeys[revertibleRandom<UInt32>(modulo: 4)],
                    dnaKeys[revertibleRandom<UInt32>(modulo: 4)]
                ]
            }
            self.quality = quality ?? GeneQuality.Nascent
            self.exp = exp ?? 0
            // Log the gene creation
            log("Created Gene["
                .concat(self.id[0].toString()).concat(self.id[1].toString()).concat(self.id[2].toString()).concat(self.id[3].toString())
                .concat("]: quality=").concat(self.quality.rawValue.toString()).concat(", exp=").concat(self.exp.toString())
            )
        }

        /// Get the id of the data
        ///
        access(all)
        view fun getId(): String {
            return String.fromCharacters([self.id[0], self.id[1], self.id[2], self.id[3]])
        }

        /// Get the string value of the data
        ///
        access(all)
        view fun toString(): String {
            return self.getId().concat("|")
            .concat(self.quality.rawValue.toString()).concat("=")
            .concat(self.exp.toString())
        }

        /// Get the data keys
        ///
        access(all)
        view fun getKeys(): [String] {
            return ["id", "quality", "exp"]
        }

        /// Get the value of the data
        ///
        access(all)
        view fun getValue(_ key: String): AnyStruct? {
            if key == "id" {
                return self.getId()
            } else if key == "quality" {
                return self.quality
            } else if key == "exp" {
                return self.exp
            }
            return nil
        }

        /// Split the data into another instance
        access(FixesTraits.Write)
        fun split(_ perc: UFix64): {FixesTraits.MergeableData} {
            post {
                self.getId() == result.getId(): "The gene id is not the same so cannot split"
            }
            let withdrawexp = UInt64(UInt256(self.exp) * UInt256(perc * 100000.0) / 100000)
            if withdrawexp > 0 {
                self.exp = self.exp - withdrawexp
            }

            log("Split Gene["
                .concat(self.id[0].toString()).concat(self.id[1].toString()).concat(self.id[2].toString()).concat(self.id[3].toString())
                .concat("]: A=").concat(self.exp.toString()).concat(", B=").concat(withdrawexp.toString())
                .concat(", quality=").concat(self.quality.rawValue.toString()))

            // Create a new struct
            let newGenes: FixesAssetMeta.Gene = Gene(
                id: self.id,
                quality: self.quality, // same quality
                exp: withdrawexp, // splited the exp
            )
            return newGenes
        }

        /// Merge the data from another instance
        /// From and Self must have the same id and same type(Ensured by interface)
        ///
        access(FixesTraits.Write)
        fun merge(_ from: {FixesTraits.MergeableData}): Void {
            pre {
                self.getId() == from.getId(): "The gene id is not the same so cannot merge"
            }
            let oldExp = self.exp
            let fromGenes = from as! Gene
            let convertRate = FixesAssetMeta.getGeneMergeLossOrGain(fromGenes.quality, self.quality)
            let convertexp = UInt64(UInt128(fromGenes.exp) * UInt128(convertRate * 10000.0) / 10000)
            self.exp = self.exp + convertexp

            log("Merge Gene["
                .concat(self.id[0].toString()).concat(self.id[1].toString()).concat(self.id[2].toString()).concat(self.id[3].toString())
                .concat("]: ExpOld=").concat(oldExp.toString()).concat(", ExpNew=").concat(self.exp.toString()
                .concat(", quality=").concat(self.quality.rawValue.toString())))

            // check if the quality can be upgraded
            var upgradeThreshold = FixesAssetMeta.getQualityLevelUpThreshold(self.quality)
            var isUpgradable = upgradeThreshold <= self.exp && self.quality.rawValue < GeneQuality.Eternal.rawValue
            while isUpgradable {
                self.quality = GeneQuality(rawValue: self.quality.rawValue + 1)!
                self.exp = self.exp - upgradeThreshold
                // check upgrade again
                upgradeThreshold = FixesAssetMeta.getQualityLevelUpThreshold(self.quality)
                isUpgradable = upgradeThreshold <= self.exp && self.quality.rawValue < GeneQuality.Eternal.rawValue

                log("Upgrade Gene["
                    .concat(self.id[0].toString()).concat(self.id[1].toString()).concat(self.id[2].toString()).concat(self.id[3].toString())
                    .concat("]: Exp=").concat(self.exp.toString()).concat(", quality=").concat(self.quality.rawValue.toString()))
            }
        }
    }

    /// The DNA data structure
    ///
    access(all) struct DNA: FixesTraits.MergeableData {
        access(all) let identifier: String
        access(all) let owner: Address
        access(all) let genes: {String: Gene}
        access(all) var mutatableAmount: UInt64

        view init(
            _ identifier: String,
            _ owner: Address,
            _ mutatableAmount: UInt64?
        ) {
            self.owner = owner
            self.identifier = identifier
            self.genes = {}
            self.mutatableAmount = mutatableAmount ?? 0
        }

        /// Get the id of the data
        ///
        access(all)
        view fun getId(): String {
            return self.identifier.concat("@").concat(self.owner.toString())
        }

        /// Get the string value of the data
        ///
        access(all)
        view fun toString(): String {
            var genes: String = ""
            for key in self.genes.keys {
                let geneStr = self.genes[key]!.toString()
                if genes != "" {
                    genes = genes.concat(",")
                }
                genes = genes.concat(geneStr)
            }
            return genes
        }

        /// Get the data keys
        ///
        access(all)
        view fun getKeys(): [String] {
            return ["identifier", "owner", "genes", "mutatableAmount"]
        }

        /// Get the value of the data
        /// It means genes keys of the DNA
        ///
        access(all)
        view fun getValue(_ key: String): AnyStruct? {
            if key == "identifier" {
                return self.identifier
            } else if key == "owner" {
                return self.owner
            } else if key == "genes" {
                return self.genes.keys
            } else if key == "mutatableAmount" {
                return self.mutatableAmount
            }
            return nil
        }

        /// Get the writable keys
        ///
        access(all)
        view fun getWritableKeys(): [String] {
            return ["mutatableAmount"]
        }

        /// Set the value of the data
        ///
        access(FixesTraits.Write)
        fun setValue(_ key: String, _ value: AnyStruct) {
            if key == "mutatableAmount" {
                self.mutatableAmount = value as! UInt64
            }
        }

        /// Split the data into another instance
        ///
        access(FixesTraits.Write)
        fun split(_ perc: UFix64): {FixesTraits.MergeableData} {
            post {
                self.getId() == result.getId(): "The result id is not the same so cannot split"
            }
            let newDna = DNA(self.identifier, self.owner, nil)
            // No need to split
            if perc == 0.0 {
                return newDna
            }
            // Mutate the mutatable amount
            if perc >= 1.0 {
                newDna.mutatableAmount = self.mutatableAmount
                self.mutatableAmount = 0
            }
            // Split the genes
            for key in self.genes.keys {
                // Split the gene, use reference to ensure data consistency
                if let geneRef = &self.genes[key] as auth(FixesTraits.Write) &Gene? {
                    let geneId = geneRef.getId()
                    // add the new gene to the new DNA
                    let newGene = geneRef.split(perc) as! Gene
                    // Don't add the gene if the exp is 0
                    if newGene.exp > 0 {
                        newDna.genes[geneId] = newGene
                    }
                }
            }
            return newDna
        }

        /// Merge the data from another instance
        /// The type of the data must be the same(Ensured by interface)
        ///
        access(FixesTraits.Write)
        fun merge(_ from: {FixesTraits.MergeableData}): Void {
            let fromDna = from as! DNA
            // identifer must be the same
            assert(
                self.identifier == fromDna.identifier,
                message: "The DNA identifier is not the same so cannot merge"
            )
            for key in fromDna.genes.keys {
                if let fromGene = fromDna.genes[key] {
                    if fromGene.exp == 0 {
                        continue
                    }
                    self.mergeGene(fromGene)
                }
            } // end for
            // merge mutatable amount
            self.mutatableAmount = self.mutatableAmount + fromDna.mutatableAmount
        }

        // ---- Customized Methods ----

        /// Check if the DNA is mutatable
        ///
        access(all)
        view fun isMutatable(): Bool {
            return self.mutatableAmount > 0
        }

        /// Add a gene to the DNA
        ///
        access(account)
        fun addGene(_ gene: Gene): Void {
            pre {
                self.isMutatable(): "The DNA is not mutatable"
            }
            self.mergeGene(gene)
            // Decrease the mutatable amount
            self.mutatableAmount = self.mutatableAmount - 1
        }

        /// Merge a gene to the DNA
        ///
        access(self)
        fun mergeGene(_ gene: Gene): Void {
            let geneId = gene.getId()
            // Merge the gene, use reference to ensure data consistency
            if let geneRef = &self.genes[geneId] as auth(FixesTraits.Write) &Gene? {
                geneRef.merge(gene)
            } else {
                // If the gene is not exist, just copy it
                self.genes[geneId] = gene
            }
        }
    }

    /// Try mutate or generate a new gene
    ///
    access(all)
    fun attemptToGenerateGene(): Gene? {
        // 30% to generate a gene
        let rand = revertibleRandom<UInt64>(modulo: 10000)
        var quality = GeneQuality.Nascent
        if rand < 2 {
            // 0.02% to generate a gene with quality Miraculous
            quality = GeneQuality.Miraculous
        } else if rand < 5 {
            // 0.03% to generate a gene with quality Arcane
            quality = GeneQuality.Arcane
        } else if rand < 10 {
            // 0.05% to generate a gene with quality Mystic
            quality = GeneQuality.Mystic
        } else if rand < 20 {
            // 0.10% to generate a gene with quality Evolution
            quality = GeneQuality.Evolution
        } else if rand < 40 {
            // 0.20% to generate a gene with quality Exemplary
            quality = GeneQuality.Exemplary
        } else if rand < 70 {
            // 0.30% to generate a gene with quality Potent
            quality = GeneQuality.Potent
        } else if rand < 120 {
            // 0.50% to generate a gene with quality Advanced
            quality = GeneQuality.Advanced
        } else if rand < 200 {
            // 0.80% to generate a gene with quality Breakthrough
            quality = GeneQuality.Breakthrough
        } else if rand < 350 {
            // 1.50% to generate a gene with quality Empowered
            quality = GeneQuality.Empowered
        } else if rand < 600 {
            // 2.50% to generate a gene with quality Augmented
            quality = GeneQuality.Augmented
        } else if rand < 1000 {
            // 4.00% to generate a gene with quality Enhanced
            quality = GeneQuality.Enhanced
        } else if rand < 1800 {
            // 8.00% to generate a gene with quality Basic
            quality = GeneQuality.Basic
        } else if rand < 3000 {
            // 12.00% to generate a gene with quality Nascent
            quality = GeneQuality.Nascent
        } else {
            return nil
        }
        let threshold = FixesAssetMeta.getQualityLevelUpThreshold(quality)
        let exp = revertibleRandom<UInt64>(modulo: threshold / 5) // random exp from 20% of the threshold
        return Gene(id: nil, quality: quality, exp: exp)
    }

    // ----------------- End of DNA and Gene -----------------

    // ----------------- Deposit Tax (Deprecated) -----------------

    /// The DepositTax data structure
    ///
    access(all) struct DepositTax: FixesTraits.MergeableData {
        access(all) var flags: {String: Bool}

        init(
            _ flags: {String: Bool}?,
        ) {
            self.flags = flags ?? { "enabled": true }
        }

        /// Get the id of the data
        ///
        access(all)
        view fun getId(): String {
            return "DepositTax"
        }

        /// Get the string value of the data
        ///
        access(all)
        view fun toString(): String {
            var flags: String = ""
            for key in self.flags.keys {
                let str = key.concat("=").concat(self.flags[key] == true ? "1" : "0")
                if flags != "" {
                    flags = flags.concat(",")
                }
                flags = flags.concat(str)
            }
            return flags
        }

        /// Get the data keys
        ///
        access(all)
        view fun getKeys(): [String] {
            return ["enabled"]
        }

        /// Get the value of the data
        /// It means genes keys of the DNA
        ///
        access(all)
        view fun getValue(_ key: String): AnyStruct? {
            if key == "enabled" {
                return self.flags["enabled"]
            }
            return nil
        }

        /// Get the writable keys
        ///
        access(all)
        view fun getWritableKeys(): [String] {
            return ["enabled"]
        }

        /// Set the value of the data
        ///
        access(FixesTraits.Write)
        fun setValue(_ key: String, _ value: AnyStruct) {
            if key == "enabled" {
                self.flags["enabled"] = value as! Bool
            }
        }

        /// Split the data into another instance
        ///
        access(FixesTraits.Write)
        fun split(_ perc: UFix64): {FixesTraits.MergeableData} {
            post {
                self.getId() == result.getId(): "The result id is not the same so cannot split"
            }
            return DepositTax(self.flags)
        }

        /// Merge the data from another instance
        /// The type of the data must be the same(Ensured by interface)
        ///
        access(FixesTraits.Write)
        fun merge(_ from: {FixesTraits.MergeableData}): Void {
            // Nothing to merge
        }
    }

    // ----------------- End of Deposit Tax -----------------

    // ----------------- ExclusiveMeta -----------------

    /// The DepositTax data structure
    ///
    access(all) struct ExclusiveMeta: FixesTraits.MergeableData {

        /// Get the id of the data
        ///
        access(all)
        view fun getId(): String {
            return "ExclusiveMeta"
        }

        /// Get the string value of the data
        ///
        access(all)
        view fun toString(): String {
            return self.getId()
        }

        /// Get the data keys
        ///
        access(all)
        view fun getKeys(): [String] {
            return []
        }

        /// Get the value of the data
        /// It means genes keys of the DNA
        ///
        access(all)
        view fun getValue(_ key: String): AnyStruct? {
            return nil
        }

        /// Split the data into another instance
        ///
        access(FixesTraits.Write)
        fun split(_ perc: UFix64): {FixesTraits.MergeableData} {
            return ExclusiveMeta()
        }

        /// Merge the data from another instance
        /// The type of the data must be the same(Ensured by interface)
        ///
        access(FixesTraits.Write)
        fun merge(_ from: {FixesTraits.MergeableData}): Void {
            // Nothing to merge
        }
    }

    // ----------------- End of ExclusiveMeta -----------------

}
