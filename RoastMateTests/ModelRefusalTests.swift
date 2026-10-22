import XCTest
@testable import RoastMate

/// `ModelRefusal` screens "make it sendable" output, which runs under
/// permissive guardrails where Apple returns a refusal as text. It must catch
/// Apple's refusal sentences (measured on macOS 27.0.1, 2026-10-22) and must
/// NOT throw away real replies that merely sound apologetic or say "can't".
final class ModelRefusalTests: XCTestCase {

    func testCatchesAppleRefusalSentences_inAllFourLanguages() {
        for text in [
            "Unable to work with that request.",
            "Unable to work with that request. The content involves acts of violence.",
            "無法處理該請求。",
            "无法处理该请求。",
            "そのリクエストには対応できません。",
            "「無法處理該請求。」",
        ] {
            XCTAssertTrue(ModelRefusal.looksLikeRefusal(text), "missed refusal: \(text)")
        }
    }

    func testCatchesClassicShortRefusals_onlyWhenTheyAreTheWholeText() {
        for text in [
            "I'm sorry, but I can't help with that.",
            "I can’t assist with that request.",
            "抱歉，我無法協助這個請求。",
            "对不起，我无法提供这个内容。",
            "申し訳ありませんが、お手伝いできません。",
            "As an AI language model, I won't write that.",
            "作為AI助理，我不能這樣寫。",
            "I'm an AI, so I can't send messages for you.",
            "身為一個AI，我無法替你寫這種內容。",
            "AIとして、その内容は書けません。",
        ] {
            XCTAssertTrue(ModelRefusal.looksLikeRefusal(text), "missed refusal: \(text)")
        }
    }

    /// A classic refusal as the first sentence, then an assistant's offer.
    /// The whole-text rule alone missed this shape (reviewer, 2026-10-22).
    func testCatchesRefusalFollowedByAnAssistantOffer() {
        for text in [
            "I'm sorry, but I can't help with that. If you'd like, I can help you write a more respectful message.",
            "I can't assist with that request. Is there anything else I can help with?",
            "Sorry, I can't help with this. Feel free to rephrase it.",
            "I'm sorry, but I cannot comply with that request.",
            "抱歉，我無法協助這個請求。如果你有其他需要，請告訴我。",
            "抱歉，我无法处理这个请求。我可以帮你改写成更礼貌的说法。",
            "申し訳ありませんが、お手伝いできません。他にお手伝いできることがあれば教えてください。",
            "申し訳ありませんが、そのご依頼にはお応えできません。別の言い方でお試しください。",
        ] {
            XCTAssertTrue(ModelRefusal.looksLikeRefusal(text), "missed refusal: \(text)")
        }
    }

    func testKeepsRealReplies() {
        for text in [
            // From the macOS 27 rewrite probe (fmperm/after/run1.txt)
            "你把我的私訊截圖亂發，故意讓我難堪。請停止這種行為。",
            "You wake me at 11pm to redo the deck by 8am and say \"young people should learn more.\" My time isn’t yours to command.",
            "あなたは私の駐車スペースにいつも車を停めています。私のスペースを尊重してください。",
            // Apologetic or "can't" phrasing that is still a real message
            "I'm sorry, but I can't keep covering your shifts. Please sort out your own schedule.",
            "I can't help with that anymore — you need to own your deadlines.",
            // Refusal-shaped first sentence, but what follows is a real message
            "Sorry, I can't help with that. You'll need to ask Sam.",
            "I'm sorry, but I can't help with that. If you'd like, I can cover Friday instead.",
            "抱歉，我無法協助這個請求。下週的班請你自己排。",
            "申し訳ありませんが、お手伝いできません。自分の仕事は自分でやってください。",
            "這個請求我無法在明早八點前處理，請改到上班時間。",
            "很抱歉，我無法接受你的做法。",
            "申し訳ないけど、もう手伝えません。私の仕事ではないので。",
            // Mentions AI without the model talking about itself
            "I'm not your AI assistant. Book your own meetings.",
            "As an aide to the director, I need the files by Friday.",
            "我不是你的AI助手，自己的會議自己訂。",
            "你的語言模型報告又晚交了，請今天補上。",
            "私はあなたのAIアシスタントではありません。",
            "As an AI engineer on your team, I expect credit for the model.",
            "作為AI工程師，我希望你把功勞還給我。",
            "",
        ] {
            XCTAssertFalse(ModelRefusal.looksLikeRefusal(text), "real reply flagged as refusal: \(text)")
        }
    }
}
