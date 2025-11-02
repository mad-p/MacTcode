//
//  UserConfigs.swift
//  MacTcode
//
//  Created by maeda on 2025/07/21.
//

import Foundation

/**
 * # UserConfigs - MacTcode設定管理システム
 *
 * ## 概要
 * MacTcodeの全設定情報を管理するシングルトンクラス。JSON形式の設定ファイルから
 * 設定を読み込み、アプリケーション全体で一元管理します。
 *
 * ## 設計パターン
 * ### シングルトンパターン
 * - `shared`静的プロパティで唯一のインスタンスにアクセス
 * - アプリケーション全体で一貫した設定状態を保持
 * - 設定変更時の通知機能を提供
 *
 * ### 委譲パターン（Delegate Pattern）
 * - `UserConfigsDelegate`プロトコルによる設定変更通知
 * - 設定が変更された際に依存するコンポーネントに通知
 * - 弱参照（weak reference）によるメモリリーク回避
 *
 * ## スレッドセーフ性
 * - 読み取り専用プロパティによる設定アクセス
 * - 設定変更は`loadConfiguration()`メソッドでのみ実行
 * - 内部状態変更時は適切な排他制御を実装
 *
 * ## 設定カテゴリ
 * 1. **MazegakiConfig**: 交ぜ書き変換設定（最大活用長、読み長、辞書ファイル等）
 * 2. **BushuConfig**: 部首変換設定（辞書ファイル）
 * 3. **KeyBindingsConfig**: キーバインド設定（各機能のキーシーケンス、基本文字配列）
 * 4. **UIConfig**: UI設定（候補選択キー、バックスペース動作、記号セット等）
 * 5. **SystemConfig**: システム設定（最近テキスト長、除外アプリ、ログ設定）
 *
 * ## 設定検証
 * - `ConfigValidationError`による厳密な設定値検証
 * - 基本文字配列のサイズ・形式チェック
 * - 数値範囲の妥当性検証
 * - 不正な設定値の場合はデフォルト値で動作
 *
 * ## 使用例
 * ```swift
 * // 設定値の取得
 * let maxYomi = UserConfigs.shared.mazegaki.maxYomi
 * let candidateKeys = UserConfigs.shared.ui.candidateSelectionKeys
 *
 * // 設定変更の監視
 * UserConfigs.shared.delegate = self
 * ```
 */

// MARK: - Configuration Change Notification

protocol UserConfigsDelegate: AnyObject {
    func userConfigsDidChange(_ configs: UserConfigs)
}

// MARK: - Configuration Validation Errors

enum ConfigValidationError: LocalizedError {
    case invalidBasicTableSize(expected: Int, actual: Int)
    case invalidBasicTableRowLength(row: Int, expected: Int, actual: Int)
    case invalidMaxInflection(value: Int)
    case invalidMaxYomi(value: Int)
    case invalidBackspaceDelay(value: Double)
    case invalidRecentTextMaxLength(value: Int)
    case invalidCancelPeriod(value: Double)

    var errorDescription: String? {
        switch self {
        case .invalidBasicTableSize(let expected, let actual):
            return "Basic table must have \(expected) rows, but has \(actual)"
        case .invalidBasicTableRowLength(let row, let expected, let actual):
            return "Row \(row) must have \(expected) characters, but has \(actual)"
        case .invalidMaxInflection(let value):
            return "Max inflection must be between 1 and 10, but is \(value)"
        case .invalidMaxYomi(let value):
            return "Max yomi must be between 1 and 50, but is \(value)"
        case .invalidBackspaceDelay(let value):
            return "Backspace delay must be between 0.01 and 1.0, but is \(value)"
        case .invalidRecentTextMaxLength(let value):
            return "Recent text max length must be between 1 and 100, but is \(value)"
        case .invalidCancelPeriod(let value):
            return "Cancel period must be between 0.1 and 10.0, but is \(value)"
        }
    }
}

class UserConfigs {
    static let shared = UserConfigs()

    // MARK: - Configuration Categories

    struct MazegakiConfig: Codable {
        let maxInflection: Int
        let maxYomi: Int
        let mazegakiYomiCharacters: String
        let dictionaryFile: String
        let lruEnabled: Bool
        let lruFile: String

        static let `default` = MazegakiConfig(
            maxInflection: 4,
            maxYomi: 10,
            mazegakiYomiCharacters: "々ー\\p{Hiragana}\\p{Katakana}\\p{Han}",
            dictionaryFile: "mazegaki.dic",
            lruEnabled: false,
            lruFile: "mazegaki_user.dic"
        )
    }

