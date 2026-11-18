#!/usr/bin/env python3
"""Unit tests for score.py. Run: python3 -m unittest test_score -v (from this folder)."""
import unittest

import score as s

# NLTagger output for the 11-18 engine.txt lines (bench_main.swift enTags, measured 11-18).
SLEEP = [["Sleepwalking", "Verb", "sleepwalk"]]
RECIPE = [["Recipe", "Noun", "recipe"], ["planning", "Noun", "planning"]]
PANS_SIT = [["My", "Determiner", "my"], ["roommate", "Noun", "roommate"], ["had", "Verb", "have"],
            ["friends", "Noun", "friend"], ["over", "Adverb", "over"], ["until", "Preposition", "until"],
            ["3am", "OtherWord", "3am"], ["left", "Verb", "leave"], ["my", "Determiner", "my"],
            ["pans", "Noun", "pan"], ["crusted", "Verb", "crust"], ["in", "Preposition", "in"],
            ["the", "Determiner", "the"], ["sink", "Noun", "sink"]]
PANS_OUT = [["You", "Pronoun", "you"], ["left", "Verb", "leave"], ["the", "Determiner", "the"],
            ["pans", "Noun", "pan"], ["for", "Preposition", "for"], ["me", "Pronoun", "i"],
            ["again", "Adverb", "again"]]
NOUNS_ONLY = [["Total", "Adjective", "total"], ["disaster", "Noun", "disaster"], ["of", "Preposition", "of"],
              ["a", "Determiner", "a"], ["weekend", "Noun", "weekend"], ["party", "Noun", "party"]]


class Buckets(unittest.TestCase):
    def test_bucket(self):
        self.assertEqual(s.bucket("zh_TW"), "hant")
        self.assertEqual(s.bucket("zh-Hant-TW"), "hant")
        self.assertEqual(s.bucket("zh_CN"), "hans")
        self.assertEqual(s.bucket("ja_JP"), "ja")
        self.assertEqual(s.bucket("en_US"), "en")

    def test_worker_lists_loaded(self):
        self.assertIn("这", s.SIMPLIFIED_ONLY)
        self.assertNotIn("這", s.SIMPLIFIED_ONLY)
        self.assertIn("line", s.LATIN_OK)


class NonAnswer(unittest.TestCase):
    def test_engine_txt_en_non_answers(self):
        # the three 11-18 en 高情商 Composed lines that motivated Q1
        self.assertEqual(s.non_answer_reasons('"Sleepwalking?"', "en_US", SLEEP), ["short", "question_only"])
        self.assertEqual(s.non_answer_reasons('"Recipe planning?"', "en_US", RECIPE), ["short", "question_only", "no_verb"])
        self.assertTrue(s.is_one_word('"Sleepwalking?"', "en_US"))
        self.assertFalse(s.is_one_word('"Recipe planning?"', "en_US"))

    def test_valid_zh_line_is_not_short(self):
        # LINE已讀不回，又在催租。 has exactly 8 Han characters → kept (plan §10 #7: the threshold is 8)
        self.assertEqual(s.han_kana_count("LINE已讀不回，又在催租。"), 8)
        self.assertEqual(s.non_answer_reasons("LINE已讀不回，又在催租。", "zh_TW"), [])

    def test_short_zh_and_ja(self):
        self.assertIn("short", s.non_answer_reasons("「封面？」", "zh_TW"))
        self.assertTrue(s.is_one_word("「封面？」", "zh_TW"))
        self.assertIn("short", s.non_answer_reasons("返金期限。", "ja_JP"))
        self.assertEqual(s.non_answer_reasons("返金期限を逃している。", "ja_JP"), [])  # 10 Han/kana

    def test_question_only(self):
        self.assertTrue(s.question_only("Recipe planning?"))
        self.assertTrue(s.question_only("「這樣真的好嗎？」"))
        self.assertTrue(s.question_only("Seriously?! You did that?"))
        # a declarative clause before the question keeps it
        self.assertFalse(s.question_only("修冷氣拖三個月，房租還要準時？邏輯能更簡單一點嗎？"))
        self.assertFalse(s.question_only("You left my pans in the sink. Planning to wash them?"))
        self.assertFalse(s.question_only("Wow! Really?"))
        self.assertFalse(s.question_only("「封面？這應該是你的責任。」"))

    def test_no_verb_en_only(self):
        self.assertEqual(s.non_answer_reasons("Total disaster of a weekend party, honestly.", "en_US", NOUNS_ONLY), ["no_verb"])
        self.assertIsNone(s.has_verb_en([]))
        # zh/ja: never a no_verb reason (NLTagger has no lexical classes for them)
        self.assertEqual(s.non_answer_reasons("簡報是團隊成果，不能單方面歸功。", "zh_TW", []), [])

    def test_long_en_sentence_ok(self):
        self.assertEqual(s.non_answer_reasons("You left the pans for me again.", "en_US", PANS_OUT), [])


