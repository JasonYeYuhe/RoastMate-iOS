/* P5 Q1 W1 — RoastMate research recruit form, Step 2 (booking).
 *
 * Reads the participant_code from the URL query (?code=...). Captures
 * email + timezone in a SEPARATE HTTP request from the Step 1 answers.
 * The Worker validates the code exists in RESEARCH_ANSWERS before
 * accepting the booking write.
 *
 * No tracking pixels, no analytics, no cookies, no localStorage.
 */
'use strict';

const WORKER_ENDPOINT = window.RM_RESEARCH_WORKER_URL || 'https://roastmate-research.yyyyy-yeyuhe.workers.dev';

const STRINGS = {
  'en': {
    'step.indicator': 'Step 2 of 2 — schedule your interview',
    title: 'Book your interview slot',
    intro: 'Your anonymous answers were already submitted in Step 1. This page collects only your email and timezone, so we can email you a scheduling link. Locus / context never reaches this request.',
    codeprompt: 'Your reference code from Step 1 (auto-filled from the link):',
    codelabel: 'Code:',
    'contact.label': 'Email (so we can email a scheduling link)',
    'contact.note': 'Stored separately from your answers. Deleted within 60 days.',
    'tz.label': 'Your timezone',
    'tz.hint': 'Helps us pick a slot that works for both of us.',
    submit: 'Book my slot',
    'booked.heading': 'Booked. Thank you.',
    'booked.body': 'We will email you within a week with 2–3 slot options.',
    'booked.privacy_note': 'Your answers (Step 1) and contact info (Step 2) are stored in separate tables, both auto-expire in 60 days. You can email yyyyy.yeyuhe@gmail.com to be removed at any time.',
    'footer.brand': 'RoastMate',
    'footer.notrack': 'No third-party tracking on this page.',
    'footer.privacy': 'Privacy',
    placeholder_timezone: 'e.g. UTC+8, JST, ET, PT',
    placeholder_email: 'you@example.com',
    'status.submitting': 'Submitting…',
    'status.error_validation': 'Please provide a valid email and timezone.',
    'status.error_network': 'Could not submit. Please try again.',
    'status.error_code': 'Your reference code is invalid or expired. Please redo Step 1.'
  },
  'zh-Hans': {
    'step.indicator': '第 2 步 / 共 2 步 — 约访谈时间',
    title: '约访谈时间',
    intro: '你的研究答案已经在第 1 步匿名提交完了。这个页面只收你的邮箱和时区，方便我们发约时间邮件。你之前写的场景内容不会出现在这个请求里。',
    codeprompt: '你在第 1 步拿到的参考编号（从链接自动填入）：',
    codelabel: '编号：',
    'contact.label': '邮箱（用于发约时间链接）',
    'contact.note': '和你的答案分开存。60 天后删除。',
    'tz.label': '你的时区',
    'tz.hint': '帮我们找一个双方都方便的时间段。',
    submit: '约我',
    'booked.heading': '约好了，谢谢。',
    'booked.body': '我们会在一周内给你发邮件，里面有 2-3 个可选的时间。',
    'booked.privacy_note': '答案（第 1 步）和联系方式（第 2 步）分两张表存，都 60 天后自动过期。想随时退出可以发邮件到 yyyyy.yeyuhe@gmail.com 让我们删掉。',
    'footer.brand': 'RoastMate',
    'footer.notrack': '本页面无任何第三方追踪。',
    'footer.privacy': '隐私政策',
    placeholder_timezone: '例如 UTC+8, 北京时间',
    placeholder_email: 'you@example.com',
    'status.submitting': '提交中……',
    'status.error_validation': '请填一个有效的邮箱和时区。',
    'status.error_network': '提交失败，请重试。',
    'status.error_code': '参考编号无效或已过期，请回到第 1 步重新填写。'
  },
  'zh-Hant': {
    'step.indicator': '第 2 步 / 共 2 步 — 約訪談時間',
    title: '約訪談時間',
    intro: '你的研究答案已經在第 1 步匿名送出。這個頁面只收你的電子郵件和時區,方便我們發約時間信。你之前寫的場景內容不會出現在這個請求裡。',
    codeprompt: '你在第 1 步拿到的參考編號(從連結自動填入):',
    codelabel: '編號:',
    'contact.label': '電子郵件(用於發約時間連結)',
    'contact.note': '和你的答案分開儲存。60 天後刪除。',
    'tz.label': '你的時區',
    'tz.hint': '幫我們找一個雙方都方便的時間。',
    submit: '預約',
    'booked.heading': '預約成功,謝謝。',
    'booked.body': '我們會在一週內寄信給你,內含 2-3 個可選的時間。',
    'booked.privacy_note': '答案(第 1 步)和聯絡方式(第 2 步)分兩張表存,都 60 天後自動過期。想隨時退出可寄信到 yyyyy.yeyuhe@gmail.com 讓我們刪掉。',
    'footer.brand': 'RoastMate',
    'footer.notrack': '本頁面無任何第三方追蹤。',
    'footer.privacy': '隱私政策',
    placeholder_timezone: '例如 UTC+8, 台北時間',
    placeholder_email: 'you@example.com',
    'status.submitting': '送出中……',
    'status.error_validation': '請填一個有效的電子郵件和時區。',
    'status.error_network': '送出失敗,請重試。',
    'status.error_code': '參考編號無效或已過期,請回到第 1 步重填。'
  },
  'ja': {
    'step.indicator': 'ステップ 2/2 — インタビュー日程調整',
    title: 'インタビュー日程の調整',
    intro: 'リサーチ回答はステップ 1 で匿名送信済みです。このページではメールアドレスとタイムゾーンのみを取得します。先ほどの文脈情報はこのリクエストには含まれません。',
    codeprompt: 'ステップ 1 でお渡しした参照コード(URL から自動入力):',
    codelabel: 'コード:',
    'contact.label': 'メールアドレス(日程調整リンクを送ります)',
    'contact.note': '回答とは別に保管し、60 日以内に削除します。',
    'tz.label': 'タイムゾーン',
    'tz.hint': 'お互いに合う時間帯を選ぶために使います。',
    submit: '日程を予約',
    'booked.heading': '予約を承りました。ありがとうございます。',
    'booked.body': '1 週間以内に、候補日時を 2〜3 件メールでお送りします。',
    'booked.privacy_note': '回答(ステップ 1)と連絡先(ステップ 2)は別テーブルに保存され、60 日で自動削除されます。yyyyy.yeyuhe@gmail.com まで連絡いただければいつでも削除します。',
    'footer.brand': 'RoastMate',
    'footer.notrack': 'このページには第三者の追跡はありません。',
    'footer.privacy': 'プライバシー',
    placeholder_timezone: '例:JST, UTC+9',
    placeholder_email: 'you@example.com',
    'status.submitting': '送信中……',
    'status.error_validation': '有効なメールアドレスとタイムゾーンを入力してください。',
    'status.error_network': '送信できませんでした。再度お試しください。',
    'status.error_code': '参照コードが無効または期限切れです。ステップ 1 をやり直してください。'
  }
};

