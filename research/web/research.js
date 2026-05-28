/* P5 Q1 W1 — RoastMate research recruit form, Step 1.
 *
 * Anonymous-first refactor (Gemini audit 2026-05-28): this page submits
 * ONLY the three research questions. No email, no timezone, no PII. On
 * success, the user is shown their participant_code and a link to the
 * Step 2 page (research-book.html) where email + timezone are captured
 * SEPARATELY. Locus context and email never travel in the same HTTP
 * request.
 *
 * No tracking pixels, no analytics, no cookies, no localStorage.
 */
'use strict';

const WORKER_ENDPOINT = window.RM_RESEARCH_WORKER_URL || 'https://roastmate-research.yyyyy-yeyuhe.workers.dev';

const STRINGS = {
  'en': {
    'step.indicator': 'Step 1 of 2 — anonymous research questions',
    title: 'RoastMate research interview',
    intro: 'We are recruiting 20 people for a 30-minute interview about how you use RoastMate. This step asks the research questions; the next step (booking) is on a separate page and captures your email + timezone independently.',
    'meta.compensation': 'Compensation: 1 year of RoastMate Pro free, via Apple offer code (you redeem in App Store after the call — no PII exchange).',
    'meta.duration': 'Time: 30 minutes by FaceTime / Zoom / WeChat — your choice, scheduled on the next page.',
    'meta.privacy_step1': 'Privacy: this page submits anonymously. Your email + timezone are captured separately on the next page so they never travel in the same payload as your answers.',
    'q1.label': '1. When was the last time you wanted to send a message you could not?',
    'q1.this_week': 'This week',
    'q1.this_month': 'This month',
    'q1.longer': 'Longer ago',
    'q1.cant_remember': "Can't remember",
    'q1.prefer_not_say': 'Prefer not to say',
    'q2.label': '2. Available for a 30-minute video call in the next 2 weeks?',
    'q2.yes': 'Yes',
    'q2.no': 'No',
    'q3.label': '3. In which app or context were you typing when the moment hit?',
    'q3.hint': 'Just write it freely — no need to specify anything sensitive.',
    submit_step1: 'Submit answers (anonymous)',
    'success.heading': 'Got it. Thank you.',
    'success.body': 'Your research answers were submitted anonymously. To schedule the interview, go to Step 2 — your reference code is below.',
    'success.code_label': 'Your reference code:',
    'success.book_cta': 'Step 2 — Book your interview slot →',
    'success.privacy_note': 'Keep this reference code if you want to come back later. The code expires in 60 days.',
    'footer.brand': 'RoastMate',
    'footer.notrack': 'No third-party tracking on this page.',
    'footer.privacy': 'Privacy',
    'status.submitting': 'Submitting…',
    'status.error_validation': 'Please complete every required field.',
    'status.error_network': 'Could not submit. Please try again in a moment.'
  },
  'zh-Hans': {
    'step.indicator': '第 1 步 / 共 2 步 — 匿名研究问题',
    title: 'RoastMate 用户访谈招募',
    intro: '我们在招募 20 位用户做 30 分钟的访谈，聊聊你怎么用 RoastMate。这一步只问研究问题；下一步（约时间）是单独的页面，分开收你的邮箱和时区。',
    'meta.compensation': '报酬：免费 1 年 RoastMate Pro 订阅，访谈结束后通过 Apple 兑换码发给你（App Store 里兑换，无需交换任何个人信息）。',
    'meta.duration': '时长：30 分钟，可用 FaceTime / 腾讯会议 / 微信视频，下一步约时间。',
    'meta.privacy_step1': '隐私：这个页面纯匿名提交，邮箱和时区在下一步单独收，确保它们和你的答案不会出现在同一个请求里。',
    'q1.label': '1. 你最近一次想发又没发出去的信息是什么时候的事？',
    'q1.this_week': '这一周',
    'q1.this_month': '这个月',
    'q1.longer': '更早',
    'q1.cant_remember': '想不起来',
    'q1.prefer_not_say': '不想说',
    'q2.label': '2. 接下来两周里能空出 30 分钟做一次视频访谈吗？',
    'q2.yes': '能',
    'q2.no': '不能',
    'q3.label': '3. 那个想发又没发出去的瞬间，你当时在哪个 app 或场景里？',
    'q3.hint': '随便写就行 — 不需要写任何敏感内容。',
    submit_step1: '提交答案（匿名）',
    'success.heading': '收到，谢谢你。',
    'success.body': '你的研究答案已匿名提交。要约访谈时间，请进入第 2 步——下面是你的参考编号。',
    'success.code_label': '参考编号：',
    'success.book_cta': '第 2 步 — 约访谈时间 →',
    'success.privacy_note': '如果想之后再约，把参考编号保留好。编号 60 天后过期。',
    'footer.brand': 'RoastMate',
    'footer.notrack': '本页面无任何第三方追踪。',
    'footer.privacy': '隐私政策',
    'status.submitting': '提交中……',
    'status.error_validation': '请把所有必填项填完。',
    'status.error_network': '提交失败，请稍后重试。'
  },
  'zh-Hant': {
    'step.indicator': '第 1 步 / 共 2 步 — 匿名研究問題',
    title: 'RoastMate 使用者訪談招募',
    intro: '我們在招募 20 位使用者做 30 分鐘的訪談,聊聊你怎麼用 RoastMate。這一步只問研究問題;下一步(約時間)是獨立頁面,分開收你的電子郵件和時區。',
    'meta.compensation': '報酬:免費 1 年 RoastMate Pro 訂閱,訪談結束後透過 Apple 兌換碼發給你(在 App Store 兌換,無需交換任何個人資料)。',
    'meta.duration': '時長:30 分鐘,可用 FaceTime / LINE / Zoom,下一步約時間。',
    'meta.privacy_step1': '隱私:這個頁面純匿名提交,電子郵件和時區在下一步單獨收,確保它們和你的答案不會出現在同一個請求裡。',
    'q1.label': '1. 你最近一次想發又沒發出去的訊息是什麼時候的事?',
    'q1.this_week': '這一週',
    'q1.this_month': '這個月',
    'q1.longer': '更早',
    'q1.cant_remember': '想不起來',
    'q1.prefer_not_say': '不想說',
    'q2.label': '2. 接下來兩週裡能空出 30 分鐘做一次視訊訪談嗎?',
    'q2.yes': '能',
    'q2.no': '不能',
    'q3.label': '3. 那個想發又沒發出去的瞬間,你當時在哪個 app 或場景裡?',
    'q3.hint': '隨便寫就行 — 不需要寫任何敏感內容。',
    submit_step1: '送出答案(匿名)',
    'success.heading': '收到,謝謝你。',
    'success.body': '你的研究答案已匿名送出。要約訪談時間,請進入第 2 步——下方是你的參考編號。',
    'success.code_label': '參考編號:',
    'success.book_cta': '第 2 步 — 約訪談時間 →',
    'success.privacy_note': '如果想之後再約,把參考編號保留好。編號 60 天後過期。',
    'footer.brand': 'RoastMate',
    'footer.notrack': '本頁面無任何第三方追蹤。',
    'footer.privacy': '隱私政策',
    'status.submitting': '送出中……',
    'status.error_validation': '請把所有必填項填完。',
    'status.error_network': '送出失敗,請稍後再試。'
  },
  'ja': {
    'step.indicator': 'ステップ 1/2 — 匿名のリサーチ質問',
    title: 'RoastMate ユーザーインタビュー募集',
    intro: 'RoastMate の使い方について 30 分のインタビューに参加いただける方を 20 名募集しています。このステップではリサーチ質問のみ。次のステップ(予約)は別ページで、メールとタイムゾーンを独立に取得します。',
    'meta.compensation': '謝礼:RoastMate Pro 1 年無料サブスクリプション。インタビュー終了後に Apple オファーコードをお送りします(App Store で引き換え、個人情報のやり取りは不要)。',
    'meta.duration': '所要時間:30分。FaceTime / Zoom / LINE のいずれかで、次のステップで日程調整。',
    'meta.privacy_step1': 'プライバシー:このページは匿名送信。メールとタイムゾーンは次のステップで別途取得するため、回答と同じリクエストには載りません。',
    'q1.label': '1. 送りたかったけど送れなかったメッセージ — 直近はいつでしたか?',
    'q1.this_week': '今週',
    'q1.this_month': '今月',
    'q1.longer': 'もっと前',
    'q1.cant_remember': '思い出せない',
    'q1.prefer_not_say': '答えたくない',
    'q2.label': '2. 今後 2 週間以内に 30 分のビデオ通話に参加できますか?',
    'q2.yes': 'はい',
    'q2.no': 'いいえ',
    'q3.label': '3. その送れなかった瞬間 — どのアプリ・どんな場面で打っていましたか?',
    'q3.hint': '自由に書いてください。具体的な内容や個人情報は不要です。',
    submit_step1: '回答を送信(匿名)',
    'success.heading': '受け付けました。ありがとうございます。',
    'success.body': '匿名で回答を送信しました。インタビュー日程の調整はステップ 2 へ。参照コードは下記。',
    'success.code_label': '参照コード:',
    'success.book_cta': 'ステップ 2 — インタビュー日程を調整 →',
    'success.privacy_note': '後日また予約する場合は参照コードを保管してください。コードは 60 日で失効します。',
    'footer.brand': 'RoastMate',
    'footer.notrack': 'このページには第三者の追跡はありません。',
    'footer.privacy': 'プライバシー',
    'status.submitting': '送信中……',
    'status.error_validation': '必須項目をすべて入力してください。',
    'status.error_network': '送信できませんでした。少し時間をおいてお試しください。'
  }
};

