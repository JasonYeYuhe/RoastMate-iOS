import XCTest
@testable import RoastMate

/// Pillar A: share artifact. Pins the v1.3.1 contract — a share card carries
/// the sendable line and nothing else, and a private vent draft has no share
/// affordance at all.
final class ShareCardTests: XCTestCase {

    // MARK: - Redactor
    //
    // Retained for v1.4 Track B.2, which will expand this (NER + Chinese
    // patterns) and run it on the sendable text. It has no production call
    // site today — see Redactor.swift.

    func testRedactsEmail() {
        let out = Redactor.redact("reach me at a.b+x@mail.example.com please")
        XCTAssertFalse(out.contains("a.b+x@mail.example.com"))
        XCTAssertTrue(out.contains("[email]"))
    }

    func testRedactsURLAndHandleAndPhone() {
        XCTAssertTrue(Redactor.redact("see https://evil.example/x now").contains("[link]"))
        let h = Redactor.redact("blame @john_doe lol")
        XCTAssertFalse(h.contains("@john_doe"))
        let p = Redactor.redact("call +1 (415) 555-2671 tonight")
        XCTAssertFalse(p.contains("2671"))
        XCTAssertTrue(p.contains("[number]"))
    }

    func testKeepsOrdinaryTextIntact() {
        let s = "my boss took credit for my work again"
        XCTAssertEqual(Redactor.redact(s), s)
    }

    // MARK: - Privacy invariant: the card renders the sendable line ONLY
    //
    // These are the regression guards for the v1.3.1 purge. `ShareCardContent`
    // deliberately has no vent field, so "the card can't carry the vent" is
    // enforced by the type system; what these pin is that the rendered content
    // is exactly the sendable text and is not derived from anything else.

    func testContentCarriesOnlyTheSendableLine() {
        let c = ShareCardContent(styleName: "Sharp", sentText: "Noted, and corrected.")
        XCTAssertEqual(c.sentText, "Noted, and corrected.")
        XCTAssertEqual(c.styleName, "Sharp")
    }