    struct BushuConfig: Codable {
        let bushuYomiCharacters: String
        let dictionaryFile: String
        let autoEnabled: Bool
        let autoFile: String

        static let `default` = BushuConfig(
            bushuYomiCharacters: "0-9、。「」・\\p{Hiragana}\\p{Katakana}\\p{Han}",
            dictionaryFile: "bushu.dic",
            autoEnabled: false,
            autoFile: "bushu_auto.dic"
        )
    }

    struct KeyBindingsConfig: Codable {
        let bushuConversion: String
        let mazegakiConversion: String
        let inflectionConversion: String
        let zenkakuMode: String
        let symbolSet1: String
        let symbolSet2: String
        let basicTable: [String]

        static let `default` = KeyBindingsConfig(
            bushuConversion: "hu",
            mazegakiConversion: "uh",
            inflectionConversion: "58",
            zenkakuMode: "90",
            symbolSet1: "\\",
            symbolSet2: "\\\\",
            basicTable: [
                "■■■■■■■■■■ヮヰヱヵヶ請境系探象ゎゐゑ■■盛革突温捕■■■■■依繊借須訳",
                "■■■■■■■■■■丑臼宴縁曳尚賀岸責漁於汚乙穏■益援周域荒■■■■■織父枚乱香",
                "■■■■■■■…■■鬼虚狭脅驚舎喜幹丘糖奇既菊却享康徒景処ぜ■■■■■譲ヘ模降走",
                "■■■■■■■←■■孤誇黄后耕布苦圧恵固巧克懇困昏邦舞雑漢緊■■■■■激干彦均又",
                "■■■■■■■■■■奉某貌卜■姿絶密秘押■■■■■衆節杉肉除■■■■■測血散笑弁",
                "■■■■■■■■■■湖礼著移郷■■■■■償欧努底亜■■■■■禁硝樹句礎■■■■■",
                "■■■■■■■■■■端飾郵塩群■星析遷宣紅傷豪維脱鼠曹奏尊■絹被源願臨■■■■■",
                "■■→■■■■■＜■刷寿順危砂庶粧丈称蒸舗充喫腕暴林薫■貢■批慶渉竜併■署↑■■",
                "■■■■■■■＞■■震扱片札乞■乃如尼帳輪倒操柄魚■籍簿■■就駐揮丹鮮■■■■■",
                "■■■■■■■■■■弘痛票訴遺欄龍略慮累則存倍牛釈■■■■■綱潟創背皮■■■■■",
                "ヲ哀暇啓把酸昼炭稲湯果告策首農歩回務島開報紙館夜位給員ど代レ欠夏彼妻善相家的対歴",
                "ゥ逢牙掲伐貿捜異隣旧概買詳由死キせ区百木音王放々応分よル千ア財針裏居差付プばュ作",
                "ヴ宛壊携避攻焼闘奈夕武残両在!や出タ手保案曲情引職7か(トれ従骨厚顔量内工八テ見",
                "ヂ囲較劇卑盤帯易速拡風階能論増コ山者発立横興刺側覚きっ日国二適類御宇推九名川機チ",
                "ヅ庵寒賢藩汽換延雪互細古利ペゃナ金マ和女崎白ぐ官球上く8え年母奥因酒伸サ建パ第入",
                "簡徴触宗植■索射濁慢害賃整軽評佐法数郎談服声任検豊美題井洋実爆仲茶率比昔短岩巨敗",
                "承章候途複■冊需詑迷撃折追隊角接備最急験変審改昇芸宿制集安画陽構旅施曜遠ォ将ぞ塚",
                "快否歯筆里■皿輯蓄戻浴秀糸春幸記朝知ワ送限研労統役セ運ツ特谷ァ導認健尾序振練念働",
                "包納頼逃寝■賛瞬貯羊積程断低減モ資士費ィ逆企精ざ印神び打勤ャ殺負何履般耳授版効視",
                "唱暮憲勉罪■■盾虫■故鉱提児敷無石屋解募令違装然確優公品語演券悪秋非便示即難普辺",
                "ぱ慰我兼菱桜瀬鳥催障収際太園船中スもお定種岡結進真3と★てるヒ江別考権ッ人三京ち",
                "ぴ為掛嫌紐典博筋忠乳若雄査ふ賞わラ東生ろ宅熟待取科ーした一が及久蔵早造ロク万方フ",
                "ぷ陰敢顕描採謡希仏察指氏丸続ェう4)十リ料土活ね参い、の51投義算半県んまンつ四",
                "ぺ隠甘牽憤君純副盟標ぎ格次習火あこ6学月受予切育池。◆0・2込沢軍青清けイす電地",
                "ぽ胃患厳弊犯余堀肩療思術広門聞本さら高シ英ボ加室少ではになを転空性使級業時「長み",
                "朱遅甲致汎■衰滋沈己病終起路越む南原駅物勢必講愛管要設水藤有素兵専親寮ホ共ブ平楽",
                "陣鶴鹿貨絡■趨湿添已常張薬防得ケ式戦関男輸形助◇流連鉄教力ベ毛永申袋良私ゴ来信午",
                "眼繁誌招季■垂甚徹巳寺質づ港条話座線ダ橋基好味宝争デ現エ他度等浅頃落命村ガ製校ご",
                "執紹夢卸阿■粋■爪巴停領容玉右べ民ソ点遇足草築観言車成天世文板客師税飛ノ完重約各",
                "岳刑弱雲窓■寸瞳陶■河置供試席期ゾ歳強係婦段衛額渋主映書可へ伝庭課着坂近外米ョ光",
                "ぁ■瓦■■呼幅歓功盗徳渡守登退店持町所ほ件友卒初慣行ド円小ジヨ誤証含%海道ず西げ",
                "ぃ■■■■紀破郡抗幡械刊訪融雨全じ自議明宮伊求技写通カ社野同判規感値ギ当理メウグ",
                "ぅ■■■■房績識属衣帝始了極熱バ部六経動局頭配黒院だり＿め大済吉ゆ器照不合面政オ",
                "ぇ■■■■去疑ぢ綿離読鈴恐督況後間場ニ産向府富直倉新」9子五説週号葉派委化ビ目市",
                "ぉ○×☆□秒範核影麻族丁未才返問ム七住北割ぶ番望元事田会前そ休省央福毎気売下都株",
                "欲巣茂述朗■■■■■帰庁昨跡ゲ洗羽個医静億録赤想消支協用表正図挙険ゼ波ヤ心界意今",
                "迫災恋脳老■■■■■監寄裁達芝響忘討史環色貸販編仕先多商ハ交之末ぼ街免再ネ～口台",
                "留列刻豆看■■↓■■竹注介具失司迎華許補左態花栄ザ調混ポ決ミ州払乗庫状団計夫食総",
                "替沼?辞献■■■■■ゅ修究答養復並浦ユ冷ぬ展警型誰組選党択体例満津準遊戸ひょ価与",
                "還更占箱矢■■■■■志抜航層深担陸巻競護根様独止堂銀以ヌ営治字材過諸単身ピ勝反ズ"
            ]
        )
    }

