/* The archive uses the same fields and ISO-8601 dates as the native app. */
(function (scope) {
  'use strict';
  const directions = { incoming: '来电', outgoing: '去电', missed: '未接来电', cancelled: '已取消' };
  const empty = () => ({ schemaVersion: 1, contacts: [], calls: [], preferences: { layout: 'classic', appearance: 'light' } });
  const id = () => typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => { const n = Math.random() * 16 | 0; return (c === 'x' ? n : n & 3 | 8).toString(16); });
  const clean = v => typeof v === 'string' ? v.trim() : '';
  const digits = v => clean(v).replace(/[^0-9*#]/g, '');
  const uuid = v => typeof v === 'string' && /^[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}$/i.test(v);
  function number(v) {
    v = clean(v);
    if (!v || v.length > 64 || !/[0-9]/.test(v) || !/^\+?[0-9*#()\- \u00a0]+$/.test(v)) throw Error('请输入有效的电话号码。号码可包含数字、开头的 +、空格、括号、短横线、* 和 #。');
    return v;
  }
  function contact(value) {
    if (!value || !uuid(value.id)) throw Error('联系人 ID 不正确。');
    const name = clean(value.name), label = clean(value.label) || '手机';
    if (!name || name.length > 200 || label.length > 40) throw Error('请输入联系人姓名，姓名最多 200 字、标签最多 40 字。');
    if (typeof value.isFavorite !== 'boolean') throw Error('联系人收藏状态不正确。');
    return { id: value.id.toLowerCase(), name, phoneNumber: number(value.phoneNumber), label, isFavorite: value.isFavorite };
  }
  function call(value, normalize = true) {
    if (!value || !uuid(value.id) || !Object.hasOwn(directions,value.direction)) throw Error('通话记录格式不正确。');
    if (value.contactID != null && !uuid(value.contactID)) throw Error('通话关联的联系人 ID 不正确。');
    if (value.nameOverride != null && typeof value.nameOverride !== 'string') throw Error('通话姓名格式不正确。');
    if (typeof value.date !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2})$/.test(value.date)) throw Error('通话日期格式不正确。');
    const date = new Date(value.date), duration = value.durationSeconds, name = clean(value.nameOverride), label = clean(value.label) || '手机';
    if (!Number.isInteger(duration) || duration < 0 || duration > 359999) throw Error('通话时长应在 0 秒至 99 小时 59 分 59 秒之间。');
    if (!Number.isFinite(date.valueOf()) || date.valueOf() < -2208988800000 || date.valueOf() >= 7258118400000) throw Error('日期应在 1900 年至 2199 年之间。');
    date.setMilliseconds(0);
    if (name.length > 200 || label.length > 40) throw Error('姓名或号码标签过长。');
    const unanswered = ['missed', 'cancelled'].includes(value.direction);
    if (unanswered && !normalize && duration !== 0) throw Error('未接或已取消通话的时长必须是 0 秒。');
    return { id: value.id.toLowerCase(), ...(value.contactID ? { contactID: value.contactID.toLowerCase() } : {}), ...(name ? { nameOverride: name } : {}), phoneNumber: number(value.phoneNumber), label, date: date.toISOString(), durationSeconds: unanswered ? 0 : duration, direction: value.direction };
  }
  function archive(value) {
    if (!value || value.schemaVersion !== 1 || !Array.isArray(value.contacts) || !Array.isArray(value.calls)) throw Error('无法读取备份：文件格式不正确或版本不受支持。');
    if (value.contacts.length > 5000 || value.calls.length > 50000) throw Error('最多支持 5,000 个联系人和 50,000 条通话记录。');
    const contacts = value.contacts.map(contact), calls = value.calls.map(v => call(v, false));
    const contactsSet = new Set(contacts.map(v => v.id));
    if (contactsSet.size !== contacts.length || new Set(calls.map(v => v.id)).size !== calls.length) throw Error('备份中有重复的记录 ID。');
    if (calls.some(v => v.contactID && !contactsSet.has(v.contactID))) throw Error('备份中有找不到对应联系人的通话记录。');
    if (!value.preferences || !['classic','unified'].includes(value.preferences.layout) || !['light','dark','system'].includes(value.preferences.appearance)) throw Error('备份的界面设置不正确。');
    return { schemaVersion: 1, contacts, calls, preferences: { layout:value.preferences.layout,appearance:value.preferences.appearance } };
  }
  function displayName(a, c) { return c.nameOverride || a.contacts.find(v => v.id === c.contactID)?.name || c.phoneNumber; }
  function deleteContact(a, cid) {
    a.calls.filter(v => v.contactID === cid).forEach(v => { v.nameOverride = displayName(a, v); delete v.contactID; });
    a.contacts = a.contacts.filter(v => v.id !== cid);
  }
  function upsert(a, field, v) { const n = a[field].findIndex(c => c.id === v.id); if (n < 0) a[field].push(v); else a[field][n] = v; }
  function sorted(a) { return [...a.calls].sort((x,y) => Date.parse(y.date) - Date.parse(x.date) || x.id.localeCompare(y.id)); }
  function matching(a, query, missedOnly) {
    const q = clean(query).toLocaleLowerCase(), n = /^\+?[0-9*#()\- \u00a0]+$/.test(q) ? digits(q) : '';
    return sorted(a).filter(v => (!missedOnly || v.direction === 'missed') && (!q || displayName(a,v).toLocaleLowerCase().includes(q) || v.phoneNumber.includes(q) || n && digits(v.phoneNumber).includes(n)));
  }
  function duration(seconds) { const h = seconds / 3600 | 0, m = seconds % 3600 / 60 | 0, s = seconds % 60; return h ? `${h} 小时 ${m} 分 ${s} 秒` : m ? `${m} 分 ${s} 秒` : `${s} 秒`; }
  function timer(seconds) { const h = seconds / 3600 | 0, m = seconds % 3600 / 60 | 0, s = seconds % 60; return (h ? h + ':' : '') + String(h ? m : seconds / 60 | 0).padStart(2,'0') + ':' + String(s).padStart(2,'0'); }
  function recent(date, now = new Date()) {
    const d = new Date(date), day = v => new Date(v.getFullYear(), v.getMonth(), v.getDate()).valueOf(), diff = (day(now) - day(d)) / 86400000;
    if (diff === 0) return d.toLocaleTimeString('zh-CN', {hour: '2-digit', minute: '2-digit', hour12: false});
    if (diff === 1) return '昨天';
    if (diff > 1 && diff < 6) return d.toLocaleDateString('zh-CN', { weekday: 'long' });
    return `${d.getFullYear() === now.getFullYear() ? '' : d.getFullYear() + '/'}${d.getMonth()+1}/${d.getDate()}`;
  }
  const api = { directions, empty, id, clean, digits, number, contact, call, archive, displayName, deleteContact, upsert, sorted, matching, duration, timer, recent };
  scope.Journal = api;
  if (typeof module !== 'undefined') module.exports = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