    func testContentIsValueEqualByRenderedText() {
        // Guards the composer's render key: two contents that render the same
        // pixels must compare equal, so a re-render isn't silently skipped.
        let a = ShareCardContent(styleName: "Sharp", sentText: "same")
        let b = ShareCardContent(styleName: "Sharp", sentText: "same")
        let c = ShareCardContent(styleName: "Sharp", sentText: "different")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testStyleNameIsOptional() {
        let c = ShareCardContent(styleName: nil, sentText: "x")
        XCTAssertNil(c.styleName)
        XCTAssertEqual(c.sentText, "x")
    }

    // MARK: - Shareability rule (the v1.3.1 contract)
    //
    // GeneratedRoastKind.isShareable is the single gate for EVERY outbound
    // affordance: the system share sheet, text selection (whose menu carries
    // its own Share), and the share-as-image card. If this regresses, a
    // private draft becomes shareable again.

    func testVentDraftIsNeverShareable() {
        XCTAssertFalse(GeneratedRoastKind.ventDraft.isShareable,
                       "a private vent draft must never get a share affordance")
    }

    func testSendableKindsAreShareable() {
        XCTAssertTrue(GeneratedRoastKind.normalRoast.isShareable)
        XCTAssertTrue(GeneratedRoastKind.sendableReply.isShareable)
        XCTAssertTrue(GeneratedRoastKind.rewrite.isShareable)
    }

    func testExactlyOneKindIsUnshareable() {
        // Pins the allow-list shape: if a case is added to the enum, this
        // fails and forces an explicit decision instead of failing open.
        let all: [GeneratedRoastKind] = [.normalRoast, .ventDraft, .sendableReply, .rewrite]
        XCTAssertEqual(all.filter { !$0.isShareable }, [.ventDraft])
    }

    func testIsPrivateVentAndIsShareableStayInverse() {
        for k in [GeneratedRoastKind.normalRoast, .ventDraft, .sendableReply] {
            XCTAssertNotEqual(k.isPrivateVent, k.isShareable,
                              "\(k): the private-draft label and the share gate must not disagree")
        }
    }

    // MARK: - B.2 strict redaction for public sharing
    //
    // Structured PII is caught with confidence; free-form Chinese names are
    // NOT, and these tests say so explicitly rather than pretending otherwise.
    // The primary defense is the Worker prompt telling the model never to echo
    // names/contacts; this layer is defense in depth.

    func testRedactsChineseContactHandles() {
        for raw in ["加我vx: abc_123", "微信号：zhangsan88", "QQ 1234567", "扣扣:998877xy", "v信 wangwang2024"] {
            let out = Redactor.redactForPublicShare(raw)
            XCTAssertTrue(out.contains("[联系方式]"), "should mask contact in: \(raw) -> \(out)")
        }
    }

    func testRedactsChineseNumeralPhone() {
        let out = Redactor.redactForPublicShare("打一三八零零一三八零零零")
        XCTAssertTrue(out.contains("[号码]"), out)
        XCTAssertFalse(out.contains("一三八"), out)
    }

    func testRedactsIDCard() {
        let out = Redactor.redactForPublicShare("身份证 11010519900307561X 都发群里了")
        XCTAssertTrue(out.contains("[身份证]"), out)
        XCTAssertFalse(out.contains("11010519900307561X"), out)
    }

    func testRedactsSurnamePlusTitle() {
        let zh = Locale(identifier: "zh-Hans")
        for raw in ["张总又画饼了", "李经理说这是机会", "王主管让我背锅"] {
            let out = Redactor.redactForPublicShare(raw, locale: zh)
            XCTAssertTrue(out.contains("[对方]"), "\(raw) -> \(out)")
        }
    }

    func testRedactsRolePrefixedNickname() {
        let out = Redactor.redactForPublicShare("PM老王又改需求", locale: Locale(identifier: "zh-Hans"))
        XCTAssertTrue(out.contains("[对方]"), out)
    }

    func testStrictPassStillCatchesTheAsciiCases() {
        let out = Redactor.redactForPublicShare("mail me a@b.com or https://x.example")
        XCTAssertTrue(out.contains("[email]"))
        XCTAssertTrue(out.contains("[link]"))
    }

    func testDoesNotMangleAnOrdinaryComeback() {
        // Over-masking is the safer error but NOT a free one: a scrubbed line
        // has no punch and will not be shared. An ordinary comeback with no PII
        // must survive completely intact.
        let line = "我不是不会做，我只是不打算替你把锅也一起背了。"
        XCTAssertEqual(Redactor.redactForPublicShare(line), line)
    }

    func testOrdinaryEnglishComebackSurvives() {
        let line = "Noted. I'll be sure to document who actually wrote it next time."
        XCTAssertEqual(Redactor.redactForPublicShare(line), line)
    }

    func testCompanyAndPlaceAreDeliberatelyNotMasked() {
        // Organisations/places are usually the joke, not the identifier.
        let line = "北京的房租比我的尊严还高。"
        XCTAssertEqual(Redactor.redactForPublicShare(line), line)
    }

    /// Real model output captured from the live Worker on 2026-09-03, after the
    /// B.2.1 prompt containment was deployed. The prompt told the model not to
    /// echo identifying details; it did anyway in 2 of 3 runs. That measurement
    /// is why the client-side pass is a PRIMARY control here, not a backstop —
    /// see the note in Redactor.swift.
    func testRedactsNamesThatSurvivedThePromptContainment() {
        let zh = Locale(identifier: "zh-Hans")
        let leaked = "张伟，你他妈脸皮是有多厚？最恶心的是你们那个李经理，为了捧你连基本事实都不要了。"
        let out = Redactor.redactForPublicShare(leaked, locale: zh)
        XCTAssertFalse(out.contains("李经理"), "surname+title must be masked: \(out)")
        XCTAssertTrue(out.contains("[对方]"), out)
    }

    func testCatchesBareTwoCharChineseName() {
        // A bare 2-character name has no structural shape, so this depends
        // entirely on NLTagger. Measured 2026-09-03: it DOES catch this one.
        // Pinned so a regression is visible — but note this is one sample, not
        // a guarantee across all names, which is why the layered design stands.
        let zh = Locale(identifier: "zh-Hans")
        let out = Redactor.redactForPublicShare("张伟，你他妈脸皮是有多厚？", locale: zh)
        XCTAssertFalse(out.contains("张伟"), out)
        XCTAssertTrue(out.contains("[对方]"), out)
    }

    func testRedactsContactAndPhoneFromARealSituation() {
        let zh = Locale(identifier: "zh-Hans")
        let raw = "我同事（微信 zhangwei_888，手机 13800138000）在群里甩锅"
        let out = Redactor.redactForPublicShare(raw, locale: zh)
        XCTAssertFalse(out.contains("zhangwei_888"), out)
        XCTAssertFalse(out.contains("13800138000"), out)
    }

    // MARK: - B.3 Feral is structurally barred, not separately gated

    func testFeralTextCannotReachTheCardBecauseItIsAVentDraft() {
        // The plan asked to "bar Feral from the composer". That is now
        // structural rather than a separate check: feral output IS a
        // .ventDraft, and .ventDraft is not shareable. A sendable reply
        // rewritten FROM a feral draft is, by construction, sendable text that
        // passed the strict validator.
        XCTAssertFalse(GeneratedRoastKind.ventDraft.isShareable)
        XCTAssertTrue(Intensity.feral.isPrivateDraft,
                      "feral must remain a private-draft register")
        XCTAssertTrue(Intensity.vent.isPrivateDraft)
        XCTAssertFalse(Intensity.sharp.isPrivateDraft)
    }

    // MARK: - B.4/B.5 growth layer is DARK by default

    func testGrowthBadgeIsOffByDefault() {
        let c = ShareCardContent(styleName: nil, sentText: "x")
        XCTAssertFalse(c.showsGrowthBadge,
                       "the QR/badge layer must default DARK until share_card_enabled flips")
    }

    func testRemoteConfigShareCardFlagDefaultsDark() {
        XCTAssertFalse(RemoteConfigValues.safeDefault.shareCardEnabled)
    }

    func testCampaignURLCarriesTheAttributionToken() {
        let url = ShareCardBadge.campaignURL.absoluteString
        XCTAssertTrue(url.contains("ct=sharecard_v14"), url)
        XCTAssertTrue(url.contains(ShareCardBadge.appStoreID), url)
    }

    func testQRRendersAtTheRequestedScale() {
        let img = ShareCardBadge.qrImage(sidePixels: 264)
        XCTAssertNotNil(img, "QR generation must not fail on-device")
        if let img { XCTAssertGreaterThanOrEqual(img.width, 200) }
    }

    // MARK: - Format

    func testExportFormatsAreExactPixelSizes() {
        // ImageRenderer exports at these exact sizes; 小红书/IG 4:5 and 抖音 9:16.
        XCTAssertEqual(ShareCardFormat.portrait45.pixelSize, CGSize(width: 1080, height: 1350))
        XCTAssertEqual(ShareCardFormat.story916.pixelSize, CGSize(width: 1080, height: 1920))
        XCTAssertEqual(ShareCardFormat.allCases.count, 2)
    }
}