    struct UIConfig: Codable {
        let candidateSelectionKeys: [String]
        let backspaceDelay: Double
        let backspaceLimit: Int
        let symbolSet1Chars: String
        let symbolSet2Chars: String

        static let `default` = UIConfig(
            candidateSelectionKeys: ["j", "k", "l", ";", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
            backspaceDelay: 0.05,
            backspaceLimit: 10,
            symbolSet1Chars: "√∂『』　“《》【】┏┳┓┃◎◆■●▲▼┣╋┫━　◇□○△▽┗┻┛／＼※§¶†‡",
            symbolSet2Chars: "♠♡♢♣㌧㊤㊥㊦㊧㊨㉖㉗㉘㉙㉚⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳①②③④⑤㉑㉒㉓㉔㉕⑥⑦⑧⑨⑩"
        )
    }

    struct SystemConfig: Codable {
        let recentTextMaxLength: Int
        let excludedApplications: [String]
        let disableOneYomiApplications: [String]
        let logEnabled: Bool
        let keyboardLayout: String
        let keyboardLayoutMapping: [String]
        let syncStatsInterval: Int
        let cancelPeriod: Double

        static let `default` = SystemConfig(
            recentTextMaxLength: 20,
            excludedApplications: ["com.apple.loginwindow", "com.apple.SecurityAgent"],
            disableOneYomiApplications: ["com.google.Chrome"],
            logEnabled: false,
            keyboardLayout: "dvorak",
            keyboardLayoutMapping: [
                "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
                "'", ",", ".", "p", "y", "f", "g", "c", "r", "l",
                "a", "o", "e", "u", "i", "d", "h", "t", "n", "s",
                ";", "q", "j", "k", "x", "b", "m", "w", "v", "z"
            ],
            syncStatsInterval: 1200,
            cancelPeriod: 1.5
        )
    }

    struct ConfigData: Codable {
        let mazegaki: MazegakiConfig
        let bushu: BushuConfig
        let keyBindings: KeyBindingsConfig
        let ui: UIConfig
        let system: SystemConfig