function getParam(name) {
  return new URLSearchParams(window.location.search).get(name) || '';
}

function pickInitialLocale() {
  const fromUrl = getParam('locale');
  if (STRINGS[fromUrl]) return fromUrl;
  const want = (navigator.language || 'en').toLowerCase();
  if (want.startsWith('zh')) {
    if (want.includes('hant') || want.includes('tw') || want.includes('hk') || want.includes('mo')) return 'zh-Hant';
    return 'zh-Hans';
  }
  if (want.startsWith('ja')) return 'ja';
  return 'en';
}

let currentLocale = pickInitialLocale();
const PARTICIPANT_CODE = getParam('code').toUpperCase().slice(0, 12);

function applyLocale(locale) {
  currentLocale = locale;
  document.documentElement.setAttribute('lang', locale);
  const dict = STRINGS[locale] || STRINGS.en;
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    if (dict[key] !== undefined) el.textContent = dict[key];
  });
  const tz = document.getElementById('timezone');
  if (tz) tz.placeholder = dict.placeholder_timezone || '';
  const em = document.getElementById('email');
  if (em) em.placeholder = dict.placeholder_email || '';
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
  if (!PARTICIPANT_CODE || !/^[A-Z0-9]{12}$/.test(PARTICIPANT_CODE)) {
    setStatus(dict['status.error_code'], 'error');
    return;
  }
  const form = event.currentTarget;
  const data = new FormData(form);
  const email = (data.get('email') || '').trim();
  const timezone = (data.get('timezone') || '').trim();
  if (!email || !timezone) {
    setStatus(dict['status.error_validation'], 'error');
    return;
  }
  const submit = form.querySelector('button[type="submit"]');
  submit.disabled = true;
  setStatus(dict['status.submitting'], '');
  try {
    const res = await fetch(WORKER_ENDPOINT.replace(/\/$/, '') + '/book', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        code: PARTICIPANT_CODE,
        email: email.slice(0, 120),
        timezone: timezone.slice(0, 40)
      }),
      referrerPolicy: 'no-referrer',
      credentials: 'omit'
    });
    if (!res.ok) {
      if (res.status === 404) {
        setStatus(dict['status.error_code'], 'error');
      } else {
        setStatus(dict['status.error_network'], 'error');
      }
      submit.disabled = false;
      return;
    }
    document.getElementById('book-form').hidden = true;
    document.getElementById('status').textContent = '';
    document.getElementById('booked').hidden = false;
  } catch (err) {
    setStatus(dict['status.error_network'], 'error');
    submit.disabled = false;
  }
}

document.addEventListener('DOMContentLoaded', () => {
  wireLocaleSwitcher();
  applyLocale(currentLocale);
  const codeEl = document.getElementById('participant-code');
  if (PARTICIPANT_CODE && /^[A-Z0-9]{12}$/.test(PARTICIPANT_CODE)) {
    codeEl.textContent = PARTICIPANT_CODE;
  }
  document.getElementById('book-form').addEventListener('submit', submitForm);
});
