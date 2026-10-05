const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { chromium } = require('playwright');

async function main() {
  const [binary, runDirectory] = process.argv.slice(2);
  assert(binary && runDirectory, '需要 NetworkSmoke 路径及项目内运行目录');
  const run = path.resolve(runDirectory), root = path.join(run, 'shared'), source = path.join(run, 'source');
  await fs.mkdir(source, { recursive: true });
  const selected = path.join(source, '选择 中文.txt');
  await fs.writeFile(selected, '选择后自动上传');
  const dropped = path.join(source, '拖入 空格.txt');
  await fs.writeFile(dropped, '拖入后自动上传');
  const folder = path.join(source, '电子书 #&');
  await fs.mkdir(path.join(folder, '子目录'), { recursive: true });
  await fs.mkdir(path.join(folder, '空目录'), { recursive: true });
  await fs.writeFile(path.join(folder, '子目录', '中文.txt'), '保留目录层级');
  await fs.writeFile(path.join(folder, '零字节.txt'), '');
  for (let i = 0; i < 105; i++) await fs.writeFile(path.join(folder, `file-${i}.txt`), `内容 ${i}`);
  const server = spawn(path.resolve(binary), [root, 'serve-browser']);
  server.stderr.on('data', data => process.stderr.write(data));
  let browser;
  try {
    const base = await new Promise((resolve, reject) => {
      let output = '';
      const timeout = setTimeout(() => reject(new Error('共享服务启动超时')), 15000);
      server.stdout.on('data', data => {
        output += data;
        const match = output.match(/NETWORK_CURL_URL (http:\/\/\S+)/);
        if (match) { clearTimeout(timeout); resolve(match[1]); }
      });
      server.on('exit', code => { clearTimeout(timeout); reject(new Error(`共享服务提前终止 ${code}: ${output}`)); });
    });
    browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
    const page = await browser.newPage({ viewport: { width: 1100, height: 800 } });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(base + '#' + encodeURIComponent('电子书'));
    await page.waitForFunction(() => document.querySelector('#folder-title').textContent === '电子书');
    async function finished(success, failure = 0) {
      await page.waitForFunction(({ success, failure }) =>
        document.querySelectorAll('#uploads [data-result=success]').length === success &&
        document.querySelectorAll('#uploads [data-result=error]').length === failure &&
        !document.querySelector('#files').disabled, { success, failure }, { timeout: 20000 });
    }
    await page.locator('#files').setInputFiles(selected);
    await finished(1);
    assert.equal(await fs.readFile(path.join(root, '电子书', '选择 中文.txt'), 'utf8'), '选择后自动上传');
    assert.equal(await page.locator('#files').inputValue(), '');
    console.log('PASS 选择文件后自动上传并清空选择');

    const cdp = await page.context().newCDPSession(page);
    async function drop(files, type = 'drop') {
      const data = { items: [], files, dragOperationsMask: 1 };
      if (type === 'drop') {
        await cdp.send('Input.dispatchDragEvent', { type: 'dragEnter', x: 400, y: 450, data });
        await cdp.send('Input.dispatchDragEvent', { type: 'dragOver', x: 400, y: 450, data });
      }
      await cdp.send('Input.dispatchDragEvent', { type, x: 400, y: 450, data });
    }
    await drop([dropped]);
    await finished(1);
    assert.equal(await fs.readFile(path.join(root, '电子书', '拖入 空格.txt'), 'utf8'), '拖入后自动上传');
    console.log('PASS 原生文件拖入后自动上传');

    await drop([folder]);
    await finished(110);
    assert.equal(await fs.readFile(path.join(root, '电子书', '电子书 #&', '子目录', '中文.txt'), 'utf8'), '保留目录层级');
    assert.deepEqual(await fs.readdir(path.join(root, '电子书', '电子书 #&', '空目录')), []);
    assert.equal((await fs.stat(path.join(root, '电子书', '电子书 #&', '零字节.txt'))).size, 0);
    for (let i = 0; i < 105; i++) assert.equal(await fs.readFile(path.join(root, '电子书', '电子书 #&', `file-${i}.txt`), 'utf8'), `内容 ${i}`);
    console.log('PASS 原生文件夹拖入保留层级、空目录、特殊名称及超过100个条目');

    await fs.writeFile(path.join(folder, '子目录', '中文.txt'), '覆盖应当拒绝');
    await fs.writeFile(path.join(folder, '新增.txt'), '合并现有目录');
    await drop([folder]);
    await finished(4, 107);
    assert.equal(await fs.readFile(path.join(root, '电子书', '电子书 #&', '子目录', '中文.txt'), 'utf8'), '保留目录层级');
    assert.equal(await fs.readFile(path.join(root, '电子书', '电子书 #&', '新增.txt'), 'utf8'), '合并现有目录');
    console.log('PASS 已有目录合并、同名文件拒绝覆盖并继续上传其他文件');

    const secondFolder = path.join(source, '另一文件夹');
    await fs.mkdir(secondFolder);
    await fs.writeFile(path.join(secondFolder, '内容.txt'), '第二个根目录');
    const extra = path.join(source, '另一个.txt');
    await fs.writeFile(extra, '同时拖入普通文件');
    await drop([secondFolder, extra]);
    await finished(3);
    assert.equal(await fs.readFile(path.join(root, '电子书', '另一文件夹', '内容.txt'), 'utf8'), '第二个根目录');
    assert.equal(await fs.readFile(path.join(root, '电子书', '另一个.txt'), 'utf8'), '同时拖入普通文件');
    console.log('PASS 文件与文件夹混合拖放');

    const blocked = path.join(source, '同名目录');
    await fs.mkdir(blocked);
    await fs.writeFile(path.join(blocked, '内容.txt'), '不能写入');
    await fs.writeFile(path.join(root, '电子书', '同名目录'), '现有文件');
    await drop([blocked]);
    await finished(0, 1);
    assert.equal(await fs.readFile(path.join(root, '电子书', '同名目录'), 'utf8'), '现有文件');
    console.log('PASS 目录与已有文件冲突时明确失败，原文件保留');

    const batch = path.join(source, '批次目录');
    await fs.mkdir(batch);
    for (let i = 0; i < 105; i++) await fs.writeFile(path.join(batch, `batch-${i}.txt`), `批次 ${i}`);
    const rejected = path.join(source, '忙碌时添加.txt');
    await fs.writeFile(rejected, '不可混入本批次');
    await drop([batch]);
    await page.waitForFunction(() => document.querySelector('#files').disabled);
    await drop([rejected]);
    await page.evaluate(() => { location.hash = encodeURIComponent('图片'); });
    await finished(106);
    for (let i = 0; i < 105; i++) assert.equal(await fs.readFile(path.join(root, '电子书', '批次目录', `batch-${i}.txt`), 'utf8'), `批次 ${i}`);
    await assert.rejects(fs.stat(path.join(root, '电子书', '忙碌时添加.txt')), { code: 'ENOENT' });
    await assert.rejects(fs.stat(path.join(root, '图片', '批次目录')), { code: 'ENOENT' });
    await page.waitForFunction(() => document.querySelector('#folder-title').textContent === '图片');
    console.log('PASS 上传中阻止重复拖放，导航后批次仍写入原目标目录');

    const fallback = await page.evaluate(() => {
      const data = new DataTransfer();
      data.items.add(new File(['原生 File 上传'], '普通 File.txt'));
      const event = new DragEvent('drop', { dataTransfer: data, bubbles: true, cancelable: true });
      document.querySelector('main').dispatchEvent(event);
      return event.defaultPrevented;
    });
    assert.equal(fallback, true);
    await finished(1);
    assert.equal(await fs.readFile(path.join(root, '图片', '普通 File.txt'), 'utf8'), '原生 File 上传');
    const textDrop = await page.evaluate(() => {
      const data = new DataTransfer(); data.setData('text/plain', '普通文本');
      const event = new DragEvent('drop', { dataTransfer: data, bubbles: true, cancelable: true });
      document.querySelector('main').dispatchEvent(event);
      return event.defaultPrevented;
    });
    assert.equal(textDrop, false);
    console.log('PASS 原生 File 回退分支正常上传，普通文本拖放保持默认行为');
    assert.deepEqual(errors, []);
    console.log('NETWORK_AUTO_UPLOAD_RESULT {"passed":8,"failed":0,"skipped":0}');
  } finally {
    if (browser) await browser.close();
    server.kill('SIGTERM');
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
