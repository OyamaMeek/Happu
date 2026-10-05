'use strict';
const $ = id => document.getElementById(id);
const encodePath = path => path.split('/').map(encodeURIComponent).join('/');
let currentPath = '', listingVersion = 0, uploading = false, dragDepth = 0;
function icon(kind) {
  const shapes = {folder:'M3 7V4h6l3 3h9v13H3V7Z', file:'M6 3h8l4 4v14H6V3Zm8 0v5h4M9 12h6m-6 4h6', trash:'M4 7h16M9 7V4h6v3M6 7l1 14h10l1-14M10 11v6m4-6v6'};
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('viewBox', '0 0 24 24'); svg.setAttribute('aria-hidden', 'true');
  const shape = document.createElementNS(svg.namespaceURI, 'path'); shape.setAttribute('d', shapes[kind]); svg.append(shape); return svg;
}
function status(message, error = false) { $('status').textContent = message; $('status').className = error ? 'error' : ''; }
async function request(url, options) {
  const response = await fetch(url, options);
  if (!response.ok) {
    const body = await response.text(); let message = body;
    try { message = JSON.parse(body).error || body; } catch {}
    const error = new Error(message || `请求失败（${response.status}）`);
    error.status = response.status; throw error;
  }
  return response;
}
function navigation(path, label) {
  const link = document.createElement('a'); link.href = '#' + encodeURIComponent(path); link.textContent = label; return link;
}
async function refresh() {
  const version = ++listingVersion; status('正在读取文件夹…'); $('entries').setAttribute('aria-busy', 'true');
  try {
    currentPath = decodeURIComponent(location.hash.slice(1));
    const data = await (await request('/api/list?path=' + encodeURIComponent(currentPath))).json();
    if (version !== listingVersion) return;
    $('breadcrumbs').replaceChildren(navigation('', '首页')); let parent = '';
    for (const name of currentPath.split('/').filter(Boolean)) {
      parent = parent ? parent + '/' + name : name;
      const separator = document.createElement('span'); separator.textContent = '›';
      $('breadcrumbs').append(separator, navigation(parent, parent === 'Downloads' ? '下载' : name));
    }
    $('breadcrumbs').lastElementChild.setAttribute('aria-current', 'page');
    $('folder-title').textContent = $('breadcrumbs').lastElementChild.textContent;
    $('item-count').textContent = `${data.entries.length} 个项目`;
    $('entries').replaceChildren();
    data.entries.sort((a, b) => Number(b.isDirectory) - Number(a.isDirectory) || a.name.localeCompare(b.name, 'zh-CN', {numeric:true}));
    for (const entry of data.entries) {
      const path = currentPath ? currentPath + '/' + entry.name : entry.name;
      const row = document.createElement('li'); row.dataset.name = entry.name;
      row.className = entry.isDirectory ? 'directory' : 'file';
      const label = !currentPath && entry.name === 'Downloads' ? '下载' : entry.name;
      const link = entry.isDirectory ? navigation(path, label) : document.createElement('a');
      if (!entry.isDirectory) { link.href = '/files/' + encodePath(path); link.download = entry.name; link.textContent = label; }
      const title = document.createElement('span'); title.textContent = label;
      link.replaceChildren(icon(entry.isDirectory ? 'folder' : 'file'), title); link.className = 'entry-link';
      const meta = document.createElement('span'); meta.className = 'meta'; meta.textContent = entry.isDirectory ? '文件夹' : formatSize(entry.size);
      const remove = document.createElement('button'); remove.type = 'button'; remove.className = 'delete'; remove.append(icon('trash')); remove.setAttribute('aria-label', '删除 ' + entry.name); remove.title = '删除 ' + entry.name;
      remove.onclick = async () => {
        if (!confirm(`确认删除“${entry.name}”${entry.isDirectory ? '及其中的全部内容' : ''}？`)) return;
        remove.disabled = true;
        try { await request('/files/' + encodePath(path), {method:'DELETE'}); await refresh(); }
        catch (error) { status(`${entry.name}：${error.message}`, true); remove.disabled = false; }
      };
      row.append(link, meta, remove); $('entries').append(row);
    }
    $('empty').hidden = data.entries.length !== 0; status('');
  } catch (error) { if (version === listingVersion) status(error.message, true); }
  finally { if (version === listingVersion) $('entries').setAttribute('aria-busy', 'false'); }
}
function formatSize(bytes) {
  if (bytes < 1024) return `${bytes.toLocaleString()} 字节`;
  const unit = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), 3);
  return `${(bytes / 1024 ** unit).toLocaleString('zh-CN', {maximumFractionDigits:1})} ${['字节', 'KB', 'MB', 'GB'][unit]}`;
}
$('files').onchange = () => startUploads(Array.from($('files').files).map(file => ({file})), currentPath);
$('create').onsubmit = async event => {
  event.preventDefault(); const name = $('folder-name').value;
  const restoreFocus = $('create').contains(document.activeElement);
  const button = $('create').querySelector('button'); button.disabled = true;
  try {
    await request('/api/directories', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({path:currentPath ? currentPath + '/' + name : name})});
    const focusStillHere = $('create').contains(document.activeElement) || document.activeElement === document.body;
    $('folder-name').value = ''; $('new-folder').open = false;
    if (restoreFocus && focusStillHere) $('new-folder').querySelector('summary').focus();
    await refresh();
  } catch (error) { status(error.message, true); }
  finally { button.disabled = false; }
};
function upload(file, folder, name = file.name) {
  const row = document.createElement('div'); row.className = 'upload-row';
  const label = document.createElement('span'); label.textContent = name + '：准备上传';
  const progress = document.createElement('progress'); progress.max = 100; progress.value = 0;
  progress.setAttribute('aria-label', name + ' 上传进度');
  row.append(label, progress); $('uploads').append(row);
  return new Promise(resolve => {
    const xhr = new XMLHttpRequest(); xhr.open('PUT', '/files/' + encodePath(folder ? folder + '/' + name : name));
    xhr.upload.onprogress = event => {
      progress.dataset.event = 'progress';
      if (event.lengthComputable && event.total) progress.value = event.loaded / event.total * 100;
      label.textContent = `${name}：${Math.round(progress.value)}%`;
    };
    xhr.onload = () => {
      if (xhr.status === 201) { progress.value = 100; label.textContent = name + '：上传完成'; row.dataset.result = 'success'; }
      else {
        let reason = xhr.responseText; try { reason = JSON.parse(reason).error || reason; } catch {}
        label.textContent = `${name}：${reason || '上传失败（' + xhr.status + '）'}`; row.dataset.result = 'error';
      }
      resolve();
    };
    xhr.onerror = () => { label.textContent = name + '：连接中断，上传失败'; row.dataset.result = 'error'; resolve(); };
    xhr.onabort = () => { label.textContent = name + '：上传已取消'; row.dataset.result = 'error'; resolve(); };
    xhr.send(file);
  });
}
async function uploadEntry(entry, folder, parent = '') {
  const name = parent ? parent + '/' + entry.name : entry.name;
  let row;
  try {
    if (entry.isFile) {
      const file = await new Promise((resolve, reject) => entry.file(resolve, reject));
      await upload(file, folder, name); return;
    }
    row = document.createElement('div'); row.className = 'upload-row';
    row.textContent = name + '：正在读取文件夹…'; $('uploads').append(row);
    const path = folder ? folder + '/' + name : name;
    try {
      await request('/api/directories', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({path})});
    } catch (error) {
      if (error.status !== 409) throw error;
      await request('/api/list?path=' + encodeURIComponent(path));
    }
    const reader = entry.createReader();
    while (true) {
      const children = await new Promise((resolve, reject) => reader.readEntries(resolve, reject));
      if (!children.length) break;
      for (const child of children) await uploadEntry(child, folder, name);
    }
    row.textContent = name + '：文件夹已创建'; row.dataset.result = 'success';
  } catch (error) {
    if (!row) { row = document.createElement('div'); row.className = 'upload-row'; $('uploads').append(row); }
    row.textContent = `${name}：${error.message || '读取或上传失败'}`; row.dataset.result = 'error';
  }
}
async function startUploads(sources, folder) {
  if (uploading) { status('正在上传，请等待本次完成后再添加文件。', true); return; }
  if (!sources.length) return;
  uploading = true; $('files').disabled = true; $('uploads').replaceChildren();
  $('selection').textContent = '正在上传到 ' + (folder || '首页') + '…';
  try {
    for (const source of sources) {
      if (source.entry) await uploadEntry(source.entry, folder);
      else await upload(source.file, folder);
    }
  } catch (error) { status(error.message, true); }
  finally {
    $('files').value = ''; $('files').disabled = false; uploading = false;
    const failed = $('uploads').querySelectorAll('[data-result="error"]').length;
    $('selection').textContent = failed ? `上传结束，${failed} 个项目失败，请查看上传结果` : '上传完成，可继续选择或拖入文件、文件夹';
    await refresh();
  }
}
const main = document.querySelector('main');
const hasFiles = event => Array.from(event.dataTransfer?.types || []).includes('Files');
function clearDrag() { dragDepth = 0; main.classList.remove('dragging'); }
document.addEventListener('dragenter', event => {
  if (!hasFiles(event)) return;
  event.preventDefault(); dragDepth++;
  if (!uploading) main.classList.add('dragging');
});
document.addEventListener('dragover', event => {
  if (!hasFiles(event)) return;
  event.preventDefault(); event.dataTransfer.dropEffect = uploading ? 'none' : 'copy';
});
document.addEventListener('dragleave', event => {
  if (dragDepth && --dragDepth === 0) clearDrag();
});
document.addEventListener('drop', event => {
  if (!hasFiles(event)) return;
  event.preventDefault(); clearDrag();
  const sources = [];
  for (const item of Array.from(event.dataTransfer.items || [])) {
    if (item.kind !== 'file') continue;
    const entry = item.getAsEntry ? item.getAsEntry() : item.webkitGetAsEntry?.();
    const file = entry ? null : item.getAsFile();
    if (entry || file) sources.push({entry, file});
  }
  if (!sources.length) for (const file of Array.from(event.dataTransfer.files)) sources.push({file});
  startUploads(sources, currentPath);
});
$('refresh').onclick = refresh;
$('skip-files').onclick = event => { event.preventDefault(); $('entries').focus(); };
addEventListener('hashchange', refresh); refresh();
