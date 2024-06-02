//
//  TcodeTable.swift
//  MacTcode
//
//  Created by maeda on 2024/05/26.
//

import Cocoa

class TcodeKeymap {
    static var map: Keymap = {
        if let map1 = StrokeKeymap("TCode2D", from2d: """
■■■■■■■■■■ヮヰヱヵヶ請境系探象ゎゐゑ■■盛革突温捕■■■■■依繊借須訳
■■■■■■■■■■丑臼宴縁曳尚賀岸責漁於汚乙穏■益援周域荒■■■■■織父枚乱香
■■■■■■■…■■鬼虚狭脅驚舎喜幹丘糖奇既菊却享康徒景処ぜ■■■■■譲ヘ模降走
■■■■■■■←■■孤誇黄后耕布苦圧恵固巧克懇困昏邦舞雑漢緊■■■■■激干彦均又
■■■■■■■■■■奉某貌卜■姿絶密秘押■■■■■衆節杉肉除■■■■■測血散笑弁
■■■■■■■■■■湖礼著移郷■■■■■償欧努底亜■■■■■禁硝樹句礎■■■■■
■■■■■■■■■■端飾郵塩群■星析遷宣紅傷豪維脱鼠曹奏尊■絹被源願臨■■■■■
■■→■■■■■＜■刷寿順危砂庶粧丈称蒸舗充喫腕暴林薫■貢■批慶渉竜併■署↑■■
■■■■■■■＞■■震扱片札乞■乃如尼帳輪倒操柄魚■籍簿■■就駐揮丹鮮■■■■■
■■■■■■■■■■弘痛票訴遺欄龍略慮累則存倍牛釈■■■■■綱潟創背皮■■■■■
ヲ哀暇啓把酸昼炭稲湯果告策首農歩回務島開報紙館夜位給員ど代レ欠夏彼妻善相家的対歴
ゥ逢牙掲伐貿捜異隣旧概買詳由死キせ区百木音王放々応分よル千ア財針裏居差付プばュ作
ヴ宛壊携避攻焼闘奈夕武残両在!や出タ手保案曲情引職7か(トれ従骨厚顔量内工八テ見
ヂ囲較劇卑盤帯易速拡風階能論増コ山者発立横興刺側覚きっ日国二適類御宇推九名川機チ
ヅ庵寒賢藩汽換延雪互細古利ペゃナ金マ和女崎白ぐ官球上く8え年母奥因酒伸サ建パ第入
簡徴触宗植■索射濁慢害賃整軽評佐法数郎談服声任検豊美題井洋実爆仲茶率比昔短岩巨敗
承章候途複■冊需詑迷撃折追隊角接備最急験変審改昇芸宿制集安画陽構旅施曜遠ォ将ぞ塚
快否歯筆里■皿輯蓄戻浴秀糸春幸記朝知ワ送限研労統役セ運ツ特谷ァ導認健尾序振練念働
包納頼逃寝■賛瞬貯羊積程断低減モ資士費ィ逆企精ざ印神び打勤ャ殺負何履般耳授版効視
唱暮憲勉罪■■盾虫■故鉱提児敷無石屋解募令違装然確優公品語演券悪秋非便示即難普辺
ぱ慰我兼菱桜瀬鳥催障収際太園船中スもお定種岡結進真3と★てるヒ江別考権ッ人三京ち
ぴ為掛嫌紐典博筋忠乳若雄査ふ賞わラ東生ろ宅熟待取科ーした一が及久蔵早造ロク万方フ
ぷ陰敢顕描採謡希仏察指氏丸続ェう4)十リ料土活ね参い、の51投義算半県んまンつ四
ぺ隠甘牽憤君純副盟標ぎ格次習火あこ6学月受予切育池。◆0・2込沢軍青清けイす電地
ぽ胃患厳弊犯余堀肩療思術広門聞本さら高シ英ボ加室少ではになを転空性使級業時「長み
朱遅甲致汎■衰滋沈己病終起路越む南原駅物勢必講愛管要設水藤有素兵専親寮ホ共ブ平楽
陣鶴鹿貨絡■趨湿添已常張薬防得ケ式戦関男輸形助◇流連鉄教力ベ毛永申袋良私ゴ来信午
眼繁誌招季■垂甚徹巳寺質づ港条話座線ダ橋基好味宝争デ現エ他度等浅頃落命村ガ製校ご
執紹夢卸阿■粋■爪巴停領容玉右べ民ソ点遇足草築観言車成天世文板客師税飛ノ完重約各
岳刑弱雲窓■寸瞳陶■河置供試席期ゾ歳強係婦段衛額渋主映書可へ伝庭課着坂近外米ョ光
ぁ■瓦■■呼幅歓功盗徳渡守登退店持町所ほ件友卒初慣行ド円小ジヨ誤証含%海道ず西げ
ぃ■■■■紀破郡抗幡械刊訪融雨全じ自議明宮伊求技写通カ社野同判規感値ギ当理メウグ
ぅ■■■■房績識属衣帝始了極熱バ部六経動局頭配黒院だり＿め大済吉ゆ器照不合面政オ
ぇ■■■■去疑ぢ綿離読鈴恐督況後間場ニ産向府富直倉新」9子五説週号葉派委化ビ目市
ぉ○×☆□秒範核影麻族丁未才返問ム七住北割ぶ番望元事田会前そ休省央福毎気売下都株
欲巣茂述朗■■■■■帰庁昨跡ゲ洗羽個医静億録赤想消支協用表正図挙険ゼ波ヤ心界意今
迫災恋脳老■■■■■監寄裁達芝響忘討史環色貸販編仕先多商ハ交之末ぼ街免再ネ～口台
留列刻豆看■■↓■■竹注介具失司迎華許補左態花栄ザ調混ポ決ミ州払乗庫状団計夫食総
替沼?辞献■■■■■ゅ修究答養復並浦ユ冷ぬ展警型誰組選党択体例満津準遊戸ひょ価与
還更占箱矢■■■■■志抜航層深担陸巻競護根様独止堂銀以ヌ営治字材過諸単身ピ勝反ズ
""") {
            let map2 = SparseMap("TCodeCommandMap")
            let map3 = UnionMap("TCodeMap", keymaps: [map2, map1])
            if !(KeymapResolver.define(sequence: "hu", keymap: map3, action: PostfixBushuAction()) &&
                KeymapResolver.define(sequence: "uh", keymap: map3, action: PostfixMazegakiAction(inflection: false)) &&
                KeymapResolver.define(sequence: "58", keymap: map3, action: PostfixMazegakiAction(inflection: true))) {
                NSLog("TCodeMap definition error")
            }
            _ = KeymapResolver.define(sequence: "\\", keymap: map3, entry: KeymapEntry.next(
                UnionMap.wrap(StrokeKeymap("outset1", fromChars: "√∂『』　《》【】“┏┳┓┃◎◆■●▲▼┣╋┫━　◇□○△▽┗┻┛／＼※§¶†‡"))
                ))
            _ = KeymapResolver.define(sequence: "\\\\", keymap: map3, entry: KeymapEntry.next(
                UnionMap.wrap(StrokeKeymap("outset2", fromChars: "♠♡♢♣㌧㊤㊥㊦㊧㊨㉖㉗㉘㉙㉚⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳①②③④⑤㉑㉒㉓㉔㉕⑥⑦⑧⑨⑩"))))
            
            return map3
        }
        NSLog("TcodeMap definition error")
        return SparseMap("nullmap")
    }()
}

class PendingEmitterAction: Action {
    func execute(client: any MyInputText, input: [InputEvent]) -> Command {
        let range: Range<Int> = if input.count == 1 {
            0..<1 // only the last
        } else {
            0..<input.count - 1 // all but last
        }
        if input.count >= 1 {
            let str = range.map { i in
                input[i].text ?? ""
            }.joined()
            return .text(str)
        }
        return .processed
    }
}

class ResetAllStateAction: Action {
    func execute(client: any MyInputText, input: [InputEvent]) -> Command {
        return .processed
    }
    static func isResetAction(entry: KeymapEntry) -> Bool {
        switch entry {
        case .next(_):
            return false
        case .command(let command):
            switch command {
            case .action(let action):
                return action is ResetAllStateAction
            default:
                return false
            }
        }
    }
}

class TopLevelMap {
    static var map = {
        let map = SparseMap("TopLevelMap")
        _ = map.replace(input: InputEvent(type: .space, text: " "), entry: .command(.action(PendingEmitterAction())))
        _ = map.replace(input: InputEvent(type: .escape, text: "\033"), entry: .command(.action(ResetAllStateAction())))
        return map
    }()
}
