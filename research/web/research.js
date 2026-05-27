/* P5 Q1 W1 — RoastMate research recruit form. No third-party deps.
 * Locale switcher (en / zh-Hans / zh-Hant / ja) + POST to Cloudflare
 * Worker endpoint. See research/worker/ for the server side.
 *
 * Privacy posture:
 *   - No tracking pixels, no analytics, no cookies set by this page.
 *   - The email field is sent to the Worker, which stores it under a
 *     SEPARATE KV namespace from the answers (Codex catch on the v1
 *     research protocol).
 *   - Locale preference is held in memory only (no localStorage).
 */
'use strict';

// Deployed Cloudflare Worker endpoint. The `window.RM_RESEARCH_WORKER_URL`
// override is for local previews / future deploys; baked-in value is the
// production URL.
const WORKER_ENDPOINT = window.RM_RESEARCH_WORKER_URL || 'https://roastmate-research.yyyyy-yeyuhe.workers.dev';

const STRINGS = {
  'en': {
    title: 'RoastMate research interview',
    intro: 'We are recruiting 20 people for a 30-minute paid research call about how you use RoastMate. Your participation helps us pick which surfaces to build next.',
    'meta.compensation': 'Compensation: a 50-credit IAP offer code (~$2.99 value).',
    'meta.duration': 'Time: 30 minutes by FaceTime / Zoom / WeChat — your choice.',
    'meta.privacy': 'Privacy: audio only, no recordings, no vent content asked. Telemetry consent not required.',
    'q1.label': '1. When was the last time you wanted to send a message you could not?',
    'q1.this_week': 'This week',
    'q1.this_month': 'This month',
    'q1.longer': 'Longer ago',
    'q1.cant_remember': "Can't remember",
    'q1.prefer_not_say': 'Prefer not to say',
    'q2.label': '2. Available for a 30-minute video call in the next 2 weeks?',
    'q2.yes': 'Yes',
    'q2.no': 'No',
    'q2.timezone': 'Your timezone (so we can find a slot)',
    'q3.label': '3. In which app or context were you typing when the moment hit?',
    'q3.hint': 'Just write it freely — no need to specify anything sensitive.',
    'contact.label': 'Email (so we can schedule)',
    'contact.note': 'Stored separately from your answers. Deleted within 30 days.',
    submit: 'Submit',
    'footer.brand': 'RoastMate',
    'footer.notrack': 'No third-party tracking on this page.',
    'footer.privacy': 'Privacy',
    'status.submitting': 'Submitting…',
    'status.ok': 'Thanks. We will reach out within a week. Your reference: ',
    'status.error_validation': 'Please complete every required field.',
    'status.error_network': 'Could not submit. Please try again in a moment.',
    placeholder_timezone: 'e.g. UTC+8, JST, ET, PT',
    placeholder_email: 'you@example.com'
  },
  'zh-Hans': {
    title: 'RoastMate 用户访谈招募',
    intro: '我们正在招募 20 位用户做 30 分钟的付费访谈，聊聊你怎么用 RoastMate。你的参与会决定我们下一步做哪些产品形态。',
    'meta.compensation': '报酬：50 个积分的兑换码（约价值 ¥21）。',
    'meta.duration': '时长：30 分钟，可用 FaceTime / 腾讯会议 / 微信视频，你选。',
    'meta.privacy': '隐私：仅音频通话，不录像，不会问你具体写过什么。无需授权使用统计。',
    'q1.label': '1. 你最近一次想发又没发出去的信息是什么时候的事？',
    'q1.this_week': '这一周',
    'q1.this_month': '这个月',
    'q1.longer': '更早',
    'q1.cant_remember': '想不起来',
    'q1.prefer_not_say': '不想说',
    'q2.label': '2. 接下来两周里能空出 30 分钟做一次视频访谈吗？',
    'q2.yes': '能',
    'q2.no': '不能',
    'q2.timezone': '你的时区（方便我们约时间）',
    'q3.label': '3. 那个想发又没发出去的瞬间，你当时在哪个 app 或场景里？',
    'q3.hint': '随便写就行 — 不需要写任何敏感内容。',
    'contact.label': '邮箱（用于约时间）',
    'contact.note': '邮箱和你的答案分开存。30 天后删除。',
    submit: '提交',
    'footer.brand': 'RoastMate',
    'footer.notrack': '本页面无任何第三方追踪。',
    'footer.privacy': '隐私政策',
    'status.submitting': '提交中……',
    'status.ok': '谢谢。我们会在一周内联系你。你的参考编号：',
    'status.error_validation': '请把所有必填项填完。',
    'status.error_network': '提交失败，请稍后重试。',
    placeholder_timezone: '例如 UTC+8, 北京时间',
    placeholder_email: 'you@example.com'
  },
  'zh-Hant': {
    title: 'RoastMate 使用者訪談招募',
    intro: '我們正在招募 20 位使用者做 30 分鐘的付費訪談,聊聊你怎麼用 RoastMate。你的參與會決定我們下一步做哪些產品形態。',
    'meta.compensation': '報酬:50 個點數的兌換碼(約值 NT$90)。',
    'meta.duration': '時長:30 分鐘,可用 FaceTime / LINE / Zoom,你選。',
    'meta.privacy': '隱私:僅音訊通話,不錄影,不會問你具體寫過什麼。不需要授權使用統計。',
    'q1.label': '1. 你最近一次想發又沒發出去的訊息是什麼時候的事?',
    'q1.this_week': '這一週',
    'q1.this_month': '這個月',
    'q1.longer': '更早',
    'q1.cant_remember': '想不起來',
    'q1.prefer_not_say': '不想說',
    'q2.label': '2. 接下來兩週裡能空出 30 分鐘做一次視訊訪談嗎?',
    'q2.yes': '能',
    'q2.no': '不能',
    'q2.timezone': '你的時區(方便我們約時間)',
    'q3.label': '3. 那個想發又沒發出去的瞬間,你當時在哪個 app 或場景裡?',
    'q3.hint': '隨便寫就行 — 不需要寫任何敏感內容。',
    'contact.label': '電子郵件(用於約時間)',
    'contact.note': '郵件和你的答案分開存。30 天後刪除。',
    submit: '送出',
    'footer.brand': 'RoastMate',
    'footer.notrack': '本頁面無任何第三方追蹤。',
    'footer.privacy': '隱私政策',
    'status.submitting': '送出中……',
    'status.ok': '謝謝。我們會在一週內與你聯絡。你的參考編號:',
    'status.error_validation': '請把所有必填項填完。',
    'status.error_network': '送出失敗,請稍後再試。',
    placeholder_timezone: '例如 UTC+8, 台北時間',
    placeholder_email: 'you@example.com'
  },
  'ja': {
    title: 'RoastMate ユーザーインタビュー募集',
    intro: 'RoastMate の使い方について 30 分の有料インタビューに参加いただける方を 20 名募集しています。あなたの声が次に作る機能を決めます。',
    'meta.compensation': '謝礼:50クレジットのIAPオファーコード(約 450 円相当)。',
    'meta.duration': '所要時間:30分。FaceTime / Zoom / LINE のいずれかで。',
    'meta.privacy': 'プライバシー:音声のみ・録音なし・実際の文面は伺いません。利用統計の許可は不要。',
    'q1.label': '1. 送りたかったけど送れなかったメッセージ — 直近はいつでしたか?',
    'q1.this_week': '今週',
    'q1.this_month': '今月',
    'q1.longer': 'もっと前',
    'q1.cant_remember': '思い出せない',
    'q1.prefer_not_say': '答えたくない',
    'q2.label': '2. 今後 2 週間以内に 30 分のビデオ通話に参加できますか?',
    'q2.yes': 'はい',
    'q2.no': 'いいえ',
    'q2.timezone': 'タイムゾーン(時間調整のため)',
    'q3.label': '3. その送れなかった瞬間 — どのアプリ・どんな場面で打っていましたか?',
    'q3.hint': '自由に書いてください。具体的な内容や個人情報は不要です。',
    'contact.label': 'メールアドレス(日程調整用)',
    'contact.note': '回答とは別に保管し、30 日以内に削除します。',
    submit: '送信',
    'footer.brand': 'RoastMate',
    'footer.notrack': 'このページには第三者の追跡はありません。',
    'footer.privacy': 'プライバシー',
    'status.submitting': '送信中……',
    'status.ok': 'ありがとうございます。1 週間以内にご連絡します。参照番号:',
    'status.error_validation': '必須項目をすべて入力してください。',
    'status.error_network': '送信できませんでした。少し時間をおいてお試しください。',
    placeholder_timezone: '例:JST, UTC+9',
    placeholder_email: 'you@example.com'
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
  // Placeholders aren't in [data-i18n]; set explicitly.
  const tz = document.getElementById('timezone');
  if (tz) tz.placeholder = dict.placeholder_timezone || '';
  const em = document.getElementById('email');
  if (em) em.placeholder = dict.placeholder_email || '';
  // ARIA-pressed mirror on locale buttons.
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
  // Bare-bones validation; native required attr already covers most.
  if (!data.get('recency') || !data.get('available') || !data.get('locus') || !data.get('email')) {
    setStatus(dict['status.error_validation'], 'error');
    return;
  }
  if (!WORKER_ENDPOINT) {
    setStatus(dict['status.error_network'] + ' (no endpoint configured)', 'error');
    return;
  }
  const payload = {
    recency: data.get('recency'),
    available: data.get('available'),
    timezone: (data.get('timezone') || '').slice(0, 40),
    locus: (data.get('locus') || '').slice(0, 200),
    email: (data.get('email') || '').slice(0, 120),
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
    const code = body.participant_code || '?';
    setStatus(dict['status.ok'] + code, 'ok');
    form.reset();
  } catch (err) {
    setStatus(dict['status.error_network'], 'error');
    submit.disabled = false;
  }
}

document.addEventListener('DOMContentLoaded', () => {
  wireLocaleSwitcher();
  applyLocale(currentLocale);
  document.getElementById('research-form').addEventListener('submit', submitForm);
});