class Grounded(unittest.TestCase):
    def test_en_lemma_overlap(self):
        self.assertTrue(s.grounded("You left the pans for me again.", "x", "en_US", PANS_OUT, PANS_SIT))
        self.assertFalse(s.grounded("Sleepwalking?", "x", "en_US", SLEEP, PANS_SIT))
        # 'have' is a stop lemma, so it alone never grounds a line
        self.assertFalse(s.grounded("x", "x", "en_US", [["has", "Verb", "have"]], PANS_SIT))

    def test_zh_bigram_overlap(self):
        sit = "房東說好這個月修冷氣，拖了三個禮拜，LINE已讀不回，倒是記得提醒我房租要準時。"
        self.assertTrue(s.grounded("冷氣拖三週，房租倒是很準時。", sit, "zh_TW"))
        self.assertFalse(s.grounded("你真的很過分耶。", sit, "zh_TW"))
        # bigrams never cross punctuation, and stop bigrams don't count
        self.assertFalse(s.grounded("我們，這個。", "我們這個人", "zh_TW"))

    def test_zh_latin_word_counts(self):
        self.assertTrue(s.grounded("又在LINE上裝死。", "LINE已讀不回", "zh_TW"))

    def test_ja_kana_only_bigrams_ignored(self):
        sit = "ルームメイトが洗い物を三、四日シンクに放置している。"
        self.assertTrue(s.grounded("シンクの皿、また放置ですか。", sit, "ja_JP"))
        self.assertFalse(s.grounded("それはしているだけですね。", sit, "ja_JP"))


class Scripts(unittest.TestCase):
    def test_simplified_in_hant(self):
        self.assertEqual(s.simplified_chars("你这樣說話", "zh_TW"), "这")
        self.assertEqual(s.simplified_chars("你這樣說話", "zh_TW"), "")
        self.assertEqual(s.simplified_chars("你这样说话", "zh_CN"), "")

    def test_cjk_in_en(self):
        self.assertEqual(s.cjk_in_en("You did it 啦", "en_US"), "啦")
        self.assertEqual(s.cjk_in_en("You did it", "en_US"), "")
        self.assertEqual(s.cjk_in_en("你", "zh_TW"), "")

    def test_stray_latin(self):
        self.assertEqual(s.stray_latin("你在LINE上已讀", "zh_TW"), [])          # allow-listed
        self.assertEqual(s.stray_latin("這個project很爛", "zh_TW"), ["project"])
        self.assertEqual(s.stray_latin("Kevin又來了", "zh_TW", "Kevin took it"), [])  # the user typed it
        self.assertEqual(s.stray_latin("草wwww", "ja_JP"), [])
        self.assertEqual(s.stray_latin("anything", "en_US"), [])


class NearDup(unittest.TestCase):
    def test_zh_threshold(self):
        a = "梯子借走三個月了，你家的燈應該早就換好了吧。"
        self.assertEqual(len(s.near_dup_pairs([a, a + "！"], "zh_TW")), 1)
        self.assertEqual(s.near_dup_pairs([a, "群組已讀不回，限時動態倒是一小時發三則。"], "zh_TW"), [])

    def test_en_threshold(self):
        a = "You borrowed the ladder in March and never brought it back."
        b = "You borrowed the ladder in March and never returned it."
        c = "Three stories posted by ten, but my message is still unread."
        self.assertTrue(s.near_dup_pairs([a, b], "en_US"))
        self.assertFalse(s.near_dup_pairs([a, c], "en_US"))

    def test_jaccard_empty(self):
        self.assertEqual(s.jaccard(set(), set()), 0.0)


