/* 断句与情绪规则：浏览器演示与 Node 测试共用。 */
(function (global) {
  'use strict';

  const HARD = new Set(['。', '！', '？', '!', '?', '；', ';', '…']);
  const SOFT = new Set(['，', ',', '、', '：', ':']);
  const CLOSING = new Set(['”', '’', '」', '』', '）', '】', '》', '〉', '〕', '］', '｝', '"']);
  const WS = new Set([' ', '\t', '\n', '\r', '\u3000']);

  const MIN_CLAUSE = 14;
  const MAX_CHUNK = 64;
  const BACKTRACK = 24;

  const EMOTIONS = {
    auto: {
      label: '智能', icon: 'sparkles', tint: '#70806a',
      rate: 0.94, pitch: 1.0, volume: 0.95, delay: 160,
      desc: '根据标点、关键词和句子长短，为每一句单独选择语气。'
    },
    calm: {
      label: '平静', icon: 'waves', tint: '#6f8a8a',
      rate: 0.94, pitch: 1.0, volume: 0.95, delay: 160
    },
    warm: {
      label: '温柔', icon: 'heart', tint: '#c07a5a',
      rate: 0.90, pitch: 0.97, volume: 0.95, delay: 200
    },
    cheerful: {
      label: '轻快', icon: 'sun', tint: '#d3a24a',
      rate: 1.06, pitch: 1.10, volume: 1.0, delay: 100
    },
    sad: {
      label: '感伤', icon: 'rain', tint: '#6f7e9a',
      rate: 0.82, pitch: 0.90, volume: 0.88, delay: 300
    },
    serious: {
      label: '郑重', icon: 'book', tint: '#7a6a58',
      rate: 0.90, pitch: 0.94, volume: 1.0, delay: 220
    },
    excited: {
      label: '激动', icon: 'bolt', tint: '#b85c3e',
      rate: 1.12, pitch: 1.15, volume: 1.0, delay: 80
    },
    curious: {
      label: '好奇', icon: 'question', tint: '#7a8a5c',
      rate: 0.98, pitch: 1.06, volume: 0.95, delay: 140
    },
    whisper: {
      label: '低语', icon: 'moon', tint: '#8b7e94',
      rate: 0.76, pitch: 0.93, volume: 0.58, delay: 340
    }
  };

  function isDigit(ch) {
    return ch !== undefined && ch >= '0' && ch <= '9';
  }

  function speakable(value) {
    return /[\p{L}\p{N}]/u.test(value);
  }

  function segment(text) {
    const chars = Array.from(text);
    if (!chars.length) return { chunks: [], sentences: [] };

    const offsets = new Array(chars.length + 1).fill(0);
    for (let i = 0; i < chars.length; i += 1) {
      offsets[i + 1] = offsets[i] + chars[i].length;
    }

    const chunks = [];
    const sentences = [];
    let sentenceIndex = 0;
    let clauseStart = 0;
    let sentenceStart = null;
    let sentenceEnd = 0;

    function trimBounds(start, end) {
      let lower = start;
      let upper = end;
      while (lower < upper && WS.has(chars[lower])) lower += 1;
      while (upper > lower && WS.has(chars[upper - 1])) upper -= 1;
      if (lower >= upper) return null;
      return [lower, upper];
    }

    function appendClause(start, end) {
      const bounds = trimBounds(start, end);
      if (!bounds) return;
      const [lower, upper] = bounds;
      const value = chars.slice(lower, upper).join('');
      if (!speakable(value)) return;

      const isStart = sentenceStart === null;
      if (isStart) sentenceStart = lower;
      sentenceEnd = upper;

      chunks.push({
        id: chunks.length,
        text: value,
        start: offsets[lower],
        end: offsets[upper],
        sentenceIndex,
        isSentenceStart: isStart
      });
    }

    function finishSentence() {
      if (sentenceStart === null || sentenceEnd <= sentenceStart) return;
      const value = chars.slice(sentenceStart, sentenceEnd).join('');
      if (!value) return;
      sentences.push({
        id: sentenceIndex,
        text: value,
        start: offsets[sentenceStart],
        end: offsets[sentenceEnd]
      });
      sentenceIndex += 1;
      sentenceStart = null;
      sentenceEnd = 0;
    }

    function skipWhitespace(from) {
      let cursor = from;
      while (cursor < chars.length && WS.has(chars[cursor])) cursor += 1;
      return cursor;
    }

    function attributionEnd(index) {
      if (index <= 0 || index > chars.length) return null;
      if (!['”', '"', '』', '」'].includes(chars[index - 1])) return null;

      let start = index;
      while (start < chars.length && (chars[start] === ' ' || chars[start] === '\t' || chars[start] === '\u3000')) {
        start += 1;
      }
      if (start >= chars.length) return null;
      if (chars[start] === '\n' || chars[start] === '\r') return null;
      if (chars[start] === '“' || chars[start] === '"') return null;
      if (CLOSING.has(chars[start])) return null;

      let cursor = start;
      let length = 0;
      while (cursor < chars.length) {
        const char = chars[cursor];
        if (char === '\n' || char === '\r') return null;
        if (HARD.has(char)) {
          if (char !== '。' && char !== '；' && char !== ';') return null;
          let end = cursor + 1;
          while (end < chars.length && (HARD.has(chars[end]) || CLOSING.has(chars[end]))) {
            end += 1;
          }
          const candidate = chars.slice(start, end).join('');
          if (candidate.length > 6) return null;
          if (candidate.includes('“') || candidate.includes('"')) return null;
          return end;
        }
        length += 1;
        if (length > 7) return null;
        cursor += 1;
      }
      return null;
    }

    let cursor = 0;
    while (cursor < chars.length) {
      const char = chars[cursor];

      if (HARD.has(char)) {
        let end = cursor + 1;
        while (end < chars.length && (HARD.has(chars[end]) || CLOSING.has(chars[end]))) {
          end += 1;
        }
        while (end < chars.length && CLOSING.has(chars[end])) end += 1;
        appendClause(clauseStart, end);
        const mergedEnd = attributionEnd(end);
        if (mergedEnd !== null) {
          appendClause(end, mergedEnd);
          finishSentence();
          clauseStart = skipWhitespace(mergedEnd);
          cursor = clauseStart;
          continue;
        }
        finishSentence();
        clauseStart = skipWhitespace(end);
        cursor = clauseStart;
        continue;
      }

      if (char === '.') {
        const previous = cursor > 0 ? chars[cursor - 1] : undefined;
        const next = chars[cursor + 1];
        const isDecimal = isDigit(previous) && isDigit(next);
        const isRepeated = next === '.';
        const isEnd = next === undefined || WS.has(next) || next === '”' || next === '"';
        if (!isDecimal && (isRepeated || isEnd)) {
          let end = cursor + 1;
          while (end < chars.length && chars[end] === '.') end += 1;
          while (end < chars.length && CLOSING.has(chars[end])) end += 1;
          appendClause(clauseStart, end);
          finishSentence();
          clauseStart = skipWhitespace(end);
          cursor = clauseStart;
          continue;
        }
      }

      if (char === '\n' || char === '\r') {
        let end = cursor + 1;
        while (end < chars.length && (chars[end] === '\n' || chars[end] === '\r')) end += 1;
        appendClause(clauseStart, cursor);
        finishSentence();
        clauseStart = end;
        cursor = end;
        continue;
      }

      if (SOFT.has(char)) {
        const length = offsets[cursor + 1] - offsets[clauseStart];
        if (length >= MIN_CLAUSE) {
          appendClause(clauseStart, cursor + 1);
          clauseStart = cursor + 1;
        }
        cursor += 1;
        continue;
      }

      if (char === '—') {
        const length = offsets[cursor + 1] - offsets[clauseStart];
        if (length >= MIN_CLAUSE) {
          let end = cursor + 1;
          while (end < chars.length && chars[end] === '—') end += 1;
          appendClause(clauseStart, end);
          clauseStart = end;
          cursor = end;
          continue;
        }
      }

      if (offsets[cursor + 1] - offsets[clauseStart] >= MAX_CHUNK) {
        let cut = cursor;
        let back = cursor;
        while (back > clauseStart && offsets[cursor + 1] - offsets[back] < BACKTRACK) {
          if (chars[back] === ' ') {
            cut = back;
            break;
          }
          back -= 1;
        }
        if (cut > clauseStart) {
          appendClause(clauseStart, cut);
          clauseStart = cut;
          cursor = cut;
          continue;
        }
      }

      cursor += 1;
    }

    appendClause(clauseStart, chars.length);
    finishSentence();
    return { chunks, sentences };
  }

  function chunkIndexForSentence(seg, index) {
    return seg.chunks.findIndex((chunk) => chunk.sentenceIndex === index && chunk.isSentenceStart);
  }

  const SAD_WORDS = [
    '哭', '泪', '孤独', '离开', '告别', '错过', '遗憾', '想念', '沉默',
    '雨', '夜', '冷', '疼', '死', '失去', '回不去', '很久', '再见', '晚安'
  ];
  const HAPPY_WORDS = [
    '笑', '喜欢', '爱', '暖', '光', '花', '春天', '甜', '幸福', '开心',
    '温柔', '亮', '希望', '拥', '阳光', '热', '棒', '精彩', '厉害'
  ];
  const STRONG_WORDS = ['一定', '必须', '终于', '竟然', '再也', '永远', '绝不', '居然', '突然'];

  function hasAny(text, words) {
    return words.some((word) => text.includes(word));
  }

  function stableSum(text) {
    let sum = 0;
    for (const char of text) {
      sum += char.codePointAt(0);
    }
    return sum;
  }

  function resolveEmotion(base, text) {
    if (base !== 'auto') return base;

    const sentence = text.trim();
    if (!sentence) return 'calm';

    const hasSad = hasAny(sentence, SAD_WORDS);
    const hasHappy = hasAny(sentence, HAPPY_WORDS);
    const hasStrong = hasAny(sentence, STRONG_WORDS);
    const hasExclamation = sentence.includes('！') || sentence.includes('!');
    const hasQuestion = sentence.includes('？') || sentence.includes('?');
    const hasEllipsis = sentence.includes('……') || sentence.includes('...');
    const isDialogue = sentence.includes('“') || sentence.includes('”') || sentence.includes('"');

    if (hasQuestion) return hasSad ? 'sad' : 'curious';
    if (hasExclamation) {
      if (hasSad) return 'sad';
      if (hasStrong || hasHappy) return 'excited';
      return 'cheerful';
    }
    if (hasEllipsis) return 'warm';
    if (hasSad) return 'sad';
    if (hasHappy) return 'cheerful';
    if (isDialogue) return 'warm';
    if (hasStrong) return 'serious';
    if (sentence.length <= 8) return 'calm';
    return stableSum(sentence) % 3 === 0 ? 'warm' : 'calm';
  }

  const api = { segment, chunkIndexForSentence, resolveEmotion, EMOTIONS };
  global.Shengjian = api;
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
