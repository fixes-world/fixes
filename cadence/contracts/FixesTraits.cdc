// Thirdparty Imports
import "MetadataViews"

/// The `FixesTraits` contract
///
pub contract FixesTraits {

    /// =============  Trait: Season 0 - Secret Garden =============

    /// The Definition of the Marketplace Season 0
    pub enum Season0SecretPlaces: UInt8 {
        pub case HeartOfTheAzureOcean // 蔚蓝海洋之心
        pub case HeartOfTheDarkForest // 黑暗森林之心
        pub case GardenofVenus // 维纳斯的花园
        pub case CityOfTheDead // 亡者之城
        pub case DragonboneWasteland // 龙骨荒原
        pub case MysticForest // 神秘森林
        pub case SoulWaterfall // 灵魂瀑布
        pub case AbyssalHollow // 深渊之穴
        pub case SilentGlacier // 静寂冰川
        pub case FrostWasteland // 霜冻荒原
        pub case DesolateGround // 荒芜之地
        pub case MirageCity // 海市蜃楼
        pub case ScorpionGorge // 蛇蝎峡谷
        pub case MysteriousIceLake // 神秘冰湖
        pub case NightShadowForest // 夜影密林
        pub case SpiritualValley // 灵犀山谷
        pub case RavensPerch // 乌鸦栖息地
        pub case RainbowFalls // 彩虹瀑布
        pub case TwilightValley // 暮色谷地
        pub case RuggedHill // 乱石山岗
    }

    access(all) view
    fun getSeason0SecretPlacesDefs(): [Definition] {
        return [
            Definition(5, 100), // 1% chance, rarity 2
            Definition(12, 1900), // 19% chance, rarity 1
            Definition(20, 8000) // 80% chance, rarity 0
        ]
    }

    /// =============  Trait: Season 0 - Ability =============

    /// The Definition of the Marketplace Season 0
    ///
    pub enum Season0Ability: UInt8 {
        pub case Omniscience // 全知全能
        pub case ElementalMastery // 全元素掌控
        pub case TimeStand // 时间静止
        pub case MillenniumFreeze // 千年冰封
        pub case FossilResurgence // 化石重生
        pub case MysticVision // 神秘视界
        pub case PhoenixRebirth // 凤凰复生
        pub case SoulBind // 灵魂束缚
        pub case PrayerOfLight // 光明祈祷
        pub case Starfall // 星辰坠落
        pub case DragonsBreath // 龙焰吐息
        pub case PsychicSense // 心灵感应
        pub case MindControl // 心灵控制
        pub case EndlessTorment // 无尽痛苦
        pub case MeditationInDespair // 绝境冥思
        pub case SilenceFear // 沉默恐惧
        pub case GloryChallenge // 荣耀挑战
        pub case ShieldWall // 防御罩墙
        pub case TidalCall // 海潮呼唤
        pub case FountainOfLife // 生命之泉
        pub case PsychicInteraction // 精神互动
        pub case PlagueTransmission // 疫病传染
        pub case NinjaStealth // 忍者潜行
        pub case BattleRoar // 战斗吼叫
        pub case CongestiveStrike // 充血打击
        pub case HolyGuidance // 圣光指引
        pub case EmpoweredBarrier // 强化结界
        pub case PerpetualLife // 生生不息
        pub case CombatEvade // 战斗闪避
        pub case AbyssArrow // 深渊之箭
        pub case SoulEcho // 灵魂回响
        pub case ArcaneBlink // 魔力闪现
        pub case ArcaneExplosion // 魔力爆炸
        pub case ShadowStep // 暗黑影步
        pub case JadeStoneSpell // 玉石咒语
        pub case PhantomDodge // 鬼魅闪避
        pub case KissOfDeath // 死亡之吻
        pub case PhantomSummoning // 幻影召唤
        pub case EyeOfTheRaven // 乌鸦之眼
        pub case RatSwarmSurge // 鼠群涌动
        pub case FlameShock // 烈焰冲击
        pub case GaleSpeedBlade // 疾风快剑
        pub case InterstellarFlight // 星界飞行
        pub case WraithSeal // 怨灵封印
        pub case DivineRestoration // 神力恢复
        pub case LifePull // 生命拉扯
        pub case RapidFire // 快速射击
        pub case MightyBlow // 强力打击
        pub case PhysicalTraining // 锻炼体魄
    }

    access(all) view
    fun getSeason0AbilityDefs(): [Definition] {
        return [
            Definition(5, 20), // 0.2% chance, rarity 3
            Definition(12, 100), // 1% chance, rarity 2
            Definition(25, 1880), // 18.8% chance, rarity 1
            Definition(49, 8000) // 80% chance, rarity 0
        ]
    }

    /// =============  Trait: Season 0 - Weapons =============

    pub enum Season0Weapons: UInt8 {
        pub case Starstaff // 星辰法杖
        pub case BowOfTheMysteriousBird // 九天玄鸟之弓
        pub case VoidSpiritWand // 虚空灵杖
        pub case GodlyWand // 神祇法杖
        pub case SunriseHolySword // 旭日圣剑
        pub case DeepSeaTrident // 深海三叉戟
        pub case DragonboneBow // 龙骨弓
        pub case RainbowHolySword // 虹光圣剑
        pub case MysticalGrimoire // 神秘法书
        pub case SaintsStaff // 圣者圣杖
        pub case FirePhoenixWhip // 火凤长鞭
        pub case SoulOrb // 灵魂法球
        pub case LightningSpear // 闪电长矛
        pub case DarkScepter // 黑暗权杖
        pub case DawnLance // 破晓长枪
        pub case RedLotusRocket // 红莲火箭
        pub case DemonBoneSpike // 恶魔骨刺
        pub case EvilStarCatapult // 魔星投石器
        pub case SwordOfTenderness // 温柔之剑
        pub case WindWarriorLongbow // 风战者长弓
        pub case NightDagger // 黑夜匕首
        pub case GalaxyHalberd // 银河双戟
        pub case MoonshadowScimitar // 影月弯刀
        pub case IceCrownDagger // 冰冠短剑
        pub case StormBattleAxe // 风暴战斧
        pub case ArcaneStaff // 奥术长杖
        pub case AxeOfInferno // 烈火之斧
        pub case SkybreakerDualBlade // 破空双刃
        pub case IceGiantSword // 寒冰巨剑
        pub case TrollsHammer // 巨魔之锤
    }

    access(all) view
    fun getSeason0WeaponsDefs(): [Definition] {
        return [
            Definition(5, 20), // 0.2% chance, rarity 3
            Definition(12, 100), // 1% chance, rarity 2
            Definition(20, 1880), // 18.8% chance, rarity 1
            Definition(30, 8000) // 80% chance, rarity 0
        ]
    }

    access(account)
    fun attemptToGenerateRandomEntryForSeason0(): @Entry? {
        let randForType = revertibleRandom()
        // 5% for secret places, 10% for ability, 25% for weapons, 60% for nothing
        let randForTypePercent = UInt8(randForType % 100)
        if randForTypePercent >= 60 {
            return nil
        }
        // generate a random number for the entry
        let randForEntry = revertibleRandom() % 10000
        var type: Type? = nil
        var defs: [Definition]? = nil
        if randForTypePercent < 5 {
            defs = self.getSeason0SecretPlacesDefs()
            type = Type<Season0SecretPlaces>()
        } else if randForTypePercent < 15 {
            defs = self.getSeason0AbilityDefs()
            type = Type<Season0Ability>()
        } else {
            defs = self.getSeason0WeaponsDefs()
            type = Type<Season0Weapons>()
        }

        var totalWeight: UInt64 = 0
        var lastThreshold: UInt8 = 0
        var currentThreshold: UInt8 = 0
        let maxRarity = UInt8(defs!.length - 1)
        var currentRarity: UInt8 = 0
        // find the right rarity
        for i, def in defs! {
            totalWeight = totalWeight + def.weight
            if randForEntry < totalWeight {
                currentThreshold = def.threshold
                currentRarity = maxRarity - UInt8(i)
                break
            }
            lastThreshold = def.threshold
        }
        // create the entry
        return <- self.createEntry(
            type!,
            // calculate the value
            lastThreshold + (UInt8(randForEntry % 255) % (currentThreshold - lastThreshold)),
            currentRarity
        )
    }

    /**
        ------------------------ Public Methods ------------------------
    */

    /// Get the rarity definition array for a given series
    /// The higher the rarity in front.
    ///
    access(all) fun getRarityArray(_ series: Type): [Definition] {
        switch series {
        case Type<Season0SecretPlaces>():
            return self.getSeason0SecretPlacesDefs()
        case Type<Season0Ability>():
            return self.getSeason0AbilityDefs()
        case Type<Season0Weapons>():
            return self.getSeason0WeaponsDefs()
        }
        return []
    }

    /// Get the maximum rarity for a given series
    ///
    access(all) fun getMaxRarity(_ series: Type): UInt8 {
        let arr = self.getRarityArray(series)
        return UInt8(arr.length - 1)
    }

    /**
        ------------------------ Genreal Interfaces & Resources ------------------------
    */

    /// The Entry Definition
    ///
    pub struct Definition {
        access(all)
        let threshold: UInt8 // max value for this rarity, not included
        access(all)
        let weight: UInt64 // weight of this rarity

        init (
            _ threshold: UInt8,
            _ weight: UInt64
        ) {
            self.threshold = threshold
            self.weight = weight
        }
    }

    /// The `Entry` resource
    ///
    pub resource Entry: MetadataViews.Resolver {
        // Series is the identifier of the series enum
        access(all)
        let series: Type
        // Value is the value of the trait, as the rawValue of the enum
        access(all)
        let value: UInt8
        // Rarity is the rarity of the trait, from 0 to maxRarity
        access(all)
        let rarity: UInt8
        // Offset is random between -20 and 20, to be used for rarity extension
        access(all)
        let offset: Int8

        init (
            series: Type,
            value: UInt8,
            rarity: UInt8
        ) {
            self.series = series
            self.value = value
            self.rarity = rarity
            // Offset is random between -20 and 20
            let rand = revertibleRandom()
            self.offset = Int8(rand % 40) - 20
        }

        // ---- implement Resolver ----

        /// Function that returns all the Metadata Views available for this profile
        ///
        access(all)
        fun getViews(): [Type] {
            return [
                Type<MetadataViews.Trait>()
            ]
        }

        /// Function that resolves a metadata view for this profile
        ///
        access(all)
        fun resolveView(_ view: Type): AnyStruct? {
            switch view {
            case Type<MetadataViews.Trait>():
                return MetadataViews.Trait(
                    name: self.series.identifier,
                    value: self.value,
                    displayType: "number",
                    rarity: MetadataViews.Rarity(
                        score: UFix64(self.rarity),
                        max: UFix64(FixesTraits.getMaxRarity(self.series)),
                        description: nil
                    )
                )
            }
            return nil
        }
    }

    /// Create a new entry
    ///
    access(account)
    fun createEntry(_ series: Type, _ value: UInt8, _ rarity: UInt8): @Entry {
        return <- create Entry(
            series: series,
            value: value,
            rarity: rarity
        )
    }
}
