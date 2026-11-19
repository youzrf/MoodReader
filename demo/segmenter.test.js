'use strict';

const assert = require('node:assert/strict');
const { segment, chunkIndexForSentence, resolveEmotion } = require('./segmenter.js');

function check(text, expectedSentences) {
  const result = segment(text);
  const rebuilt = result.sentences.map((sentence) => text.slice(sentence.start, sentence.end));
  assert.deepEqual(rebuilt, result.sentences.map((sentence) => sentence.text));
  assert.equal(result.sentences.length, expectedSentences, `sentences for: ${text}`);
  for (const sentence of result.sentences) {
    assert.ok(sentence.end > sentence.start);
    assert.ok(sentence.text.trim().length > 0);
  }
  for (let i = 1; i < result.sentences.length; i += 1) {
    assert.ok(result.sentences[i - 1].end <= result.sentences[i].start, 'sentence ranges overlap');
  }
  return result;
}

const basic = check('你好。今天好吗？我很好！', 3);
assert.equal(basic.chunks.length, 3);

const quote = check('他说：“你好。”她笑了。', 1);
assert.equal(quote.sentences[0].text, '他说：“你好。”她笑了。');

const decimal = check('圆周率是3.14，很重要。', 1);
assert.ok(decimal.chunks.length >= 1);
assert.equal(decimal.sentences[0].text, '圆周率是3.14，很重要。');

const english = check('Hello world. This is fine! Really?', 3);
assert.equal(english.sentences[0].text, 'Hello world.');

const ellipsis = check('他走了……她没有回头。', 2);
assert.equal(ellipsis.sentences[0].text, '他走了……');

const newlines = check('第一段。\n\n第二段。\n第三段。', 3);

const dialogue = check('“还是老样子？”\n\n“嗯，一杯热豆浆。”我说。', 2);
assert.equal(dialogue.sentences[1].text, '“嗯，一杯热豆浆。”我说。');

const long = check('这是一个没有任何标点符号的句子'.repeat(8), 1);
assert.ok(long.chunks.length > 1);
for (const chunk of long.chunks) {
  assert.ok(chunk.text.length <= 70, `chunk too long: ${chunk.text.length}`);
}

const rangeTest = check('  第一句。  第二句！  结尾', 3);
assert.ok(rangeTest.sentences[0].start > 0);
assert.equal(rangeTest.sentences[0].text, '第一句。');

assert.equal(resolveEmotion('auto', '真的吗？'), 'curious');
assert.equal(resolveEmotion('auto', '太棒了！'), 'excited');
assert.equal(resolveEmotion('auto', '他哭了。'), 'sad');
assert.equal(resolveEmotion('auto', '今天阳光很好。'), 'cheerful');
assert.equal(resolveEmotion('warm', '真的吗？'), 'warm');

const target = rangeTest.sentences[1];
assert.ok(chunkIndexForSentence(rangeTest, target.id) >= 0);
assert.equal(rangeTest.chunks[chunkIndexForSentence(rangeTest, target.id)].sentenceIndex, target.id);

console.log('segmenter tests passed');
console.log(JSON.stringify({
  basic: basic.sentences,
  chunks: basic.chunks,
  longChunks: long.chunks.length
}, null, 2));