function pickInitialLocale() {
  const want = (navigator.language || 'en').toLowerCase();
  if (want.startsWith('zh')) {
    if (want.includes('hant') || want.includes('tw') || want.includes('hk') || want.includes('mo')) {
      return 'zh-Hant';
    }
    return 'zh-Hans';
  }
  if (want.startsWith('ja')) return 'ja';
  return 'en';
}

let currentLocale = pickInitialLocale();

function applyLocale(locale) {
  currentLocale = locale;
  document.documentElement.setAttribute('lang', locale);
  const dict = STRINGS[locale] || STRINGS.en;
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    if (dict[key] !== undefined) el.textContent = dict[key];
  });
  document.querySelectorAll('nav button[data-locale]').forEach(btn => {
    btn.setAttribute('aria-pressed', btn.dataset.locale === locale ? 'true' : 'false');
  });
}

function wireLocaleSwitcher() {
  document.querySelectorAll('nav button[data-locale]').forEach(btn => {
    btn.addEventListener('click', () => applyLocale(btn.dataset.locale));
  });
}

function setStatus(msg, kind) {
  const s = document.getElementById('status');
  s.textContent = msg;
  s.className = kind || '';
}

async function submitForm(event) {
  event.preventDefault();
  const dict = STRINGS[currentLocale] || STRINGS.en;
  const form = event.currentTarget;
  const data = new FormData(form);
  if (!data.get('recency') || !data.get('available') || !data.get('locus')) {
    setStatus(dict['status.error_validation'], 'error');
    return;
  }
  const payload = {
    recency: data.get('recency'),
    available: data.get('available'),
    locus: (data.get('locus') || '').slice(0, 200),
    locale: currentLocale
  };
  const submit = form.querySelector('button[type="submit"]');
  submit.disabled = true;
  setStatus(dict['status.submitting'], '');
  try {
    const res = await fetch(WORKER_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
      referrerPolicy: 'no-referrer',
      credentials: 'omit'
    });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    const body = await res.json();
    const code = body.participant_code;
    showSuccess(code);
  } catch (err) {
    setStatus(dict['status.error_network'], 'error');
    submit.disabled = false;
  }
}

function showSuccess(code) {
  document.getElementById('research-form').hidden = true;
  document.getElementById('status').textContent = '';
  document.getElementById('success-code').textContent = code;
  const link = document.getElementById('book-link');
  link.href = `research-book.html?code=${encodeURIComponent(code)}&locale=${encodeURIComponent(currentLocale)}`;
  document.getElementById('success').hidden = false;
}

document.addEventListener('DOMContentLoaded', () => {
  wireLocaleSwitcher();
  applyLocale(currentLocale);
  document.getElementById('research-form').addEventListener('submit', submitForm);
});