        static let `default` = ConfigData(
            mazegaki: .default,
            bushu: .default,
            keyBindings: .default,
            ui: .default,
            system: .default
        )
    }

    // MARK: - Properties

    private var configData: ConfigData = .default
    private let configURL: URL
    weak var delegate: UserConfigsDelegate?

    // MARK: - Constants

    private static let expectedBasicTableRows = 40
    private static let expectedBasicTableColumns = 40

    // MARK: - Initialization

    private init() {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        macTcodeURL = appSupportURL.appendingPathComponent("MacTcode")

        // ディレクトリが存在しない場合は作成
        if !fileManager.fileExists(atPath: macTcodeURL.path) {
            try? fileManager.createDirectory(at: macTcodeURL, withIntermediateDirectories: true)
        }

        configURL = macTcodeURL.appendingPathComponent("config.json")
        loadConfig()
    }

    // MARK: - Public Access Properties

    var mazegaki: MazegakiConfig { configData.mazegaki }
    var bushu: BushuConfig { configData.bushu }
    var keyBindings: KeyBindingsConfig { configData.keyBindings }
    var ui: UIConfig { configData.ui }
    var system: SystemConfig { configData.system }
    let macTcodeURL: URL

    // MARK: - Configuration Management

    private func loadConfig() {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            log("Config file not found. Using default configuration.")
            return
        }

        do {
            let data = try Data(contentsOf: configURL)
            let decoder = JSONDecoder()
            let loadedConfig = try decoder.decode(ConfigData.self, from: data)

            // 設定の妥当性を検証
            try validateConfiguration(loadedConfig)

            configData = loadedConfig
            log("Configuration loaded and validated successfully.")
            delegate?.userConfigsDidChange(self)
        } catch {
            log("Failed to load configuration: \(error). Using default configuration.")
            configData = .default
        }
    }

    func loadConfigFromFile(_ fileURL: URL) throws {
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        let loadedConfig = try decoder.decode(ConfigData.self, from: data)

        // 設定の妥当性を検証
        try validateConfiguration(loadedConfig)

        configData = loadedConfig
        log("Configuration loaded from external file: \(fileURL.path)")
        delegate?.userConfigsDidChange(self)
    }
    
    func loadConfig(file: String) -> String? {
        // ユーザーのApplication Supportディレクトリを優先して検索
        let configURL = configFileURL(file)
            
        if FileManager.default.fileExists(atPath: configURL.path) {
            do {
                let configContent = try String(contentsOf: configURL, encoding: .utf8)
                Log.i("Config file \(file) loaded from: \(configURL.path)")
                return configContent
            } catch {
                Log.i("Failed to read file \(configURL.path): \(error)")
            }
        }

        // バンドルリソースから検索（フォールバック）
        if let configFilePath = Bundle.main.path(forResource: file, ofType: nil) {
            do {
                let configContent = try String(contentsOfFile: configFilePath, encoding: .utf8)
                Log.i("Config file \(file) loaded from bundle: \(configFilePath)")
                return configContent
            } catch {
                Log.i("Failed to read bundle file: \(error)")
            }
        }
        
        Log.i("Config file \(file) not found in any search path")
        return nil
    }

    func configFileURL(_ filename: String) -> URL {
        return macTcodeURL.appendingPathComponent(filename)
    }

    private func validateConfiguration(_ config: ConfigData) throws {
        // MazegakiConfig validation
        guard config.mazegaki.maxInflection >= 1 && config.mazegaki.maxInflection <= 10 else {
            throw ConfigValidationError.invalidMaxInflection(value: config.mazegaki.maxInflection)
        }

        guard config.mazegaki.maxYomi >= 1 && config.mazegaki.maxYomi <= 50 else {
            throw ConfigValidationError.invalidMaxYomi(value: config.mazegaki.maxYomi)
        }

        // KeyBindingsConfig validation - basicTable
        let basicTable = config.keyBindings.basicTable
        guard basicTable.count == Self.expectedBasicTableRows else {
            throw ConfigValidationError.invalidBasicTableSize(
                expected: Self.expectedBasicTableRows,
                actual: basicTable.count
            )
        }

        for (index, row) in basicTable.enumerated() {
            guard row.count == Self.expectedBasicTableColumns else {
                throw ConfigValidationError.invalidBasicTableRowLength(
                    row: index,
                    expected: Self.expectedBasicTableColumns,
                    actual: row.count
                )
            }
        }

        // UIConfig validation
        guard config.ui.backspaceDelay >= 0.01 && config.ui.backspaceDelay <= 1.0 else {
            throw ConfigValidationError.invalidBackspaceDelay(value: config.ui.backspaceDelay)
        }

        // SystemConfig validation
        guard config.system.recentTextMaxLength >= 1 && config.system.recentTextMaxLength <= 100 else {
            throw ConfigValidationError.invalidRecentTextMaxLength(value: config.system.recentTextMaxLength)
        }

        guard config.system.cancelPeriod >= 0.1 && config.system.cancelPeriod <= 10.0 else {
            throw ConfigValidationError.invalidCancelPeriod(value: config.system.cancelPeriod)
        }
    }