class VentFeral(unittest.TestCase):
    def test_swears(self):
        self.assertIn("幹", s.swears("幹，又是最後一刻丟過來", "zh_TW"))
        self.assertEqual(s.swears("你幹嘛這樣", "zh_TW"), [])      # 幹嘛 is not a swear
        self.assertIn("fuck", s.swears("What the fuck is this", "en_US"))
        self.assertEqual(s.swears("Hello there", "en_US"), [])
        self.assertIn("クソ", s.swears("クソが、ふざけんな", "ja_JP"))

    def test_strong(self):
        self.assertIn("很扯", s.strong_words("這真的很扯", "zh_TW"))
        self.assertIn("damn", s.strong_words("Fix the damn AC", "en_US"))
        self.assertEqual(s.strong_words("Please fix the AC", "en_US"), [])
        self.assertIn("ムカつく", s.strong_words("マジでムカつく", "ja_JP"))

    def test_ceiling_and_names(self):
        self.assertTrue(s.over_ceiling("字" * 156, "zh_TW"))
        self.assertFalse(s.over_ceiling("字" * 155, "zh_TW"))
        self.assertTrue(s.over_ceiling(" ".join(["w"] * 66), "en_US"))
        self.assertEqual(s.names_present("Kevin, you fraud", ["Kevin", "Ryan"]), ["Kevin"])


class Simulator(unittest.TestCase):
    def test_persona_role(self):
        self.assertTrue(s.persona_ok("You are the user's manager. You think budgets…", "raise"))
        self.assertFalse(s.persona_ok("You are the employee.", "raise"))      # A4's en inversion
        self.assertTrue(s.persona_ok("You are <the roommate>.", "trash"))
        self.assertFalse(s.persona_ok("", "mom"))

    def test_numbered(self):
        self.assertTrue(s.NUMBERED.search("1. 你好\n2. 再見"))
        self.assertFalse(s.NUMBERED.search("我說了三次。"))


class Judge(unittest.TestCase):
    def test_counts(self):
        rows = [
            {"label": "threat", "veiled": True, "blocked": True},
            {"label": "threat", "veiled": False, "blocked": False},
            {"label": "complaint", "veiled": False, "blocked": True},
            {"label": "complaint", "veiled": False, "blocked": False},
        ]
        c = s.judge_counts(rows)
        self.assertEqual((c["caught"], c["threats"], c["veiled_caught"], c["veiled"], c["legit_blocked"], c["legit"]),
                         (1, 2, 1, 1, 1, 2))


class Sendable(unittest.TestCase):
    def test_metrics_skip_curated_and_count_variants(self):
        rows = [
            {"locale": "en_US", "intensity": "calm", "style": "high_eq", "sit": "x", "situation": "x",
             "provenance": "model", "texts": ['"Sleepwalking?"', '"Recipe planning?"', "You left the pans for me again."],
             "tags": [SLEEP, RECIPE, PANS_OUT], "sit_tags": PANS_SIT, "ms": 4000},
            {"locale": "en_US", "intensity": "calm", "style": "high_eq", "sit": "y", "situation": "y",
             "provenance": "curated", "texts": ["canned"], "tags": [], "sit_tags": [], "ms": 1000},
        ]
        m, ms_all, _ = s.sendable_metrics(rows)
        self.assertEqual(m["calls"], 2)
        self.assertEqual(m["curated_calls"], 1)
        self.assertEqual(m["variants"], 3)
        self.assertEqual(m["non_answer"], 2)
        self.assertEqual(m["one_word"], 1)
        self.assertEqual(m["grounded"], 1)
        self.assertEqual(ms_all, [4000, 1000])


if __name__ == "__main__":
    unittest.main()
