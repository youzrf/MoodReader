/* 声笺 · 浏览器交互演示
 * 断句/情绪规则在 segmenter.js，本文件负责界面、朗读、暂停与书签。
 */
(function () {
  'use strict';

  const { segment, chunkIndexForSentence, resolveEmotion, EMOTIONS } = window.Shengjian;

  const STORE_KEY = 'shengjian.demo.v1';
  const SPEEDS = [0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4];

  const samples = [
    {
      id: 'sample-0',
      title: '深夜便利店',
      author: '声笺 · 短篇',
      seed: 0,
      content: `城市在凌晨两点的时候，会露出另一种表情。

我推开便利店的门，风铃“叮”地响了一声。收银台后面的年轻人抬起头，冲我笑了一下：“还是老样子？”

“嗯，一杯热豆浆。”我说。

他把杯子放到机器下面，白色的热气很快涌上来，像一小团舍不得散开的云。窗外有出租车驶过，灯光从玻璃上滑下去，整条街又安静了。

我忽然想起很多年前，也是这样的深夜，也有人问过我要不要喝点热的。那时候我急着赶路，摇了摇头。后来才明白，有些热气，错过了就不会再有。

“您的豆浆。”他把杯子推过来，又补了一句，“小心烫。”

我捧着杯子走出门。夜风很凉，掌心却很暖。城市没有说话，只是把一盏一盏的灯，留给了还醒着的人。`
    },
    {
      id: 'sample-1',
      title: '海边的第七封信',
      author: '声笺 · 书信',
      seed: 1,
      content: `亲爱的阿遥：

这是我写给你的第七封信。前六封都没有寄出去，它们安静地躺在抽屉里，像六只不肯远行的纸船。

今天下午，我去了我们以前常去的那片海。风很大，浪一层一层地推上来，又退回去。我在礁石上坐了很久，直到鞋底沾满了细碎的沙。

你还记得吗？你说过，海是不会记住任何人的。可我不信。要不然，为什么每一次潮水涌上来，都像是在叫谁的名字？

我带了一枚硬币，原本想替你许个愿。可硬币在掌心握得太久，竟然也暖了。最后我没有把它扔进海里，而是放回了口袋。

有些愿望，也许不必实现。只要它还在，就已经足够让人走下去。

天色暗下来的时候，我听见远处有人在笑。那笑声被风吹得断断续续，却让我忽然很想你。

阿遥，如果你收到这封信，不必急着回。你只要知道，在很远的地方，有一个人把海的声音，折进了纸里。

祝你好眠。

林岸
十一月十七日`
    },
    {
      id: 'sample-2',
      title: '把日子读慢一点',
      author: '声笺 · 随笔',
      seed: 2,
      content: `我们总是太着急了。

急着起床，急着赶路，急着把一天的事情做完，再急着睡去。手机里的消息一条接一条，像雨点落在铁皮屋顶上，热闹，却听不清哪一滴才是自己的声音。

有一天，我故意把闹钟关掉，睡到自然醒。阳光已经爬到了书桌边上，灰尘在光里慢慢地飘。我给自己煮了一壶茶，没有放音乐，也没有打开任何屏幕。

水开的时候，壶盖轻轻跳动，发出“嗒、嗒”的声响。我忽然觉得，这声音很好听。不是因为它有多美，而是因为我终于有空，把它听完。

楼下的老人正在浇花。他浇得很慢，一勺一勺，像是怕惊动了叶子上的光。我趴在窗边看了很久，心里那根一直绷着的弦，悄悄地松了一点。

慢下来，并不是把生活停下来。而是让眼睛重新看见，让耳朵重新听见，让心重新回到身体里。

如果你也觉得累了，不妨试试：把手机放远一点，把呼吸放长一点。然后，听一段文字，读一页书，或者，只是安安静静地，喝完一杯热水。

日子不会因为我们的匆忙而变短，却会因为我们的停留，变得厚一点。

今天，也请慢一点。`
    }
  ];

  const state = {
    books: [],
    currentBookId: null,
    seg: { chunks: [], sentences: [] },
    sentenceIndex: 0,
    chunkIndex: 0,
    emotionMode: 'auto',
    speed: 1,
    voiceURI: '',
    autoScroll: true,
    playing: false,
    paused: false,
    finished: false,
    runId: 0,
    advanceTimer: null,
    resumeNeedsSpeak: false,
    sheet: null,
    toastTimer: null,
    saveTimer: null
  };

  const $ = (selector) => document.querySelector(selector);
  const $$ = (selector) => Array.from(document.querySelectorAll(selector));

  const dom = {
    greeting: $('#greeting'),
    today: $('#today'),
    bookCount: $('#bookCount'),
    bookGrid: $('#bookGrid'),
    continueHost: $('#continueHost'),
    libraryScreen: $('#libraryScreen'),
    readerScreen: $('#readerScreen'),
    readerTitle: $('#readerTitle'),
    readerMeta: $('#readerMeta'),
    readerText: $('#readerText'),
    readerScroll: $('#readerScroll'),
    readerProgress: $('#readerProgress'),
    readerBookmarkBtn: $('#readerBookmarkBtn'),
    readerBookmarkIcon: $('#readerBookmarkIcon'),
    playerBookmarkBtn: $('#playerBookmarkBtn'),
    playerBookmarkIcon: $('#playerBookmarkIcon'),
    emotionChip: $('#emotionChip'),
    playerCount: $('#playerCount'),
    snippet: $('#snippet'),
    playerProgress: $('#playerProgress'),
    speedBtn: $('#speedBtn'),
    playBtn: $('#playBtn'),
    playIcon: $('#playIcon'),
    prevBtn: $('#prevBtn'),
    nextBtn: $('#nextBtn'),
    emotionBtn: $('#emotionBtn'),
    emotionLabel: $('#emotionLabel'),
    emotionIcon: $('#emotionIcon'),
    settingsBtn: $('#settingsBtn'),
    backBtn: $('#backBtn'),
    readerMenuBtn: $('#readerMenuBtn'),
    sheetBackdrop: $('#sheetBackdrop'),
    bookmarksSheet: $('#bookmarksSheet'),
    settingsSheet: $('#settingsSheet'),
    menuSheet: $('#menuSheet'),
    newSheet: $('#newSheet'),
    bookmarksBody: $('#bookmarksBody'),
    bookmarksSub: $('#bookmarksSub'),
    voiceList: $('#voiceList'),
    speedRange: $('#speedRange'),
    speedValue: $('#speedValue'),
    speedValue2: $('#speedValue2'),
    emotionGrid: $('#emotionGrid'),
    emotionDesc: $('#emotionDesc'),
    autoScrollSwitch: $('#autoScrollSwitch'),
    newTitle: $('#newTitle'),
    newAuthor: $('#newAuthor'),
    newText: $('#newText'),
    createBookBtn: $('#createBookBtn'),
    toast: $('#toast'),
    toastText: $('#toastText')
  };

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  function clamp(value, low, high) {
    return Math.min(high, Math.max(low, value));
  }

  function escapeHTML(value) {
    return String(value).replace(/[&<>"']/g, (char) => ({
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;'
    }[char]));
  }

  function uid() {
    if (window.crypto && crypto.randomUUID) return crypto.randomUUID();
    return `id-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
  }

  function firstCharacter(title) {
    return Array.from((title || '声').trim())[0] || '声';
  }

  function readingMinutes(book) {
    return Math.max(1, Math.ceil((book.content || '').length / 320));
  }

  function minutesLabel(book) {
    return `${readingMinutes(book)} 分钟`;
  }

  function icon(name, extraClass) {
    return `<svg width="16" height="16" class="${extraClass || ''}"><use href="#i-${name}"/></svg>`;
  }

  function setIcon(element, name) {
    if (!element) return;
    const use = element.tagName && element.tagName.toLowerCase() === 'use'
      ? element
      : element.querySelector('use');
    if (use) use.setAttribute('href', `#i-${name}`);
  }

  function hexToRGBA(hex, alpha) {
    const value = hex.replace('#', '');
    const r = parseInt(value.slice(0, 2), 16);
    const g = parseInt(value.slice(2, 4), 16);
    const b = parseInt(value.slice(4, 6), 16);
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  }

  function formatTime(timestamp) {
    try {
      return new Intl.DateTimeFormat('zh-CN', {
        month: 'numeric',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      }).format(new Date(timestamp));
    } catch (error) {
      return '';
    }
  }

  function toast(message) {
    dom.toastText.textContent = message;
    dom.toast.classList.add('show');
    clearTimeout(state.toastTimer);
    state.toastTimer = setTimeout(() => dom.toast.classList.remove('show'), 1900);
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  function normalizeBook(raw) {
    return {
      id: raw.id || uid(),
      title: raw.title || '未命名朗读',
      author: raw.author || '',
      content: raw.content || '',
      seed: Number.isInteger(raw.seed) ? raw.seed : Math.floor(Math.random() * 5),
      createdAt: raw.createdAt || Date.now(),
      lastOpenedAt: raw.lastOpenedAt || raw.createdAt || Date.now(),
      lastSentenceIndex: Number.isInteger(raw.lastSentenceIndex) ? raw.lastSentenceIndex : 0,
      progress: typeof raw.progress === 'number' ? clamp(raw.progress, 0, 1) : 0,
      bookmarks: Array.isArray(raw.bookmarks)
        ? raw.bookmarks.map((mark) => ({
            id: mark.id || uid(),
            sentenceIndex: mark.sentenceIndex || 0,
            charOffset: mark.charOffset || 0,
            snippet: mark.snippet || '',
            note: mark.note || '',
            createdAt: mark.createdAt || Date.now()
          }))
        : []
    };
  }

  function loadState() {
    let saved = null;
    try {
      const raw = localStorage.getItem(STORE_KEY);
      if (raw) saved = JSON.parse(raw);
    } catch (error) {
      saved = null;
    }

    if (saved && Array.isArray(saved.books)) {
      state.books = saved.books.map(normalizeBook);
    } else {
      state.books = samples.map((sample, index) => normalizeBook({
        ...sample,
        createdAt: Date.now() - index * 1000,
        lastOpenedAt: Date.now() - index * 1000
      }));
    }

    if (saved && saved.settings) {
      const settings = saved.settings;
      if (settings.emotionMode && EMOTIONS[settings.emotionMode]) {
        state.emotionMode = settings.emotionMode;
      }
      if (typeof settings.speed === 'number') {
        state.speed = clamp(settings.speed, 0.7, 1.4);
      }
      if (typeof settings.voiceURI === 'string') {
        state.voiceURI = settings.voiceURI;
      }
      if (typeof settings.autoScroll === 'boolean') {
        state.autoScroll = settings.autoScroll;
      }
    }
  }

  function persist() {
    try {
      localStorage.setItem(STORE_KEY, JSON.stringify({
        books: state.books,
        settings: {
          emotionMode: state.emotionMode,
          speed: state.speed,
          voiceURI: state.voiceURI,
          autoScroll: state.autoScroll
        }
      }));
    } catch (error) {
      // 隐私模式下 localStorage 可能不可写，演示仍然可以继续。
    }
  }

  function saveSoon() {
    clearTimeout(state.saveTimer);
    state.saveTimer = setTimeout(persist, 350);
  }

  function currentBook() {
    return state.books.find((book) => book.id === state.currentBookId) || null;
  }

  function bookById(id) {
    return state.books.find((book) => book.id === id) || null;
  }

  // ---------------------------------------------------------------------------
  // Library
  // ---------------------------------------------------------------------------

  function greetingText() {
    const hour = new Date().getHours();
    if (hour >= 5 && hour < 11) return '早上好';
    if (hour >= 11 && hour < 14) return '中午好';
    if (hour >= 14 && hour < 18) return '下午好';
    return '晚上好';
  }

  function dateText() {
    try {
      return new Intl.DateTimeFormat('zh-CN', {
        month: 'long',
        day: 'numeric',
        weekday: 'long'
      }).format(new Date());
    } catch (error) {
      return '';
    }
  }

  function waveMarkup() {
    const heights = [5, 11, 7, 15, 9, 13, 6];
    return heights.map((height) => `<i style="height:${height}px"></i>`).join('');
  }

  function renderLibrary() {
    dom.greeting.textContent = greetingText();
    dom.today.textContent = dateText();
    dom.bookCount.textContent = String(state.books.length);
    renderContinue();
    renderGrid();
  }

  function renderContinue() {
    if (!state.books.length) {
      dom.continueHost.innerHTML = '';
      return;
    }
    const book = [...state.books].sort((a, b) => b.lastOpenedAt - a.lastOpenedAt)[0];
    const progress = clamp(book.progress || 0, 0, 1);
    const label = progress > 0.001 ? '继续收听' : '开始收听';

    dom.continueHost.innerHTML = `
      <button class="continue-card" data-open-book="${escapeHTML(book.id)}">
        <div class="mini-cover c${book.seed % 5}">
          <span class="mi">${escapeHTML(firstCharacter(book.title))}</span>
          <span class="mt">${escapeHTML(book.title)}</span>
        </div>
        <div class="continue-body">
          <div class="continue-top">
            <span class="chip">${label}</span>
            <span style="font-size:10px;color:var(--ink-faint)">${minutesLabel(book)}</span>
          </div>
          <div class="continue-title">${escapeHTML(book.title)}</div>
          <div class="continue-author">${escapeHTML(book.author || '未署名')}</div>
          <div class="progress-line"><i style="width:${(progress * 100).toFixed(1)}%"></i></div>
        </div>
        <span class="continue-play">${icon('play')}</span>
      </button>
    `;
  }

  function renderGrid() {
    if (!state.books.length) {
      dom.bookGrid.innerHTML = `
        <div class="empty" style="grid-column:1/-1">
          <div class="empty-icon">${icon('book')}</div>
          <h4>书架还空着</h4>
          <p>点右上角的加号，粘贴一段文字开始朗读。</p>
        </div>
      `;
      return;
    }

    dom.bookGrid.innerHTML = state.books.map((book) => {
      const progress = clamp(book.progress || 0, 0, 1);
      return `
        <button class="book-card" data-open-book="${escapeHTML(book.id)}">
          <div class="cover c${book.seed % 5}">
            <span class="initial">${escapeHTML(firstCharacter(book.title))}</span>
            <div class="cover-bottom">
              <div class="wave">${waveMarkup()}</div>
              <div class="cover-title">${escapeHTML(book.title)}</div>
            </div>
          </div>
          <div class="book-meta">
            <div class="book-title">${escapeHTML(book.title)}</div>
            <div class="book-sub">
              <span>${escapeHTML(book.author || '未署名')}</span>
              <span class="dot"></span>
              <span>${minutesLabel(book)}</span>
            </div>
            <div class="progress-line"><i style="width:${(progress * 100).toFixed(1)}%"></i></div>
          </div>
        </button>
      `;
    }).join('');
  }

  // ---------------------------------------------------------------------------
  // Reader rendering
  // ---------------------------------------------------------------------------

  function renderReader() {
    const book = currentBook();
    if (!book) return;

    dom.readerTitle.textContent = book.title;
    dom.readerMeta.textContent = `${book.author || '未署名'} · ${state.seg.sentences.length} 句`;

    if (!state.seg.sentences.length) {
      dom.readerText.textContent = '这篇文章还没有可朗读的内容。';
      dom.snippet.textContent = '轻点正文中的任意一句，从这里开始听。';
      updateChrome();
      return;
    }

    const pieces = [];
    let cursor = 0;
    for (const sentence of state.seg.sentences) {
      if (sentence.start > cursor) {
        pieces.push(escapeHTML(book.content.slice(cursor, sentence.start)));
      }
      const classes = ['sentence'];
      if (sentence.id === state.sentenceIndex) classes.push('current');
      if (isBookmarked(sentence.id)) classes.push('bookmarked');
      pieces.push(
        `<span class="${classes.join(' ')}" data-sentence="${sentence.id}">${escapeHTML(book.content.slice(sentence.start, sentence.end))}</span>`
      );
      cursor = sentence.end;
    }
    if (cursor < book.content.length) {
      pieces.push(escapeHTML(book.content.slice(cursor)));
    }
    dom.readerText.innerHTML = pieces.join('');
    updateChrome();
  }

  function updateHighlight() {
    dom.readerText.querySelectorAll('.sentence').forEach((element) => {
      const index = Number(element.dataset.sentence);
      element.classList.toggle('current', index === state.sentenceIndex);
      element.classList.toggle('bookmarked', isBookmarked(index));
    });
  }

  function currentSentence() {
    return state.seg.sentences[state.sentenceIndex] || null;
  }

  function emotionForSentence(index) {
    const sentence = state.seg.sentences[index];
    if (!sentence) return EMOTIONS.calm;
    return EMOTIONS[resolveEmotion(state.emotionMode, sentence.text)] || EMOTIONS.calm;
  }

  function updateChrome() {
    const book = currentBook();
    if (!book) return;
    const sentence = currentSentence();
    const total = Math.max(1, state.seg.sentences.length);
    const progress = clamp((state.sentenceIndex + 1) / total, 0, 1);

    dom.readerProgress.style.width = `${(progress * 100).toFixed(2)}%`;
    dom.playerProgress.style.width = `${(progress * 100).toFixed(2)}%`;
    dom.playerCount.textContent = `第 ${Math.min(state.sentenceIndex + 1, total)} / ${total} 句`;
    dom.snippet.textContent = sentence ? sentence.text : '轻点正文中的任意一句，从这里开始听。';
    dom.readerMeta.textContent = `${book.author || '未署名'} · ${state.seg.sentences.length} 句`;

    const emotion = emotionForSentence(state.sentenceIndex);
    dom.emotionChip.textContent = emotion.label;
    dom.emotionChip.style.color = emotion.tint;
    dom.emotionChip.style.background = hexToRGBA(emotion.tint, 0.10);
    dom.emotionChip.style.borderColor = hexToRGBA(emotion.tint, 0.22);

    const mode = EMOTIONS[state.emotionMode] || EMOTIONS.auto;
    dom.emotionLabel.textContent = mode.label;
    setIcon(dom.emotionIcon, mode.icon);

    dom.speedBtn.textContent = `${state.speed.toFixed(1)}×`;
    updateSpeedLabels();
    updateBookmarkUI();
  }

  function updateSpeedLabels() {
    const label = `${state.speed.toFixed(1)}×`;
    dom.speedValue.textContent = label;
    dom.speedValue2.textContent = label;
    dom.speedRange.value = String(state.speed);
    dom.speedBtn.textContent = label;
  }

  function isBookmarked(sentenceIndex) {
    const book = currentBook();
    if (!book) return false;
    return book.bookmarks.some((mark) => mark.sentenceIndex === sentenceIndex);
  }

  function updateBookmarkUI() {
    const active = isBookmarked(state.sentenceIndex);
    [dom.readerBookmarkBtn, dom.playerBookmarkBtn].forEach((button) => {
      button.classList.toggle('active', active);
      button.classList.toggle('bookmarked', active);
      button.setAttribute('aria-label', active ? '移除书签' : '添加书签');
    });
    setIcon(dom.readerBookmarkIcon, active ? 'bookmark-fill' : 'bookmark');
    setIcon(dom.playerBookmarkIcon, active ? 'bookmark-fill' : 'bookmark');
  }

  function updatePlaybackUI() {
    let symbol = 'play';
    if (state.playing) symbol = 'pause';
    else if (state.finished) symbol = 'replay';
    setIcon(dom.playIcon, symbol);
    dom.playBtn.setAttribute('aria-label', state.playing ? '暂停' : '播放');
    dom.playIcon.classList.toggle('play-nudge', symbol === 'play');
  }

  function scrollToCurrent(smooth, force) {
    if (!state.autoScroll && !force) return;
    const element = dom.readerText.querySelector(`.sentence[data-sentence="${state.sentenceIndex}"]`);
    if (!element) return;
    const box = dom.readerScroll.getBoundingClientRect();
    const rect = element.getBoundingClientRect();
    const top = dom.readerScroll.scrollTop + rect.top - box.top - box.height * 0.30;
    dom.readerScroll.scrollTo({
      top: Math.max(0, top),
      behavior: smooth ? 'smooth' : 'auto'
    });
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

  function supportsSpeech() {
    return 'speechSynthesis' in window && 'SpeechSynthesisUtterance' in window;
  }

  function stopPlayback() {
    state.runId += 1;
    state.playing = false;
    state.paused = false;
    state.resumeNeedsSpeak = false;
    clearTimeout(state.advanceTimer);
    state.advanceTimer = null;
    if (supportsSpeech()) {
      window.speechSynthesis.cancel();
    }
    updatePlaybackUI();
  }

  function startPlayback() {
    if (!supportsSpeech()) {
      toast('这个浏览器不支持语音合成，请用 Safari、Chrome 或 Edge 打开');
      return;
    }
    if (!state.seg.chunks.length) {
      toast('这篇文章还没有可朗读的内容');
      return;
    }
    if (state.playing) return;
    if (state.paused) {
      resumePlayback();
      return;
    }

    if (state.finished || state.chunkIndex >= state.seg.chunks.length) {
      state.finished = false;
      focusChunk(0, { scroll: true, save: true });
    }

    state.runId += 1;
    state.playing = true;
    state.paused = false;
    state.finished = false;
    speakChunk(state.chunkIndex, state.runId);
  }

  function speakChunk(index, runId) {
    if (runId !== state.runId) return;
    const chunks = state.seg.chunks;
    if (index >= chunks.length) {
      finishPlayback(runId);
      return;
    }

    const chunk = chunks[index];
    state.chunkIndex = index;
    if (state.sentenceIndex !== chunk.sentenceIndex) {
      state.sentenceIndex = chunk.sentenceIndex;
      updateHighlight();
      updateChrome();
      saveProgress();
      if (state.autoScroll) scrollToCurrent(true);
    }

    const emotion = emotionForSentence(chunk.sentenceIndex);
    const utterance = new SpeechSynthesisUtterance(chunk.text);
    const voice = pickVoice();
    if (voice) utterance.voice = voice;
    utterance.lang = voice ? voice.lang : 'zh-CN';
    utterance.rate = clamp(0.95 * state.speed * emotion.rate, 0.5, 1.8);
    utterance.pitch = clamp(emotion.pitch, 0.5, 2);
    utterance.volume = clamp(emotion.volume, 0.1, 1);

    utterance.onstart = () => {
      if (runId !== state.runId) return;
      state.playing = true;
      state.paused = false;
      updatePlaybackUI();
    };

    utterance.onend = () => {
      if (runId !== state.runId) return;
      if (!state.playing) return;
      const next = index + 1;
      state.advanceTimer = setTimeout(() => {
        if (runId !== state.runId) return;
        state.advanceTimer = null;
        if (next < chunks.length) {
          speakChunk(next, runId);
        } else {
          finishPlayback(runId);
        }
      }, Math.max(0, emotion.delay));
    };

    utterance.onerror = (event) => {
      if (runId !== state.runId) return;
      const reason = event.error || 'unknown';
      if (reason === 'interrupted' || reason === 'canceled') return;
      state.playing = false;
      state.paused = false;
      updatePlaybackUI();
      toast(`语音合成失败：${reason}`);
    };

    updatePlaybackUI();
    window.speechSynthesis.speak(utterance);
  }

  function pausePlayback() {
    if (!state.playing && !state.paused) return;
    if (state.paused) {
      resumePlayback();
      return;
    }

    if (state.advanceTimer) {
      clearTimeout(state.advanceTimer);
      state.advanceTimer = null;
      if (state.chunkIndex + 1 < state.seg.chunks.length) {
        state.chunkIndex += 1;
        const sentenceIndex = state.seg.chunks[state.chunkIndex].sentenceIndex;
        if (sentenceIndex !== state.sentenceIndex) {
          state.sentenceIndex = sentenceIndex;
          updateHighlight();
          updateChrome();
          saveProgress();
        }
      }
      state.playing = false;
      state.paused = true;
      state.resumeNeedsSpeak = true;
      updatePlaybackUI();
      return;
    }

    if (supportsSpeech() && window.speechSynthesis.speaking) {
      window.speechSynthesis.pause();
      state.playing = false;
      state.paused = true;
      state.resumeNeedsSpeak = false;
      updatePlaybackUI();
      saveProgress();
      return;
    }

    state.playing = false;
    state.paused = true;
    state.resumeNeedsSpeak = true;
    updatePlaybackUI();
  }

  function resumePlayback() {
    if (!state.paused) return;
    if (state.resumeNeedsSpeak) {
      state.resumeNeedsSpeak = false;
      state.playing = true;
      state.paused = false;
      state.runId += 1;
      speakChunk(state.chunkIndex, state.runId);
      updatePlaybackUI();
      return;
    }

    if (supportsSpeech() && window.speechSynthesis.paused) {
      window.speechSynthesis.resume();
      state.playing = true;
      state.paused = false;
      updatePlaybackUI();
      return;
    }

    if (supportsSpeech()) window.speechSynthesis.cancel();
    state.runId += 1;
    state.playing = true;
    state.paused = false;
    speakChunk(state.chunkIndex, state.runId);
    updatePlaybackUI();
  }

  function togglePlayback() {
    if (state.playing) {
      pausePlayback();
    } else if (state.paused) {
      resumePlayback();
    } else {
      startPlayback();
    }
  }

  function finishPlayback(runId) {
    if (runId !== state.runId) return;
    state.playing = false;
    state.paused = false;
    state.finished = true;
    state.resumeNeedsSpeak = false;
    const book = currentBook();
    if (book) {
      book.progress = 1;
      book.lastSentenceIndex = Math.max(0, state.seg.sentences.length - 1);
      book.lastOpenedAt = Date.now();
      persist();
      renderLibrary();
    }
    updatePlaybackUI();
    toast('读完了。喜欢的话，留一枚书签吧。');
  }

  function focusChunk(index, options) {
    const opts = options || {};
    if (!state.seg.chunks[index]) return;
    state.chunkIndex = index;
    const sentenceIndex = state.seg.chunks[index].sentenceIndex;
    if (sentenceIndex !== state.sentenceIndex) {
      state.sentenceIndex = sentenceIndex;
      updateHighlight();
      updateChrome();
      if (opts.save !== false) saveProgress();
      if (state.autoScroll) scrollToCurrent(true);
    }
  }

  function focusSentence(index, options) {
    const opts = options || {};
    const sentence = state.seg.sentences[index];
    if (!sentence) return;
    state.sentenceIndex = index;
    state.chunkIndex = Math.max(0, chunkIndexForSentence(state.seg, index));
    updateHighlight();
    updateChrome();
    if (opts.save !== false) saveProgress();
    if (state.autoScroll) scrollToCurrent(true);
  }

  function seekToSentence(index, autoplay) {
    if (!state.seg.sentences[index]) return;
    stopPlayback();
    state.finished = false;
    focusSentence(index, { save: true });
    updatePlaybackUI();
    if (autoplay !== false) startPlayback();
  }

  function nextSentence() {
    const next = state.seg.sentences[state.sentenceIndex + 1];
    if (!next) {
      stopPlayback();
      state.finished = true;
      updatePlaybackUI();
      return;
    }
    seekToSentence(next.id, true);
  }

  function previousSentence() {
    const current = state.seg.sentences[state.sentenceIndex];
    if (!current) return;
    const firstChunk = Math.max(0, chunkIndexForSentence(state.seg, current.id));
    if (state.chunkIndex > firstChunk) {
      seekToSentence(current.id, true);
      return;
    }
    const previous = state.seg.sentences[state.sentenceIndex - 1];
    if (previous) {
      seekToSentence(previous.id, true);
    } else {
      seekToSentence(0, true);
    }
  }

  function saveProgress() {
    const book = currentBook();
    if (!book || !state.seg.sentences.length) return;
    book.lastSentenceIndex = state.sentenceIndex;
    book.progress = clamp((state.sentenceIndex + 1) / state.seg.sentences.length, 0, 1);
    book.lastOpenedAt = Date.now();
    saveSoon();
  }

  // ---------------------------------------------------------------------------
  // Bookmarks
  // ---------------------------------------------------------------------------

  function toggleBookmark() {
    const book = currentBook();
    const sentence = currentSentence();
    if (!book || !sentence) return;

    const existing = book.bookmarks.findIndex((mark) => mark.sentenceIndex === sentence.id);
    if (existing >= 0) {
      book.bookmarks.splice(existing, 1);
      toast('已移除书签');
    } else {
      book.bookmarks.push({
        id: uid(),
        sentenceIndex: sentence.id,
        charOffset: sentence.start,
        snippet: sentence.text,
        note: '',
        createdAt: Date.now()
      });
      book.bookmarks.sort((a, b) => a.sentenceIndex - b.sentenceIndex);
      toast('已收藏这一句');
    }

    persist();
    updateHighlight();
    updateBookmarkUI();
    if (state.sheet === 'bookmarks') renderBookmarks();
  }

  function renderBookmarks() {
    const book = currentBook();
    if (!book) return;
    dom.bookmarksSub.textContent = `${book.bookmarks.length} 枚`;

    const sentence = currentSentence();
    const currentSaved = sentence ? book.bookmarks.some((mark) => mark.sentenceIndex === sentence.id) : false;
    const addMarkup = sentence ? `
      <div class="sheet-card">
        <div class="bm-current-label">现在听到</div>
        <div class="bm-current-text">${escapeHTML(sentence.text)}</div>
        ${currentSaved
          ? `<div class="bm-current-btn" style="background:rgba(184,92,62,.10);color:var(--accent)">${icon('bookmark-fill')} 这一句已经收藏</div>`
          : `<button class="bm-current-btn" data-add-current>${icon('bookmark')} 把这一句加入书签</button>`}
      </div>
    ` : '';

    if (!book.bookmarks.length) {
      dom.bookmarksBody.innerHTML = `
        ${addMarkup}
        <div class="empty">
          <div class="empty-icon">${icon('bookmark')}</div>
          <h4>还没有书签</h4>
          <p>听到喜欢的一句，点一下播放器右上角的书签。</p>
        </div>
      `;
      return;
    }

    const cards = book.bookmarks.map((mark) => `
      <div class="sheet-card bm-card">
        <div class="bm-top">
          <span class="bm-index">第 ${mark.sentenceIndex + 1} 句</span>
          <span>·</span>
          <span class="bm-time">${escapeHTML(formatTime(mark.createdAt))}</span>
          <span class="bm-actions">
            <button class="bm-icon" data-note="${escapeHTML(mark.id)}" aria-label="编辑备注">${icon('bubble')}</button>
            <button class="bm-icon" data-delete="${escapeHTML(mark.id)}" aria-label="删除书签">${icon('trash')}</button>
          </span>
        </div>
        <div class="bm-snippet">${escapeHTML(mark.snippet)}</div>
        ${mark.note ? `<div class="bm-note">${escapeHTML(mark.note)}</div>` : ''}
        <div class="bm-foot">
          <button class="bm-jump" data-jump="${mark.sentenceIndex}">${icon('play')} 从这里听</button>
        </div>
      </div>
    `).join('');

    dom.bookmarksBody.innerHTML = `${addMarkup}<div class="bm-list-head"><span>全部书签</span><span>按正文顺序</span></div>${cards}`;
  }

  function toggleBookmarkFromSheet() {
    toggleBookmark();
    renderBookmarks();
  }

  function editBookmarkNote(id) {
    const book = currentBook();
    if (!book) return;
    const mark = book.bookmarks.find((item) => item.id === id);
    if (!mark) return;
    const next = window.prompt('给这枚书签留一句话', mark.note || '');
    if (next === null) return;
    mark.note = next.trim();
    persist();
    renderBookmarks();
    toast('备注已保存');
  }

  function deleteBookmark(id) {
    const book = currentBook();
    if (!book) return;
    book.bookmarks = book.bookmarks.filter((mark) => mark.id !== id);
    persist();
    updateHighlight();
    updateBookmarkUI();
    renderBookmarks();
    toast('书签已删除');
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  function chineseVoices() {
    if (!supportsSpeech()) return [];
    const voices = window.speechSynthesis.getVoices() || [];
    return voices
      .filter((voice) => /^zh/i.test(voice.lang))
      .sort((a, b) => {
        const aCN = a.lang.replace('_', '-').toLowerCase().startsWith('zh-cn') ? 0 : 1;
        const bCN = b.lang.replace('_', '-').toLowerCase().startsWith('zh-cn') ? 0 : 1;
        if (aCN !== bCN) return aCN - bCN;
        return a.name.localeCompare(b.name);
      });
  }

  function pickVoice() {
    const voices = chineseVoices();
    if (!voices.length) return null;
    if (state.voiceURI) {
      const selected = voices.find((voice) => voice.voiceURI === state.voiceURI);
      if (selected) return selected;
    }
    const preferredName = /Xiaoxiao|Xiaoyi|Yunxi|Yunjian|Huihui|Tingting|Meijia|Natural/i;
    return voices.find((voice) => preferredName.test(voice.name))
      || voices.find((voice) => voice.lang.replace('_', '-').toLowerCase().startsWith('zh-cn'))
      || voices[0];
  }

  function renderSettings() {
    const voices = chineseVoices();
    const autoSelected = !state.voiceURI || !voices.some((voice) => voice.voiceURI === state.voiceURI);
    const rows = [
      `<button class="voice-row ${autoSelected ? 'sel' : ''}" data-voice="">
        <div>
          <div class="voice-name ${autoSelected ? 'sel' : ''}">自动选择最佳</div>
          <div class="voice-detail">优先使用设备上更自然的中文声音</div>
        </div>
        <span class="voice-check"></span>
      </button>`
    ];

    for (const voice of voices) {
      const selected = state.voiceURI === voice.voiceURI;
      const lang = voice.lang.replace('_', '-');
      rows.push(`
        <button class="voice-row ${selected ? 'sel' : ''}" data-voice="${escapeHTML(voice.voiceURI)}">
          <div>
            <div class="voice-name ${selected ? 'sel' : ''}">
              ${escapeHTML(voice.name)}
              ${voice.localService ? '' : '<span class="badge">在线</span>'}
            </div>
            <div class="voice-detail">${escapeHTML(lang)}${voice.default ? ' · 系统默认' : ''}</div>
          </div>
          <span class="voice-check"></span>
        </button>
      `);
    }

    if (!voices.length) {
      rows.push(`
        <div class="voice-row">
          <div>
            <div class="voice-name">暂时没有中文声音</div>
            <div class="voice-detail">换用 Safari / Edge，或在系统里安装中文语音后再试</div>
          </div>
        </div>
      `);
    }

    dom.voiceList.innerHTML = rows.join('');
    updateSpeedLabels();

    dom.emotionGrid.innerHTML = Object.keys(EMOTIONS).map((key) => {
      const emotion = EMOTIONS[key];
      const selected = state.emotionMode === key;
      return `
        <button class="emotion-option ${selected ? 'sel' : ''}" data-emotion="${key}" style="${selected ? `border-color:${hexToRGBA(emotion.tint, 0.55)};background:${hexToRGBA(emotion.tint, 0.12)};color:${emotion.tint}` : ''}">
          ${icon(emotion.icon)}
          <span>${emotion.label}</span>
        </button>
      `;
    }).join('');

    dom.emotionDesc.textContent = state.emotionMode === 'auto'
      ? EMOTIONS.auto.desc
      : `整篇统一使用「${EMOTIONS[state.emotionMode].label}」语气。适合诗歌、独白，或你想让整篇文章保持同一种情绪的时候。`;

    dom.autoScrollSwitch.classList.toggle('on', state.autoScroll);
    dom.autoScrollSwitch.setAttribute('aria-pressed', String(state.autoScroll));
  }

  function selectEmotion(key) {
    if (!EMOTIONS[key]) return;
    state.emotionMode = key;
    persist();
    renderSettings();
    updateChrome();
  }

  // ---------------------------------------------------------------------------
  // Reader lifecycle
  // ---------------------------------------------------------------------------

  function openBook(id, sentenceIndex, autoplay) {
    const book = bookById(id);
    if (!book) return;

    stopPlayback();
    state.currentBookId = id;
    state.seg = segment(book.content);
    state.finished = false;

    const maxIndex = Math.max(0, state.seg.sentences.length - 1);
    const requested = Number.isInteger(sentenceIndex) ? sentenceIndex : (book.lastSentenceIndex || 0);
    const target = clamp(requested, 0, maxIndex);
    state.sentenceIndex = target;
    state.chunkIndex = Math.max(0, chunkIndexForSentence(state.seg, target));

    book.lastOpenedAt = Date.now();
    renderReader();
    dom.libraryScreen.hidden = true;
    dom.readerScreen.hidden = false;
    updatePlaybackUI();
    saveProgress();
    persist();

    requestAnimationFrame(() => {
      scrollToCurrent(false, true);
      if (autoplay) startPlayback();
    });
  }

  function closeReader() {
    stopPlayback();
    saveProgress();
    persist();
    closeSheet();
    dom.readerScreen.hidden = true;
    dom.libraryScreen.hidden = false;
    renderLibrary();
  }

  function openSheet(name) {
    const element = document.getElementById(`${name}Sheet`);
    if (!element) return;

    closeSheet(true);
    state.sheet = name;
    if (name === 'bookmarks') renderBookmarks();
    if (name === 'settings') renderSettings();
    if (name === 'new') {
      dom.newTitle.value = '';
      dom.newAuthor.value = '';
      dom.newText.value = '';
    }

    dom.sheetBackdrop.classList.add('open');
    element.classList.add('open');
    element.setAttribute('aria-hidden', 'false');
  }

  function closeSheet(immediate) {
    $$('.sheet.open').forEach((sheet) => {
      sheet.classList.remove('open');
      sheet.setAttribute('aria-hidden', 'true');
    });
    dom.sheetBackdrop.classList.remove('open');
    state.sheet = null;
    if (!immediate) {
      // 保持状态简单：关闭动作本身不触发额外逻辑。
    }
  }

  function createBook() {
    const content = dom.newText.value.trim();
    if (!content) {
      toast('先粘贴或写一点文字吧');
      dom.newText.focus();
      return;
    }
    const fallbackTitle = content.replace(/\s+/g, ' ').slice(0, 18);
    const book = normalizeBook({
      id: uid(),
      title: dom.newTitle.value.trim() || fallbackTitle,
      author: dom.newAuthor.value.trim(),
      content,
      seed: Math.floor(Math.random() * 5),
      createdAt: Date.now(),
      lastOpenedAt: Date.now(),
      lastSentenceIndex: 0,
      progress: 0,
      bookmarks: []
    });

    state.books.unshift(book);
    persist();
    renderLibrary();
    closeSheet();
    openBook(book.id, 0, false);
    toast('已加入书架');
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  function wireEvents() {
    document.addEventListener('click', (event) => {
      const openButton = event.target.closest('[data-open-book]');
      if (openButton) {
        openBook(openButton.dataset.openBook);
        return;
      }

      const closeButton = event.target.closest('[data-close-sheet]');
      if (closeButton) {
        closeSheet();
      }
    });

    dom.backBtn.addEventListener('click', closeReader);
    dom.playBtn.addEventListener('click', togglePlayback);
    dom.prevBtn.addEventListener('click', previousSentence);
    dom.nextBtn.addEventListener('click', nextSentence);
    dom.readerBookmarkBtn.addEventListener('click', toggleBookmark);
    dom.playerBookmarkBtn.addEventListener('click', toggleBookmark);
    dom.readerMenuBtn.addEventListener('click', () => openSheet('menu'));
    dom.settingsBtn.addEventListener('click', () => openSheet('settings'));
    dom.emotionBtn.addEventListener('click', () => openSheet('settings'));

    dom.speedBtn.addEventListener('click', () => {
      const index = SPEEDS.findIndex((value) => Math.abs(value - state.speed) < 0.001);
      const next = SPEEDS[(index + 1) % SPEEDS.length];
      state.speed = next;
      updateSpeedLabels();
      persist();
      toast(`语速 ${next.toFixed(1)}×`);
    });

    dom.readerText.addEventListener('click', (event) => {
      const sentence = event.target.closest('.sentence');
      if (!sentence) return;
      seekToSentence(Number(sentence.dataset.sentence), true);
    });

    dom.sheetBackdrop.addEventListener('click', () => closeSheet());

    dom.bookmarksBody.addEventListener('click', (event) => {
      if (event.target.closest('[data-add-current]')) {
        toggleBookmarkFromSheet();
        return;
      }
      const jump = event.target.closest('[data-jump]');
      if (jump) {
        closeSheet();
        seekToSentence(Number(jump.dataset.jump), true);
        return;
      }
      const remove = event.target.closest('[data-delete]');
      if (remove) {
        deleteBookmark(remove.dataset.delete);
        return;
      }
      const note = event.target.closest('[data-note]');
      if (note) {
        editBookmarkNote(note.dataset.note);
      }
    });

    dom.voiceList.addEventListener('click', (event) => {
      const row = event.target.closest('[data-voice]');
      if (!row) return;
      state.voiceURI = row.dataset.voice || '';
      persist();
      renderSettings();
      toast(state.voiceURI ? '声音已切换，下一句生效' : '将自动选择最佳声音');
    });

    dom.speedRange.addEventListener('input', () => {
      state.speed = clamp(Number(dom.speedRange.value), 0.7, 1.4);
      updateSpeedLabels();
    });
    dom.speedRange.addEventListener('change', persist);

    dom.emotionGrid.addEventListener('click', (event) => {
      const button = event.target.closest('[data-emotion]');
      if (!button) return;
      selectEmotion(button.dataset.emotion);
    });

    dom.autoScrollSwitch.addEventListener('click', () => {
      state.autoScroll = !state.autoScroll;
      dom.autoScrollSwitch.classList.toggle('on', state.autoScroll);
      dom.autoScrollSwitch.setAttribute('aria-pressed', String(state.autoScroll));
      persist();
      if (state.autoScroll) scrollToCurrent(true);
    });

    $('#newBookBtn').addEventListener('click', () => openSheet('new'));
    dom.createBookBtn.addEventListener('click', createBook);

    $('#menuBookmarks').addEventListener('click', () => {
      closeSheet();
      setTimeout(() => openSheet('bookmarks'), 180);
    });
    $('#menuSettings').addEventListener('click', () => {
      closeSheet();
      setTimeout(() => openSheet('settings'), 180);
    });
    $('#menuRepeat').addEventListener('click', () => {
      closeSheet();
      seekToSentence(state.sentenceIndex, true);
    });
    $('#menuRestart').addEventListener('click', () => {
      closeSheet();
      stopPlayback();
      state.finished = false;
      focusSentence(0, { save: true });
      updatePlaybackUI();
      toast('已回到开头');
    });

    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape') closeSheet();
      if (event.code === 'Space' && !dom.readerScreen.hidden && !event.target.closest('input, textarea')) {
        event.preventDefault();
        togglePlayback();
      }
    });

    window.addEventListener('pagehide', persist);

    if (supportsSpeech()) {
      const refreshVoices = () => {
        if (state.sheet === 'settings') renderSettings();
      };
      if (typeof window.speechSynthesis.addEventListener === 'function') {
        window.speechSynthesis.addEventListener('voiceschanged', refreshVoices);
      } else {
        window.speechSynthesis.onvoiceschanged = refreshVoices;
      }
      // 某些浏览器需要先取一次 voices 才会触发加载。
      window.speechSynthesis.getVoices();
    }
  }

  // ---------------------------------------------------------------------------
  // Demo / screenshot helpers
  // ---------------------------------------------------------------------------

  function seedDemoState() {
    const book = bookById('sample-0') || state.books[0];
    if (!book) return;
    const seg = segment(book.content);
    if (!book.bookmarks.length) {
      [1, 4, 7].forEach((index, order) => {
        const sentence = seg.sentences[index];
        if (!sentence) return;
        book.bookmarks.push({
          id: uid(),
          sentenceIndex: index,
          charOffset: sentence.start,
          snippet: sentence.text,
          note: order === 1 ? '这句话让我想起很多年前的深夜。' : '',
          createdAt: Date.now() - (3 - order) * 86400000
        });
      });
    }
    book.lastSentenceIndex = 3;
    book.progress = 0.42;
    book.lastOpenedAt = Date.now();
    state.books.forEach((item) => {
      if (item.id !== book.id) item.lastOpenedAt = Math.min(item.lastOpenedAt, Date.now() - 86400000);
    });
    persist();
    renderLibrary();
  }

  function applyQuery() {
    const params = new URLSearchParams(window.location.search);
    if (params.get('demo') === '1') seedDemoState();

    if (params.get('view') === 'reader') {
      const book = bookById(params.get('book')) || state.books[0];
      if (!book) return;
      const sentence = Number.parseInt(params.get('sentence') || '0', 10) || 0;
      openBook(book.id, sentence, false);
      const sheet = params.get('sheet');
      if (sheet) {
        setTimeout(() => openSheet(sheet), 60);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Boot
  // ---------------------------------------------------------------------------

  loadState();
  wireEvents();
  renderLibrary();
  applyQuery();
})();