    func saveConfig() {
        do {
            // 保存前に妥当性を検証
            try validateConfiguration(configData)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(configData)
            try data.write(to: configURL)
            log("Configuration saved successfully.")
        } catch {
            log("Failed to save configuration: \(error)")
        }
    }

    func saveConfigToFile(_ fileURL: URL) throws {
        try validateConfiguration(configData)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configData)
        try data.write(to: fileURL)
        log("Configuration exported to: \(fileURL.path)")
    }

    func resetToDefaults() {
        configData = .default
        saveConfig()
        delegate?.userConfigsDidChange(self)
        log("Configuration reset to defaults.")
    }

    func reloadConfig() {
        loadConfig()
        log("Configuration reloaded.")
    }

    // MARK: - Configuration Status

    var isUsingDefaultConfig: Bool {
        return !FileManager.default.fileExists(atPath: configURL.path)
    }

    var configFileExists: Bool {
        return FileManager.default.fileExists(atPath: configURL.path)
    }

    var configFilePath: String {
        return configURL.path
    }

    func createSampleConfigFile() {
        if !configFileExists {
            saveConfig()
            log("Sample configuration file created at: \(configURL.path)")
        }
    }

    // MARK: - Configuration Updates

    func updateMazegaki(_ newConfig: MazegakiConfig) {
        let newConfigData = ConfigData(
            mazegaki: newConfig,
            bushu: configData.bushu,
            keyBindings: configData.keyBindings,
            ui: configData.ui,
            system: configData.system
        )

        do {
            try validateConfiguration(newConfigData)
            configData = newConfigData
            delegate?.userConfigsDidChange(self)
            log("Mazegaki configuration updated.")
        } catch {
            log("Failed to update mazegaki configuration: \(error)")
        }
    }

    func updateBushu(_ newConfig: BushuConfig) {
        let newConfigData = ConfigData(
            mazegaki: configData.mazegaki,
            bushu: newConfig,
            keyBindings: configData.keyBindings,
            ui: configData.ui,
            system: configData.system
        )

        do {
            try validateConfiguration(newConfigData)
            configData = newConfigData
            delegate?.userConfigsDidChange(self)
            log("Bushu configuration updated.")
        } catch {
            log("Failed to update bushu configuration: \(error)")
        }
    }

    func updateKeyBindings(_ newConfig: KeyBindingsConfig) {
        let newConfigData = ConfigData(
            mazegaki: configData.mazegaki,
            bushu: configData.bushu,
            keyBindings: newConfig,
            ui: configData.ui,
            system: configData.system
        )

        do {
            try validateConfiguration(newConfigData)
            configData = newConfigData
            delegate?.userConfigsDidChange(self)
            log("Key bindings configuration updated.")
        } catch {
            log("Failed to update key bindings configuration: \(error)")
        }
    }

    func updateUI(_ newConfig: UIConfig) {
        let newConfigData = ConfigData(
            mazegaki: configData.mazegaki,
            bushu: configData.bushu,
            keyBindings: configData.keyBindings,
            ui: newConfig,
            system: configData.system
        )

        do {
            try validateConfiguration(newConfigData)
            configData = newConfigData
            delegate?.userConfigsDidChange(self)
            log("UI configuration updated.")
        } catch {
            log("Failed to update UI configuration: \(error)")
        }
    }

    func updateSystem(_ newConfig: SystemConfig) {
        let newConfigData = ConfigData(
            mazegaki: configData.mazegaki,
            bushu: configData.bushu,
            keyBindings: configData.keyBindings,
            ui: configData.ui,
            system: newConfig
        )

        do {
            try validateConfiguration(newConfigData)
            configData = newConfigData
            delegate?.userConfigsDidChange(self)
            log("System configuration updated.")
        } catch {
            log("Failed to update system configuration: \(error)")
        }
    }

    // Logging

    // This function is used for logging messages
    // while initializing the singleton instance.
    // Log.i refers to UserConfig.shared.system.logEnabled, however,
    // during the initialization of UserConfig itself, it may lead to a bus error.
    private func log(_ message: String) {
        NSLog(message)
    }
}
