/* All actions stay inside this application. There are no telephony or network APIs. */
(() => {
  'use strict';
  const J = window.Journal, KEY = 'calljournal.archive.v1';
  const phone = document.getElementById('phone'), screen = document.getElementById('screen');
  const tabs = document.getElementById('tabs'), overlay = document.getElementById('overlay');
  const paths = {
    phone: '<path fill="currentColor" d="M6.1 2.5c.6-.3 1.3-.1 1.7.5l2.3 4c.3.6.2 1.3-.3 1.7l-1.5 1.4a16 16 0 0 0 5.6 5.6l1.4-1.5c.4-.5 1.1-.6 1.7-.3l4 2.3c.6.4.8 1.1.5 1.7l-1.3 3c-.3.6-.8.9-1.5.9C10.2 21.8 2.2 13.8 2.2 5.3c0-.7.3-1.2.9-1.5z"/>',
    hangup: '<path fill="currentColor" d="M2 11.6c5.1-5 14.9-5 20 0 .5.5.7 1.2.4 1.8l-1.1 3c-.2.6-.8.9-1.4.8l-4-.8c-.6-.1-1-.6-1-1.2v-2.4a14.6 14.6 0 0 0-5.8 0v2.4c0 .6-.4 1.1-1 1.2l-4 .8c-.6.1-1.2-.2-1.4-.8l-1.1-3c-.3-.6-.1-1.3.4-1.8z"/>',
    recents: '<circle cx="12" cy="12" r="9.4" fill="currentColor"/><path d="M12 5.8v6.4l4 2.4" stroke="var(--bg)" stroke-width="1.8" stroke-linecap="round" fill="none"/>',
    contacts: '<circle cx="12" cy="12" r="9.4" fill="none" stroke="currentColor" stroke-width="1.5"/><circle cx="12" cy="8.6" r="3" fill="currentColor"/><path d="M5.8 18.2c.6-3.1 2.6-4.7 6.2-4.7s5.6 1.6 6.2 4.7" fill="currentColor"/>',
    person: '<circle cx="12" cy="8.1" r="4.2" fill="currentColor"/><path d="M3.2 22c0-6 3-9 8.8-9s8.8 3 8.8 9z" fill="currentColor"/>',
    star: '<path fill="currentColor" d="m12 1.7 3.2 6.5 7.2 1-5.2 5.1 1.2 7.2-6.4-3.4-6.4 3.4 1.2-7.2-5.2-5.1 7.2-1z"/>',
    keypad: '<g fill="currentColor"><circle cx="5" cy="4" r="2.3"/><circle cx="12" cy="4" r="2.3"/><circle cx="19" cy="4" r="2.3"/><circle cx="5" cy="11.5" r="2.3"/><circle cx="12" cy="11.5" r="2.3"/><circle cx="19" cy="11.5" r="2.3"/><circle cx="5" cy="19" r="2.3"/><circle cx="12" cy="19" r="2.3"/><circle cx="19" cy="19" r="2.3"/></g>',
    voicemail: '<g fill="none" stroke="currentColor" stroke-width="2.3"><circle cx="6" cy="12" r="4.8"/><circle cx="18" cy="12" r="4.8"/><path d="M6 16.8h12"/></g>',
    info: '<circle cx="12" cy="12" r="9.2" stroke="currentColor" stroke-width="1.5" fill="none"/><circle cx="12" cy="7" r="1.2" fill="currentColor"/><path d="M12 10.5v6.3m-1.8 0h3.6m-3.4-6.3H12" stroke="currentColor" stroke-width="1.6" fill="none" stroke-linecap="round"/>',
    plus: '<path d="M12 4v16M4 12h16" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>',
    minus: '<path d="M5 12h14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    filter: '<g fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"><path d="M3 5h18M6 12h12M9 19h6"/></g>',
    search: '<circle cx="10.4" cy="10.4" r="6.4" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="m15.2 15.2 5.3 5.3" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>',
    back: '<path d="m15 4-8 8 8 8" stroke="currentColor" stroke-width="2.1" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
    chevron: '<path d="m9 5 7 7-7 7" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
    edit: '<path d="m4 16 12-12 4 4-12 12-5 1zM14 6l4 4" stroke="currentColor" stroke-width="1.6" fill="none" stroke-linejoin="round"/>',
    copy: '<rect x="8" y="6" width="12" height="15" rx="2" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M15 6V3H4v14h4" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/>',
    outgoing: '<path fill="currentColor" d="M3 7c.6-.3 1.2-.1 1.5.4l1.8 3.2c.3.5.2 1-.2 1.4l-1 1a13 13 0 0 0 5 5l1-1c.4-.4.9-.5 1.4-.2l3.2 1.8c.5.3.7.9.4 1.5l-.9 2c-.2.5-.7.8-1.2.8C7.2 23 1 16.8 1 10c0-.5.3-1 .8-1.2z"/><path d="M14 3h7v7m0-7-9 9" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round"/>',
    incoming: '<path fill="currentColor" d="M3 7c.6-.3 1.2-.1 1.5.4l1.8 3.2c.3.5.2 1-.2 1.4l-1 1a13 13 0 0 0 5 5l1-1c.4-.4.9-.5 1.4-.2l3.2 1.8c.5.3.7.9.4 1.5l-.9 2c-.2.5-.7.8-1.2.8C7.2 23 1 16.8 1 10c0-.5.3-1 .8-1.2z"/><path d="M12 3v7h7m-7 0 9-9" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round"/>',
    trash: '<path d="M4 6h16M9 3h6M6 6l1 15h10l1-15M10 10v7m4-7v7" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>',
    settings: '<path d="m9 2-.6 3-2.2 1.3-2.9-1-2.5 4.3 2.2 2v2.5l-2.2 2 2.5 4.3 2.9-1 2.2 1.3.6 3h5l.6-3 2.2-1.3 2.9 1 2.5-4.3-2.2-2v-2.5l2.2-2-2.5-4.3-2.9 1L15.6 5 15 2z" transform="translate(.5 -1) scale(.96)" fill="none" stroke="currentColor" stroke-width="1.5"/><circle cx="12" cy="12" r="3.5" fill="none" stroke="currentColor" stroke-width="1.5"/>',
    backspace: '<path d="m8 5-7 7 7 7h14V5zM11 9l6 6m0-6-6 6" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>',
    mute: '<path d="M9 10V5a3 3 0 0 1 6 0v8M5 9v3a7 7 0 0 0 12 5M12 19v3m-4 0h8M3 2l18 20" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>',
    speaker: '<path d="M3 9h4l5-5v16l-5-5H3z" fill="currentColor"/><path d="M16 7c3 2.6 3 7.4 0 10m3-13c5.5 4.6 5.5 11.4 0 16" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>',
    pause: '<path d="M8 5v14M16 5v14" stroke="currentColor" stroke-width="4" stroke-linecap="round"/>',
    swap: '<path d="M3 7h17l-4-4M21 17H4l4 4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
    merge: '<path d="M5 21v-5l7-7 7 7v5M12 9V2m-4 4 4-4 4 4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
    check: '<path d="m4 12 5 5L21 5" stroke="currentColor" stroke-width="2" stroke-linecap="round" fill="none"/>',
    download: '<path d="M12 3v12m-5-5 5 5 5-5M4 16v5h16v-5" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" fill="none"/>',
    upload: '<path d="M12 16V3m-5 5 5-5 5 5M4 16v5h16v-5" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" fill="none"/>'
  };
  const icon = name => `<svg class="icon" viewBox="0 0 24 24" aria-hidden="true">${paths[name] || paths.phone}</svg>`;
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const buttonLabels = {'add-call':'添加通话','add-contact':'添加联系人','pick-favorite':'添加个人收藏',menu:'过滤和设置',dial:'呼叫',hangup:'结束通话',backspace:'删除一位号码'};
  const btn = (action, text, id = '', classes = '') => `<button type="button" class="${classes}" data-action="${action}"${id ? ` data-id="${esc(id)}"` : ''}${buttonLabels[action] ? ` aria-label="${buttonLabels[action]}"` : ''}>${text}</button>`;
  const avatar = (name, big = false) => `<div class="avatar${big ? ' big' : ''}" aria-hidden="true">${esc(Array.from(name)[0] || '人')}</div>`;
  const chevron = `<span class="chevron">${icon('chevron')}</span>`;
  let data = J.empty(), rawUnreadable = null, storedSnapshot = null;
  let ui = { tab: 'recents', missed: false, query: '', edit: false, detail: null, menu: false, dial: '', settings: false };
  let sheet = null, confirmAction = null, callSession = null, toastTimeout;
  let startupError = '';
  try {
    const raw = localStorage.getItem(KEY); storedSnapshot = raw;
    if (raw) { try { data = J.archive(JSON.parse(raw)); } catch (error) { rawUnreadable = raw; startupError = '已保存的数据无法读取。请在“设置与备份”中导出原始数据或导入有效备份，原始内容仍然保留。'; } }
  } catch (_) { startupError = '浏览器未允许访问本地存储。请允许本地存储后再添加或更改内容。'; }

  /* Commit disk first, then memory. Storage failures leave the current state untouched. */
  function commit(change, allowRecovery = false) {
    if (rawUnreadable && !allowRecovery) throw Error('原始数据尚未恢复。请先导出原始数据，再导入有效备份。');
    const next = JSON.parse(JSON.stringify(data));
    const candidate = change(next) || next, valid = J.archive(candidate);
    const encoded = JSON.stringify(valid);
    if (new Blob([encoded]).size > 10 * 1024 * 1024) throw Error('备份文件不能超过 10 MB。');
    let latest;
    try { latest = localStorage.getItem(KEY); } catch (_) { throw Error('本地存储不可用，当前数据未更改。'); }
    if (latest !== storedSnapshot) throw Error('另一窗口更新了本地数据。当前更改尚未保存，请先导出备份，刷新页面后再编辑。');
    try { localStorage.setItem(KEY, encoded); } catch (_) { throw Error('未能保存：本地存储不可用或空间不足。当前数据未更改。请导出备份并检查浏览器设置。'); }
    data = valid; storedSnapshot = encoded; rawUnreadable = null; return valid;
  }
  function perform(change) { try { commit(change); render(); return true; } catch (error) { alertMessage('未能完成', error.message); return false; } }
  function notify(text) {
    const toast = document.getElementById('toast'); toast.textContent = text; toast.classList.add('show');
    clearTimeout(toastTimeout); toastTimeout = setTimeout(() => toast.classList.remove('show'), 2000);
  }
  function alertMessage(title, text, extra = '') {
    const node = document.createElement('div'); node.className = 'alert-shade';
    node.innerHTML = `<div class="alert" role="alertdialog" aria-modal="true" aria-label="${esc(title)}"><h3>${esc(title)}</h3><p>${esc(text)}</p>${extra}${btn('alert-close','好')}</div>`;
    phone.append(node); node.querySelector('button')?.focus();
  }
  function confirmation(text, label, action) {
    confirmAction = action;
    const node = document.createElement('div'); node.className = 'confirm-shade';
    node.innerHTML = `<div class="confirm-sheet" role="dialog" aria-modal="true" aria-label="${esc(text)}"><div class="confirm-group"><div class="confirm-title">${esc(text)}</div>${btn('confirm-yes',esc(label),'','red')}</div>${btn('confirm-no','取消','','confirm-cancel')}</div>`;
    phone.append(node); node.querySelector('button')?.focus();
  }
  function closeConfirm() { phone.querySelector('.confirm-shade')?.remove(); confirmAction = null; }
  function setTab(tab) { ui.tab = tab; ui.detail = null; ui.settings = false; ui.query = ''; ui.edit = false; ui.menu = false; render(); screen.scrollTop = 0; }
  function toolbar(left, title, right) { return `<div class="toolbar"><div class="toolbar-side">${left}</div><span class="toolbar-title">${title}</span><div class="toolbar-side right">${right}</div></div>`; }
  function searchBox() { return `<div class="search">${icon('search')}<input type="search" id="search" placeholder="${ui.tab === 'contacts' ? '搜索' : '姓名或电话号码'}" aria-label="搜索姓名或电话号码" value="${esc(ui.query)}" autocomplete="off">${ui.query ? btn('clear-query','×','','icon-button') : ''}</div>`; }
  function empty(title, symbol, action = '') { return `<div class="empty">${icon(symbol)}<h2>${title}</h2>${action}</div>`; }
  function render() {
    const appearance = data.preferences.appearance;
    phone.classList.toggle('dark', appearance === 'dark' || appearance === 'system' && matchMedia('(prefers-color-scheme: dark)').matches);
    const tabDefs = data.preferences.layout === 'unified' ? [['recents','phone','通话'],['contacts','contacts','通讯录'],['keypad','keypad','拨号键盘'],['search','search','搜索']] : [['favorites','star','个人收藏'],['recents','recents','最近通话'],['contacts','contacts','通讯录'],['keypad','keypad','拨号键盘'],['voicemail','voicemail','语音留言']];
    if (!tabDefs.some(v => v[0] === ui.tab)) ui.tab = 'recents';
    tabs.innerHTML = tabDefs.map(([name,symbol,title]) => `<button type="button" class="tab${ui.tab === name ? ' active' : ''}" data-action="tab" data-id="${name}" aria-label="${title}" aria-current="${ui.tab === name ? 'page' : 'false'}">${icon(symbol)}<span>${title}</span></button>`).join('');
    if (ui.settings) renderSettings();
    else if (ui.detail) renderDetail();
    else if (ui.tab === 'recents' || ui.tab === 'search') renderRecents();
    else if (ui.tab === 'contacts') renderContacts();
    else if (ui.tab === 'favorites') renderFavorites();
    else if (ui.tab === 'keypad') renderKeypad();
    else screen.innerHTML = toolbar('','','') + '<h1 class="page-title">语音留言</h1>' + empty('无语音留言','voicemail');
  }
  function renderRecents() {
    const classic = data.preferences.layout === 'classic', isSearch=ui.tab==='search';
    screen.innerHTML = (isSearch ? toolbar('','','') : toolbar(btn('edit-list',ui.edit ? '完成' : '编辑'),'', btn('add-call',icon('plus'),'','icon-button') + btn('menu',icon('filter'),'','icon-button'))) + `<h1 class="page-title">${isSearch ? '搜索' : classic ? '最近通话' : '通话'}</h1>` + searchBox() + (isSearch ? '' : `<div class="segment">${btn('all','所有通话','',ui.missed ? '' : 'selected')}${btn('missed','未接来电','',ui.missed ? 'selected' : '')}</div>`) + (!classic && !isSearch && !ui.query && !ui.missed ? favoritesStrip() : '') + '<div id="results"></div>';
    renderRecentRows();
    if (ui.menu) overlay.innerHTML = `<div class="more-menu">${btn('layout-classic','经典布局' + (classic ? icon('check') : ''))}${btn('layout-unified','统一布局' + (!classic ? icon('check') : ''))}${btn('settings','设置与备份' + icon('settings'))}${btn('clear-calls','清空最近通话' + icon('trash'),'','red')}</div>`;
    else if (!sheet) overlay.innerHTML = '';
  }
  function favoritesStrip() {
    const fav = data.contacts.filter(v => v.isFavorite).slice(0,8);
    return fav.length ? `<h2 class="section-heading">个人收藏</h2><div class="favorite-strip">${fav.map(c => btn('call-contact',avatar(c.name)+`<span>${esc(c.name)}</span>`,c.id,'favorite-chip')).join('')}</div><h2 class="section-heading">最近通话</h2>` : '';
  }
  function renderRecentRows() {
    const rows = J.matching(data, ui.query, ui.missed), unified = data.preferences.layout === 'unified';
    const results = screen.querySelector('#results');
    results.innerHTML = rows.length ? `<div class="recent-list">${rows.map(c => `<div class="recent-row" data-call-id="${c.id}">${ui.edit ? btn('delete-call',icon('minus'),c.id,'delete-dot') : ''}${btn(unified ? 'detail-call' : 'call-record',`${unified ? avatar(J.displayName(data,c)) : ''}<span class="row-text"><span class="row-name${c.direction === 'missed' ? ' red' : ''}">${esc(J.displayName(data,c))}</span><span class="row-subtitle">${['outgoing','cancelled'].includes(c.direction) ? icon('outgoing') : unified ? icon('incoming') : ''}${esc(c.label)}${c.direction === 'cancelled' ? ' · 已取消' : ''}</span></span><span class="row-time">${esc(J.recent(c.date))}</span>`,c.id,'row-main')}${btn(unified ? 'call-record' : 'detail-call',icon(unified ? 'phone' : 'info'),c.id,'info-button')}</div>`).join('')}</div>` : empty(ui.query ? '无搜索结果' : ui.missed ? '无未接来电' : '无最近通话',ui.query ? 'search' : 'phone', !ui.query && !ui.missed ? btn('add-call','添加通话') : '');
    results.querySelectorAll('.info-button').forEach(b => b.setAttribute('aria-label', unified ? '呼叫' : '通话详情'));
  }
  function sortedContacts() { return [...data.contacts].sort((a,b) => a.name.localeCompare(b.name,'zh-CN')); }
  function matchingContacts() { const q = ui.query.trim().toLowerCase(), n = /^\+?[0-9*#()\- \u00a0]+$/.test(q) ? J.digits(q) : ''; return sortedContacts().filter(v => !q || v.name.toLowerCase().includes(q) || v.phoneNumber.includes(q) || n && J.digits(v.phoneNumber).includes(n)); }
  function renderContacts() {
    screen.innerHTML = toolbar('','',btn('add-contact',icon('plus'),'','icon-button')) + '<h1 class="page-title">通讯录</h1>' + searchBox() + '<div id="results"></div>';
    renderContactRows();
  }
  function renderContactRows() {
    const contacts = matchingContacts();
    screen.querySelector('#results').innerHTML = contacts.length ? `<div class="contact-list">${contacts.map(c => btn('detail-contact',esc(c.name),c.id,'contact-row')).join('')}</div><div class="contact-count">${contacts.length} 个联系人</div>` : empty(ui.query ? '无搜索结果' : '无联系人','contacts', !ui.query ? btn('add-contact','添加联系人') : '');
  }
  function renderFavorites() {
    const contacts = sortedContacts().filter(v => v.isFavorite);
    screen.innerHTML = toolbar(btn('edit-list',ui.edit ? '完成' : '编辑'),'',btn('pick-favorite',icon('plus'),'','icon-button')) + '<h1 class="page-title">个人收藏</h1>' + (contacts.length ? `<div class="recent-list">${contacts.map(c => `<div class="recent-row favorite-row">${ui.edit ? btn('remove-favorite',icon('minus'),c.id,'delete-dot') : ''}${btn('call-contact',avatar(c.name)+`<span class="row-text"><span class="row-name">${esc(c.name)}</span><span class="row-subtitle">${icon('phone')}${esc(c.label)}</span></span>`,c.id,'row-main')}${btn('detail-contact',icon('info'),c.id,'info-button')}</div>`).join('')}</div>` : empty('无个人收藏','star',btn('pick-favorite','添加个人收藏')));
    screen.querySelectorAll('.info-button').forEach(b => b.setAttribute('aria-label','联系人详情'));
  }
  function keys(action = 'digit') {
    return `<div class="keys">${[['1',''],['2','ABC'],['3','DEF'],['4','GHI'],['5','JKL'],['6','MNO'],['7','PQRS'],['8','TUV'],['9','WXYZ'],['*',''],['0','+'],['#','']].map(([n,letters]) => btn(action,`${n}<small>${letters || '&nbsp;'}</small>`,n,'key')).join('')}</div>`;
  }
  function renderKeypad() {
    screen.innerHTML = '<div class="keypad"><div class="number-display" id="dial-number">' + esc(ui.dial) + '</div>' + `<div class="add-number">${ui.dial ? btn('contact-from-dial','添加号码') : ''}</div>` + keys() + `<div class="dial-bottom"><span></span>${btn('dial',icon('phone'),'','dial')}${btn('backspace',icon('backspace'),'','backspace')}</div></div>`;
    screen.querySelector('.dial').setAttribute('aria-label','呼叫'); screen.querySelector('.backspace').setAttribute('aria-label','删除一位号码');
  }
  function showDetail(type,id) { ui.detail = {type,id}; ui.menu = false; overlay.innerHTML = ''; render(); screen.scrollTop = 0; }
  function section(title, content) { return `<section class="section">${title ? `<h2 class="section-label">${title}</h2>` : ''}<div class="card">${content}</div></section>`; }
  function actionButton(action, title, symbol, id) { return btn(action,icon(symbol)+`<span>${title}</span>`,id,'detail-action'); }
  function renderDetail() {
    const {type,id} = ui.detail;
    const v = data[type === 'call' ? 'calls' : 'contacts'].find(v => v.id === id);
    if (!v) { ui.detail = null; render(); return; }
    const name = type === 'call' ? J.displayName(data,v) : v.name;
    let body = `<div class="detail-hero">${avatar(name,true)}<h1 class="detail-name">${esc(name)}</h1><div class="action-row">${actionButton(type === 'call' ? 'call-record' : 'call-contact','呼叫','phone',id)}${actionButton('copy-number','复制','copy',v.phoneNumber)}${actionButton(type === 'call' ? 'edit-call' : 'toggle-favorite',type === 'call' ? '编辑' : v.isFavorite ? '已收藏' : '收藏',type === 'call' ? 'edit' : 'star',id)}</div></div>`;
    if (type === 'call') {
      const d = new Date(v.date);
      body += section(esc(d.toLocaleDateString('zh-CN',{year:'numeric',month:'2-digit',day:'2-digit',weekday:'long'})), `<div class="call-meta"><span>${esc(d.toLocaleTimeString('zh-CN',{hour12:false,hour:'2-digit',minute:'2-digit',second:'2-digit'}))}</span><span class="meta-right"><span${v.direction === 'missed' ? ' class="red"' : ''}>${icon(v.direction === 'outgoing' || v.direction === 'cancelled' ? 'outgoing' : 'incoming')}${J.directions[v.direction]}</span>${['missed','cancelled'].includes(v.direction) ? '' : `<span class="secondary">${J.duration(v.durationSeconds)}</span>`}</span></div>`);
    }
    body += section('',btn(type === 'call' ? 'call-record' : 'call-contact',`<label>${esc(v.label)}</label><span>${esc(v.phoneNumber)}</span>`,id,'card-row stack'));
    if (type === 'call') body += section('',v.contactID ? btn('detail-contact','查看联系人'+chevron,v.contactID,'card-row') + btn('duplicate-call','添加通话记录',id,'card-row') : btn('contact-from-call','创建新联系人',id,'card-row') + btn('duplicate-call','添加通话记录',id,'card-row'));
    else {
      body += section('',btn('add-linked-call','添加通话记录',id,'card-row') + btn('toggle-favorite',v.isFavorite ? '从个人收藏移除' : '添加到个人收藏',id,'card-row'));
      const history = J.sorted(data).filter(c => c.contactID === id).slice(0,20);
      if (history.length) body += section('最近通话',history.map(c => btn('detail-call',`<span><span${c.direction === 'missed' ? ' class="red"' : ''}>${J.directions[c.direction]}</span><br><small class="secondary">${J.duration(c.durationSeconds)}</small></span><span class="trailing">${esc(J.recent(c.date))}</span>${chevron}`,c.id,'card-row')).join(''));
    }
    body += section('',btn(type === 'call' ? 'delete-call' : 'delete-contact',type === 'call' ? '删除通话' : '删除联系人',id,'card-row red'));
    screen.innerHTML = `<div class="grouped">${toolbar(btn('back',icon('back')+(ui.tab === 'contacts' ? '通讯录' : ui.tab === 'favorites' ? '个人收藏' : '最近通话')),'',btn(type === 'call' ? 'edit-call' : 'edit-contact','编辑',id))}${body}</div>`;
  }
  function localDate(iso) {
    const d = new Date(iso), z = v => String(v).padStart(2,'0');
    return `${d.getFullYear()}-${z(d.getMonth()+1)}-${z(d.getDate())}T${z(d.getHours())}:${z(d.getMinutes())}:${z(d.getSeconds())}`;
  }
  function formRow(label, control) { return `<div class="form-row"><label>${label}</label>${control}</div>`; }
  function formSection(title, content, help = '') { return `<section class="form-section">${title ? `<h2 class="form-section-title">${title}</h2>` : ''}<div class="form-group">${content}</div>${help ? `<p class="form-help">${help}</p>` : ''}</section>`; }
  function openSheet(title, content, kind, draft, onSave = null) {
    ui.menu = false;
    sheet = {kind,draft,onSave};
    overlay.innerHTML = `<div class="modal-shade"><div class="sheet" role="dialog" aria-modal="true" aria-label="${esc(title)}">${toolbar(btn('close-sheet','取消'),title,kind === 'picker' ? '' : btn('save-sheet','完成'))}<div class="sheet-body"><form id="editor" novalidate>${content}<div id="form-error" class="form-error" role="alert"></div><button type="submit" hidden>完成</button></form></div></div></div>`;
    sheet.original = serializeForm();
    overlay.querySelector('button')?.focus();
  }
  function serializeForm() { const form = overlay.querySelector('#editor'); return form ? JSON.stringify([...new FormData(form).entries()]) : ''; }
  function closeSheet(force = false) {
    if (!force && sheet?.kind !== 'picker' && serializeForm() !== sheet?.original) { confirmation('放弃更改？','放弃更改',() => closeSheet(true)); return; }
    sheet = null; overlay.innerHTML = ''; render();
  }
  function openCallEditor(v = null) {
    const draft = v ? {...v} : {id:J.id(),phoneNumber:'',label:'手机',date:new Date().toISOString(),durationSeconds:60,direction:'incoming'};
    const contacts = sortedContacts();
    const h = draft.durationSeconds / 3600 | 0, m = draft.durationSeconds % 3600 / 60 | 0, s = draft.durationSeconds % 60;
    const content = formSection('联系人', formRow('关联联系人',`<select name="contactID" aria-label="关联联系人"><option value="">无</option>${contacts.map(c => `<option value="${c.id}"${c.id === draft.contactID ? ' selected' : ''}>${esc(c.name)}</option>`).join('')}</select>`) + formRow('姓名',`<input name="nameOverride" aria-label="姓名" type="text" maxlength="200" placeholder="${draft.contactID ? '使用联系人姓名' : '选填'}" value="${esc(draft.nameOverride || '')}" autocomplete="off">`) + formRow('电话号码',`<input name="phoneNumber" aria-label="电话号码" type="tel" maxlength="64" value="${esc(draft.phoneNumber)}" placeholder="电话号码" autocomplete="off">`) + formRow('标签',`<input name="label" aria-label="标签" maxlength="40" value="${esc(draft.label)}" placeholder="手机">`)) + formSection('通话',formRow('日期和时间',`<input name="date" aria-label="日期和时间" type="datetime-local" step="1" min="1900-01-01T00:00:00" max="2199-12-31T23:59:59" value="${localDate(draft.date)}">`) + formRow('通话类型',`<select name="direction" aria-label="通话类型">${Object.entries(J.directions).map(([k,t]) => `<option value="${k}"${k === draft.direction ? ' selected' : ''}>${t}</option>`).join('')}</select>`) + formRow('通话时长',`<div class="duration-inputs"><input name="hours" type="number" min="0" max="99" aria-label="小时" value="${h}"><span>时</span><input name="minutes" type="number" min="0" max="59" aria-label="分钟" value="${m}"><span>分</span><input name="seconds" type="number" min="0" max="59" aria-label="秒" value="${s}"><span>秒</span></div>`),'未接来电和已取消通话的时长为 0 秒。');
    openSheet(data.calls.some(c => c.id === draft.id) ? '编辑通话' : '添加通话',content,'call',draft);
    updateDurationEnabled();
    sheet.original=serializeForm();
  }
  function openContactEditor(v = null, onSave = null) {
    const draft = v ? {...v} : {id:J.id(),name:'',phoneNumber:'',label:'手机',isFavorite:false};
    const content = `<div class="sheet-avatar">${avatar(draft.name || '人',true)}</div>` + formSection('',formRow('姓名',`<input name="name" aria-label="联系人姓名" maxlength="200" placeholder="姓名" value="${esc(draft.name)}" autocomplete="off">`) + formRow('电话号码',`<input name="phoneNumber" aria-label="电话号码" type="tel" maxlength="64" value="${esc(draft.phoneNumber)}" placeholder="电话号码" autocomplete="off">`) + formRow('标签',`<input name="label" aria-label="标签" maxlength="40" value="${esc(draft.label)}">`)) + formSection('',formRow('个人收藏',`<input name="isFavorite" aria-label="个人收藏" type="checkbox"${draft.isFavorite ? ' checked' : ''}>`));
    openSheet(data.contacts.some(c => c.id === draft.id) ? '编辑联系人' : '新建联系人',content,'contact',draft,onSave);
  }
  function picker() {
    openSheet('添加个人收藏',sortedContacts().length ? `<div class="contact-list">${sortedContacts().map(c => btn('select-favorite',avatar(c.name)+esc(c.name),c.id,'contact-row favorite-row')).join('')}</div>` : empty('无联系人','contacts',btn('new-favorite','新建联系人')),'picker',null);
  }
  function formError(message) { const target = overlay.querySelector('#form-error'); target.textContent = message; target.style.display = 'block'; target.scrollIntoView({block:'nearest'}); }
  function updateDurationEnabled() {
    const form = overlay.querySelector('#editor'); if (!form || sheet?.kind !== 'call') return;
    const off = ['missed','cancelled'].includes(form.elements.direction.value);
    ['hours','minutes','seconds'].forEach(name => { form.elements[name].disabled = off; if(off)form.elements[name].value='0'; });
  }
  function saveSheet() {
    if (!sheet || sheet.kind === 'picker') return;
    const form = overlay.querySelector('#editor'), fields = Object.fromEntries(new FormData(form));
    try {
      let value;
      if (sheet.kind === 'call') {
        let seconds = 0;
        if (!['missed','cancelled'].includes(fields.direction)) {
          for (const [name,max] of [['hours',99],['minutes',59],['seconds',59]]) {
            const n = Number(fields[name]); if (fields[name] === '' || !Number.isInteger(n) || n < 0 || n > max) throw Error('时长的小时需为 0–99，分钟和秒需为 0–59 的整数。');
          }
          seconds = Number(fields.hours) * 3600 + Number(fields.minutes) * 60 + Number(fields.seconds);
        }
        value = J.call({...sheet.draft,...fields,contactID:fields.contactID || undefined,durationSeconds:seconds,date:new Date(fields.date).toISOString()});
        commit(next => J.upsert(next,'calls',value));
      } else {
        value = J.contact({...sheet.draft,...fields,isFavorite:form.elements.isFavorite.checked});
        commit(next => { J.upsert(next,'contacts',value); sheet.onSave?.(next,value); });
      }
      closeSheet(true); notify('已保存');
    } catch (error) { formError(error instanceof RangeError ? '请选择完整的日期和时间。' : error.message); }
  }
  function startCall(number, name, contactID) {
    try { number = J.number(number); } catch (error) { alertMessage('无法呼叫',error.message); return; }
    if (callSession) return;
    const contact = data.contacts.find(c => c.id === contactID || J.digits(c.phoneNumber) === J.digits(number));
    const started = Date.now();
    callSession = {lines:[{id:J.id(),number,name:name || contact?.name || number,contactID:contact?.id,started,connected:null,seconds:0}],active:0,merged:false,mute:false,speaker:false,hold:false,keypad:false,digits:'',finished:false};
    phone.classList.add('in-call');
    ui.menu = false; if (!sheet) overlay.innerHTML = '';
    renderCall();
    callSession.interval = setInterval(() => {
      if (!callSession || callSession.finished) return;
      for (const line of callSession.lines) {
        if (!line.ended && !line.connected && Date.now() - line.started >= 1000) line.connected = Date.now();
        if (!line.ended) line.seconds = line.connected ? Math.floor((Date.now() - line.connected) / 1000) : 0;
      }
      const active = callSession.lines[callSession.active];
      const timer = phone.querySelector('#call-timer');
      if (timer) timer.textContent = callSession.hold ? '通话已保留' : active.connected ? J.timer(active.seconds) : '正在呼叫…';
    },250);
  }
  function renderCall() {
    const c = callSession; if (!c) return;
    const active = c.lines[c.active];
    let layer = phone.querySelector('.call-layer'); if (!layer) { layer = document.createElement('div'); layer.className = 'call-layer'; layer.setAttribute('role','dialog'); layer.setAttribute('aria-modal','true'); layer.setAttribute('aria-label','通话'); phone.append(layer); }
    const two = c.lines.length === 2;
    const controls = [['mute','静音','mute'],['call-keypad','拨号键盘','keypad'],['speaker','扬声器','speaker'],[two && !c.merged ? 'swap-call' : 'hold',two && !c.merged ? '切换通话' : '保留通话',two && !c.merged ? 'swap' : 'pause'],['call-add','添加通话','plus'],[two ? 'merge-call' : 'call-contacts',two ? c.merged ? '已合并' : '合并通话' : '通讯录',two ? 'merge' : 'contacts']];
    layer.innerHTML = `<h1 class="call-name">${c.merged ? '电话会议' : esc(active.name)}</h1>${two ? `<div class="call-secondary">${c.merged ? c.lines.map(v=>esc(v.name)).join('、') : esc(c.lines[1-c.active].name)+' · 保留通话'}</div>` : ''}<div class="call-timer" id="call-timer">${c.hold ? '通话已保留' : active.connected ? J.timer(active.seconds) : '正在呼叫…'}</div>` + (c.keypad ? `<div class="call-keypad"><div id="call-digits" class="number-display">${esc(c.digits)}</div>${keys('call-digit')}${btn('hide-call-keypad','隐藏','','call-keypad-close')}</div>` : `<div class="call-controls">${controls.map(([action,title,symbol]) => btn(action,`<span class="control-circle">${icon(symbol)}</span><span>${title}</span>`,'',`call-control${c[action] || action === 'merge-call' && c.merged ? ' on' : ''}`)).join('')}</div>`) + btn('hangup',icon('hangup'),'','end-call') + '<div class="home-call" aria-hidden="true"></div>';
    layer.querySelector('.end-call').setAttribute('aria-label','结束通话');
    if (two) layer.querySelector('[data-action="call-add"]').disabled=true;
    if (c.merged) layer.querySelector('[data-action="merge-call"]').disabled=true;
  }
  function openCallPicker(contactsOnly = false) {
    if (!callSession || callSession.lines.length >= 2) return;
    phone.querySelector('.call-picker-shade')?.remove();
    const node = document.createElement('div'); node.className = 'call-picker-shade';
    node.innerHTML = `<div class="sheet" role="dialog" aria-modal="true" aria-label="${contactsOnly ? '通讯录' : '添加通话'}">${toolbar(btn('close-call-picker','取消'),contactsOnly ? '通讯录' : '添加通话','')}<div class="sheet-body">${!contactsOnly ? formSection('',formRow('电话号码','<input type="tel" id="second-call-number" aria-label="添加通话的电话号码" maxlength="64" placeholder="电话号码">') + btn('add-number-call','呼叫','','card-row')) : ''}${sortedContacts().length ? `<div class="contact-list">${sortedContacts().map(v=>btn('add-contact-call',avatar(v.name)+`<span>${esc(v.name)}<br><small class="secondary">${esc(v.phoneNumber)}</small></span>`,v.id,'contact-row favorite-row')).join('')}</div>` : empty('无联系人','contacts',contactsOnly ? btn('show-number-call','输入号码') : '')}</div></div>`;
    phone.append(node); node.querySelector('button')?.focus();
  }
  function addLocalLine(number,name,contactID) {
    const c = callSession; if (!c || c.lines.length >= 2) return;
    try {number=J.number(number);}catch(error){alertMessage('无法呼叫',error.message);return;}
    const contact=data.contacts.find(v=>v.id===contactID || J.digits(v.phoneNumber)===J.digits(number));
    c.lines.push({id:J.id(),number,name:name || contact?.name || number,contactID:contact?.id,started:Date.now(),connected:null,seconds:0});
    c.active=1;c.hold=false;c.keypad=false;
    phone.querySelector('.call-picker-shade')?.remove();renderCall();
  }
  function hangup() {
    const c = callSession; if (!c) return;
    const lines = c.merged ? c.lines : [c.lines[c.active]];
    for (const line of lines) if (!line.ended) {line.ended=true;line.seconds=line.connected ? Math.min(359999,Math.floor((Date.now()-line.connected)/1000)) : 0;}
    try {
      const records = lines.map(line=>{const contact=data.contacts.find(v=>v.id===line.contactID);return J.call({id:line.id,phoneNumber:line.number,label:contact?.label || '手机',date:new Date(line.started).toISOString(),durationSeconds:line.seconds,direction:line.connected ? 'outgoing' : 'cancelled',...(contact ? {contactID:contact.id} : line.name!==line.number ? {nameOverride:line.name} : {})});});
      commit(next => {records.forEach(record=>J.upsert(next,'calls',record));});
      c.lines=c.lines.filter(v=>!lines.includes(v));
      if (c.lines.length) {c.active=0;c.hold=false;c.merged=false;renderCall();}
      else {c.finished=true;clearInterval(c.interval);phone.querySelector('.call-layer')?.remove();phone.querySelector('.call-picker-shade')?.remove();phone.classList.remove('in-call');callSession=null;render();}
    } catch (error) { alertMessage('未能保存通话',error.message + ' 请处理后再次点按结束通话。'); }
  }
  function renderSettings() {
    const p = data.preferences;
    screen.innerHTML = `<div class="grouped">${toolbar(btn('back',icon('back')+'返回'),'设置与备份','')}` + section('显示',`<div class="card-row"><span>布局</span><select id="setting-layout" aria-label="布局" style="margin-left:auto;border:0;background:none;color:var(--blue)"><option value="classic"${p.layout === 'classic' ? ' selected' : ''}>经典</option><option value="unified"${p.layout === 'unified' ? ' selected' : ''}>统一</option></select></div><div class="card-row"><span>外观</span><select id="setting-appearance" aria-label="外观" style="margin-left:auto;border:0;background:none;color:var(--blue)">${[['light','浅色'],['dark','深色'],['system','跟随系统']].map(([k,v]) => `<option value="${k}"${p.appearance === k ? ' selected' : ''}>${v}</option>`).join('')}</select></div>`) + section('备份',btn('export','导出备份'+`<span class="trailing">${icon('download')}</span>`,'','card-row') + btn('import','导入备份'+`<span class="trailing">${icon('upload')}</span>`,'','card-row') + (rawUnreadable ? btn('export-raw','导出原始数据','','card-row red') : '')) + `<p class="settings-note">${data.contacts.length} 个联系人，${data.calls.length} 条通话。内容保存在本机浏览器中；请定期导出备份。</p>` + section('',btn('clear-calls','清空最近通话','','card-row red')) + '<input id="import-file" type="file" accept=".json,application/json" hidden></div>';
  }
  function download(value, filename) {
    const blob = new Blob([typeof value === 'string' ? value : JSON.stringify(value,null,2)],{type:'application/json'}), url = URL.createObjectURL(blob), link = document.createElement('a');
    link.href = url; link.download = filename; document.body.append(link); link.click(); link.remove(); setTimeout(() => URL.revokeObjectURL(url),1000);
  }
  async function importFile(file) {
    if (!file) return;
    try {
      if (file.size > 10 * 1024 * 1024) throw Error('备份文件不能超过 10 MB。');
      const value = J.archive(JSON.parse(await file.text()));
      confirmation(`导入备份将替换当前的 ${data.contacts.length} 个联系人和 ${data.calls.length} 条通话。备份含 ${value.contacts.length} 个联系人、${value.calls.length} 条通话。`,'导入并替换',() => {
        try { commit(() => value,true); ui.detail = null; render(); notify('备份已导入'); } catch (error) { alertMessage('导入失败',error.message); }
      });
    } catch (error) { alertMessage('导入失败',error instanceof SyntaxError ? '文件不是有效的 JSON 备份。' : error.message); }
  }
  async function copyNumber(value) {
    try { if (!navigator.clipboard?.writeText) throw Error(); await navigator.clipboard.writeText(value); notify('号码已复制'); }
    catch (_) { alertMessage('电话号码','长按下面的号码即可复制。',`<input class="copy-input" aria-label="可复制的电话号码" readonly value="${esc(value)}">`); phone.querySelector('.copy-input')?.select(); }
  }
  function findCall(id) { return data.calls.find(v => v.id === id); }
  function findContact(id) { return data.contacts.find(v => v.id === id); }
  const actions = {
    tab: id => setTab(id),
    all: () => {ui.missed=false;render();}, missed: () => {ui.missed=true;render();},
    'clear-query': () => {ui.query='';render();screen.querySelector('#search')?.focus();},
    'edit-list': () => {ui.edit=!ui.edit;render();},
    menu: () => {ui.menu=!ui.menu;render();},
    'layout-classic': () => {ui.menu=false;perform(next => {next.preferences.layout='classic';});},
    'layout-unified': () => {ui.menu=false;perform(next => {next.preferences.layout='unified';});},
    settings: () => {ui.settings=true;ui.menu=false;overlay.innerHTML='';render();screen.scrollTop=0;},
    back: () => {ui.detail=null;ui.settings=false;render();screen.scrollTop=0;},
    'add-call': () => openCallEditor(),
    'edit-call': id => {const c=findCall(id);if(c)openCallEditor(c);},
    'detail-call': id => showDetail('call',id),
    'call-record': id => {const c=findCall(id);if(c)startCall(c.phoneNumber,J.displayName(data,c),c.contactID);},
    'duplicate-call': id => {const c=findCall(id);if(c)openCallEditor({...c,id:J.id(),date:new Date().toISOString()});},
    'delete-call': id => confirmation('删除这条通话记录？','删除通话',() => perform(next => {next.calls=next.calls.filter(c=>c.id!==id);})),
    'clear-calls': () => confirmation('清空所有最近通话？联系人会保留。此操作无法撤销。','清空所有通话',() => {ui.menu=false;perform(next=>{next.calls=[];});}),
    'add-contact': () => openContactEditor(),
    'edit-contact': id => {const c=findContact(id);if(c)openContactEditor(c);},
    'detail-contact': id => showDetail('contact',id),
    'call-contact': id => {const c=findContact(id);if(c)startCall(c.phoneNumber,c.name,c.id);},
    'delete-contact': id => confirmation('删除联系人？已有通话记录的姓名和号码会保留。','删除联系人',() => perform(next=>J.deleteContact(next,id))),
    'toggle-favorite': id => perform(next=>{const c=next.contacts.find(v=>v.id===id);if(c)c.isFavorite=!c.isFavorite;}),
    'remove-favorite': id => perform(next=>{const c=next.contacts.find(v=>v.id===id);if(c)c.isFavorite=false;}),
    'pick-favorite': picker,
    'select-favorite': id => {if(perform(next=>{const c=next.contacts.find(v=>v.id===id);if(c)c.isFavorite=true;}))closeSheet(true);},
    'new-favorite': () => openContactEditor({id:J.id(),name:'',phoneNumber:'',label:'手机',isFavorite:true}),
    'add-linked-call': id => {const c=findContact(id);if(c)openCallEditor({id:J.id(),contactID:c.id,phoneNumber:c.phoneNumber,label:c.label,date:new Date().toISOString(),durationSeconds:60,direction:'incoming'});},
    'contact-from-call': id => {const c=findCall(id);if(c)openContactEditor({id:J.id(),name:c.nameOverride || '',phoneNumber:c.phoneNumber,label:c.label,isFavorite:false},(next,saved)=>{const r=next.calls.find(v=>v.id===id);if(r){r.contactID=saved.id;delete r.nameOverride;}});},
    'contact-from-dial': () => openContactEditor({id:J.id(),name:'',phoneNumber:ui.dial,label:'手机',isFavorite:false}),
    'copy-number': copyNumber,
    digit: value => {if(ui.dial.length<64)ui.dial+=value;renderKeypad();},
    backspace: () => {ui.dial=ui.dial.slice(0,-1);renderKeypad();},
    dial: () => {if(!ui.dial){const last=J.sorted(data).find(c=>c.direction==='outgoing'||c.direction==='cancelled');if(last){ui.dial=last.phoneNumber;renderKeypad();}return;}startCall(ui.dial);},
    'close-sheet': () => closeSheet(),
    'save-sheet': saveSheet,
    'confirm-no': closeConfirm,
    'confirm-yes': () => {const action=confirmAction;closeConfirm();action?.();},
    'alert-close': () => phone.querySelector('.alert-shade')?.remove(),
    export: () => download(data,`电话备份-${new Date().toISOString().slice(0,10)}.json`),
    'export-raw': () => download(rawUnreadable,'电话原始数据.json'),
    import: () => screen.querySelector('#import-file')?.click(),
    mute: () => {if(callSession){callSession.mute=!callSession.mute;renderCall();}},
    speaker: () => {if(callSession){callSession.speaker=!callSession.speaker;renderCall();}},
    hold: () => {if(callSession){callSession.hold=!callSession.hold;renderCall();}},
    'call-keypad': () => {if(callSession){callSession.keypad=true;renderCall();}},
    'hide-call-keypad': () => {if(callSession){callSession.keypad=false;renderCall();}},
    'call-digit': digit => {if(callSession && callSession.digits.length<64){callSession.digits+=digit;phone.querySelector('#call-digits').textContent=callSession.digits;}},
    'call-add': () => openCallPicker(),
    'call-contacts': () => openCallPicker(true),
    'show-number-call': () => openCallPicker(),
    'close-call-picker': () => phone.querySelector('.call-picker-shade')?.remove(),
    'add-number-call': () => addLocalLine(phone.querySelector('#second-call-number').value),
    'add-contact-call': id => {const contact=findContact(id);if(contact)addLocalLine(contact.phoneNumber,contact.name,contact.id);},
    'swap-call': () => {if(callSession?.lines.length===2){callSession.active=1-callSession.active;callSession.hold=false;renderCall();}},
    'merge-call': () => {if(callSession?.lines.length===2){callSession.merged=true;callSession.hold=false;renderCall();}},
    hangup
  };
  phone.addEventListener('click', event => {
    const button = event.target.closest('[data-action]');
    if (button && !button.disabled) { const action=actions[button.dataset.action]; if(action)action(button.dataset.id); }
    else if (ui.menu && !event.target.closest('.more-menu')) {ui.menu=false;overlay.innerHTML='';}
  });
  phone.addEventListener('submit',event=>{event.preventDefault();saveSheet();});
  phone.addEventListener('input',event=>{
    if(event.target.id==='search'){ui.query=event.target.value;if(ui.tab==='contacts')renderContactRows();else renderRecentRows();}
    if(sheet?.kind==='contact' && event.target.name==='name'){const a=overlay.querySelector('.avatar');if(a)a.textContent=Array.from(event.target.value)[0] || '人';}
  });
  phone.addEventListener('change',event=>{
    if(event.target.id==='import-file'){importFile(event.target.files[0]);event.target.value='';}
    if(event.target.id==='setting-layout'){const value=event.target.value;perform(next=>{next.preferences.layout=value;});}
    if(event.target.id==='setting-appearance'){const value=event.target.value;perform(next=>{next.preferences.appearance=value;});}
    if(sheet?.kind==='call' && event.target.name==='direction')updateDurationEnabled();
    if(sheet?.kind==='call' && event.target.name==='contactID'){
      const c=findContact(event.target.value), form=overlay.querySelector('#editor');
      if(c){form.elements.phoneNumber.value=c.phoneNumber;form.elements.label.value=c.label;form.elements.nameOverride.value='';form.elements.nameOverride.placeholder='使用联系人姓名';}
      else form.elements.nameOverride.placeholder='选填';
    }
  });
  phone.addEventListener('contextmenu',event=>{
    const row=event.target.closest('[data-call-id]');if(!row)return;event.preventDefault();
    const id=row.dataset.callId;
    confirmation('通话记录','编辑通话',()=>actions['edit-call'](id));
  });
  document.addEventListener('keydown',event=>{
    if(event.key==='Escape'){
      if(phone.querySelector('.alert-shade'))phone.querySelector('.alert-shade').remove();
      else if(confirmAction)closeConfirm();else if(phone.querySelector('.call-picker-shade'))phone.querySelector('.call-picker-shade').remove();else if(sheet)closeSheet();else if(ui.menu){ui.menu=false;overlay.innerHTML='';}
      else if(ui.detail||ui.settings)actions.back();
    }
    if(event.key==='Tab'){
      const top=phone.querySelector('.alert-shade')||phone.querySelector('.confirm-shade')||phone.querySelector('.call-picker-shade .sheet')||phone.querySelector('.sheet')||phone.querySelector('.call-layer');
      if(top){const focusable=[...top.querySelectorAll('button,input,select')].filter(v=>!v.disabled && !v.hidden && v.offsetParent !== null),first=focusable[0],last=focusable.at(-1);if(event.shiftKey&&document.activeElement===first){last?.focus();event.preventDefault();}else if(!event.shiftKey&&document.activeElement===last){first?.focus();event.preventDefault();}}
    }
    if(ui.tab==='keypad'&&!sheet&&!ui.detail&&!ui.settings&&!callSession&&!phone.querySelector('.alert-shade')){
      if(/^[0-9*#+]$/.test(event.key)){event.preventDefault();actions.digit(event.key);}
      else if(event.key==='Backspace'){event.preventDefault();actions.backspace();}
    }
  });
  let zeroHoldTimer, heldZero=false;
  phone.addEventListener('pointerdown',event=>{const b=event.target.closest('[data-action="digit"][data-id="0"]');if(b){heldZero=false;zeroHoldTimer=setTimeout(()=>{heldZero=true;if(ui.dial.length<64){ui.dial+='+';renderKeypad();}},550);}});
  phone.addEventListener('pointerup',()=>clearTimeout(zeroHoldTimer));
  phone.addEventListener('pointercancel',()=>clearTimeout(zeroHoldTimer));
  phone.addEventListener('click',event=>{if(heldZero&&event.target.closest('[data-action="digit"][data-id="0"]')){heldZero=false;event.stopImmediatePropagation();}},true);
  window.addEventListener('storage',event=>{
    if(event.key!==KEY)return;
    if(sheet||callSession){notify('另一窗口更新了数据，请完成当前操作后刷新');return;}
    try{data=event.newValue ? J.archive(JSON.parse(event.newValue)) : J.empty();storedSnapshot=event.newValue;render();}catch(_){notify('另一窗口的数据无法读取');}
  });
  window.addEventListener('beforeunload',event=>{if(sheet && sheet.kind!=='picker' && serializeForm()!==sheet.original || callSession){event.preventDefault();event.returnValue='';}});
  const clock=()=>{document.getElementById('status-time').textContent=new Date().toLocaleTimeString('zh-CN',{hour:'numeric',minute:'2-digit',hour12:false});};
  clock();setInterval(clock,30000);render();if(startupError)setTimeout(()=>alertMessage('本地数据',startupError),100);
})();
