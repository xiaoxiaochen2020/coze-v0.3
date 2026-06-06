// =============================================================
// My Agent WebUI v0.3.1
// 修复：v0.3.1 modal [hidden] 用 [hidden] CSS 规则 + ESC 关闭 + api() 错误带 statusText
// =============================================================

const $  = (s) => document.querySelector(s);
const $$ = (s) => document.querySelectorAll(s);
const API = "";   // 同源
let PROVIDERS = {};   // { deepseek: {name, base_url, default_model}, ... }
let CATEGORIES = [];  // sidebar 6 项
let PROJECTS = [];    // 全部项目
let APIKEYS = [];     // 全部 Key（脱敏）
let CURRENT_CHAT_PROJECT = null;  // 当前聊天项目 id

// ====== 工具函数 ======
const PROVIDER_COLORS = {
  deepseek: "#4F46E5",
  qwen:     "#EA580C",
  glm:      "#0EA5E9",
  kimi:     "#111827",
  openai:   "#10A981",
};
const PROVIDER_ICONS = {
  deepseek: "DS",
  qwen:     "千",
  glm:      "智",
  kimi:     "K",
  openai:   "AI",
};
const PROJECT_COLORS = ["#7C3AED","#3B82F6","#EA580C","#10A981","#0EA5E9","#F59E0B","#EC4899","#6366F1"];
function projectColor(name) {
  let h = 0;
  for (let i=0;i<name.length;i++) h = (h*31 + name.charCodeAt(i)) & 0xffff;
  return PROJECT_COLORS[h % PROJECT_COLORS.length];
}
function projectIcon(name) { return (name||"?").slice(0,1).toUpperCase(); }
function fmtTime(iso) {
  if (!iso) return "";
  const d = new Date(iso);
  const now = new Date();
  const diff = (now - d) / 1000;
  if (diff < 60) return "刚刚";
  if (diff < 3600) return Math.floor(diff/60) + " 分钟前";
  if (diff < 86400) return Math.floor(diff/3600) + " 小时前";
  return d.getMonth()+1 + "-" + d.getDate();
}

async function api(path, opts={}) {
  const r = await fetch(API + path, {
    headers: {"Content-Type": "application/json"},
    ...opts,
  });
  if (!r.ok) {
    let detail = "";
    try { detail = (await r.text()).slice(0, 200); } catch {}
    throw new Error(`HTTP ${r.status} ${r.statusText}${detail ? " — " + detail : ""}`);
  }
  return r.json();
}

// ESC 关闭所有 modal
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") {
    for (const m of $$(".modal")) m.hidden = true;
  }
});
// 点遮罩关闭 modal
for (const m of $$(".modal")) {
  m.addEventListener("click", (e) => { if (e.target === m) m.hidden = true; });
}

// =============================================================
// ① 顶栏：折叠 + 搜索
// =============================================================
$("#btn-fold").onclick = () => $("#sidebar").classList.toggle("collapsed");

const SEARCH = $("#search");
SEARCH.addEventListener("input", () => {
  // v0.3 占位：搜索项目名 / 描述 / Key 名
  const q = SEARCH.value.toLowerCase().trim();
  if (!q) return;
  // 不切换视图，只在当前视图过滤
});
SEARCH.addEventListener("keydown", (e) => {
  if (e.key === "Enter") { e.preventDefault(); doSearch(); }
});
window.addEventListener("keydown", (e) => {
  if ((e.metaKey || e.ctrlKey) && e.key === "k") {
    e.preventDefault();
    SEARCH.focus();
  }
});
function doSearch() {
  const q = SEARCH.value.toLowerCase().trim();
  if (!q) return;
  // 简化：跳到项目页 + 过滤
  showView("projects");
  for (const card of $$("#grid .card")) {
    const name = (card.dataset.name||"").toLowerCase();
    const desc = (card.dataset.desc||"").toLowerCase();
    card.style.display = (name.includes(q) || desc.includes(q)) ? "" : "none";
  }
}

// =============================================================
// 视图切换
// =============================================================
function showView(name) {
  for (const v of ["welcome","projects","placeholder","apikeys","chat"]) {
    $("#view-" + v).hidden = (v !== name);
  }
  // sidebar 选中态
  for (const it of $$(".sb-nav-item")) it.classList.remove("active");
  for (const p of $$(".sb-proj")) p.classList.remove("active");
  if (name === "projects") {} // 项目点击时单独 active
  if (name === "apikeys") {
    const item = $$(".sb-nav-item").find(i => i.dataset.cat === "apikeys");
    if (item) item.classList.add("active");
  }
  if (name === "welcome") {
    setStatus("就绪");
  }
}

// =============================================================
// ② 侧栏：渲染
// =============================================================
async function renderSidebar() {
  // 1) 工作空间项目列表
  const projEl = $("#sb-projects");
  projEl.innerHTML = "";
  for (const p of PROJECTS) {
    const c = projectColor(p.name);
    const div = document.createElement("div");
    div.className = "sb-proj";
    div.dataset.pid = p.id;
    div.innerHTML = `
      <div class="sb-proj-ico" style="background:${c}">${projectIcon(p.name)}</div>
      <div class="sb-proj-name">${esc(p.name)}</div>
    `;
    div.onclick = () => openChat(p.id);
    projEl.appendChild(div);
  }
  // + 创建新项目
  const create = document.createElement("div");
  create.className = "sb-create";
  create.innerHTML = `<span class="sb-create-plus">+</span> 创建新项目`;
  create.onclick = () => openCreateModal();
  projEl.appendChild(create);

  // 2) 我的分类
  const navEl = $("#sb-nav");
  navEl.innerHTML = "";
  for (const c of CATEGORIES) {
    const div = document.createElement("div");
    div.className = "sb-nav-item";
    div.dataset.cat = c.key;
    div.innerHTML = `<span class="sb-ico">${c.ico}</span><span>${esc(c.label)}</span>`;
    div.onclick = () => {
      if (c.key === "apikeys") {
        showView("apikeys");
        renderApikeys();
      } else {
        $("#ph-title").textContent = c.label;
        $("#ph-sub").textContent = "（v0.3 占位）";
        showView("placeholder");
      }
    };
    navEl.appendChild(div);
  }
}

// =============================================================
// 欢迎页：输入 + chip
// =============================================================
$("#welcome-send").onclick = () => doWelcomeSend();
$("#welcome-text").addEventListener("keydown", (e) => {
  if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); doWelcomeSend(); }
});
function doWelcomeSend() {
  const text = $("#welcome-text").value.trim();
  if (!text) return;
  // 简化：直接建项目"我的对话"+ 发消息
  api("/api/projects", {
    method: "POST",
    body: JSON.stringify({name: "我的对话", description: text.slice(0, 30), api_key_id: ""}),
  }).then(p => {
    PROJECTS.push(p);
    renderSidebar();
    return openChat(p.id, text);
  }).catch(err => alert("创建失败：" + err.message));
}
for (const chip of $$(".chip")) {
  chip.onclick = () => {
    $("#welcome-text").value = chip.dataset.prompt;
    $("#welcome-text").focus();
  };
}

// =============================================================
// 项目页
// =============================================================
$("#btn-create").onclick = () => openCreateModal();

function renderProjects() {
  $("#proj-count").textContent = PROJECTS.length;
  const grid = $("#grid");
  grid.innerHTML = "";
  if (PROJECTS.length === 0) {
    grid.innerHTML = `
      <div class="card card-empty">
        <div class="card-empty-ico">📂</div>
        <div class="card-empty-text">还没有项目<br><span class="muted">点侧栏「+ 创建新项目」开始</span></div>
      </div>`;
    return;
  }
  for (const p of PROJECTS) {
    const c = projectColor(p.name);
    const keyName = p.api_key_id ? (APIKEYS.find(k=>k.id===p.api_key_id)?.name || "已失效 Key") : "OpenClaw";
    const div = document.createElement("div");
    div.className = "card";
    div.dataset.name = p.name;
    div.dataset.desc = p.description || "";
    div.innerHTML = `
      <div class="card-ico" style="background:${c}">${projectIcon(p.name)}</div>
      <div class="card-name">${esc(p.name)}</div>
      <div class="card-desc">${esc(p.description || "（无描述）")}</div>
      <div class="card-badge">${esc(keyName)}</div>
    `;
    div.onclick = () => openChat(p.id);
    grid.appendChild(div);
  }
}

// =============================================================
// 弹窗：新建项目
// =============================================================
function openCreateModal() {
  // 刷新 Key 下拉
  const sel = $("#f-api-key");
  sel.innerHTML = `<option value="">OpenClaw 默认（gpt-5.5）</option>`;
  for (const k of APIKEYS) {
    if (!k.enabled) continue;
    const opt = document.createElement("option");
    opt.value = k.id;
    opt.textContent = `${k.name} · ${PROVIDERS[k.provider]?.name || k.provider}`;
    sel.appendChild(opt);
  }
  $("#f-name").value = "";
  $("#f-desc").value = "";
  $("#modal-create").hidden = false;
  setTimeout(() => $("#f-name").focus(), 50);
}
$("#btn-cancel").onclick = () => $("#modal-create").hidden = true;
$("#btn-submit").onclick = () => {
  const name = $("#f-name").value.trim();
  if (!name) { alert("项目名不能为空"); return; }
  const desc = $("#f-desc").value.trim();
  const api_key_id = $("#f-api-key").value;
  api("/api/projects", {
    method: "POST",
    body: JSON.stringify({name, description: desc, api_key_id}),
  }).then(p => {
    PROJECTS.push(p);
    renderSidebar();
    $("#modal-create").hidden = true;
    showView("projects");
    renderProjects();
    setStatus(`已创建项目「${p.name}」`);
  }).catch(err => alert("创建失败：" + err.message));
};

// =============================================================
// 聊天页
// =============================================================
$("#btn-back").onclick = () => { showView("projects"); renderProjects(); };
$("#btn-send").onclick = () => doChatSend();
$("#chat-text").addEventListener("keydown", (e) => {
  if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); doChatSend(); }
});
$("#btn-bind-key").onclick = () => openBindModal();

function openChat(pid, initialText="") {
  const p = PROJECTS.find(x => x.id === pid);
  if (!p) return;
  CURRENT_CHAT_PROJECT = pid;
  $("#chat-title").textContent = p.name;
  // sidebar active
  for (const it of $$(".sb-proj")) it.classList.toggle("active", it.dataset.pid === pid);
  // backend
  const k = p.api_key_id ? APIKEYS.find(x=>x.id===p.api_key_id) : null;
  $("#chat-backend").textContent = k ? `🔑 ${k.name}` : "OpenClaw 默认";
  // messages
  const body = $("#chat-body");
  body.innerHTML = "";
  const msgs = p.messages || [];
  for (const m of msgs) body.appendChild(renderMsg(m));
  body.scrollTop = body.scrollHeight;
  showView("chat");
  $("#chat-text").focus();
  if (initialText) {
    $("#chat-text").value = initialText;
    doChatSend();
  }
}

function renderMsg(m) {
  const div = document.createElement("div");
  div.className = "chat-msg " + m.role;
  div.innerHTML = `
    <div class="chat-msg-avatar">${m.role === "user" ? "我" : "AI"}</div>
    <div class="chat-msg-bubble">${esc(m.content)}</div>
  `;
  return div;
}

function doChatSend() {
  const text = $("#chat-text").value.trim();
  if (!text) return;
  const pid = CURRENT_CHAT_PROJECT;
  if (!pid) return;
  $("#chat-text").value = "";
  // 乐观追加用户消息
  const body = $("#chat-body");
  const userMsg = {role:"user", content:text, ts:new Date().toISOString()};
  body.appendChild(renderMsg(userMsg));
  body.scrollTop = body.scrollHeight;
  // 占位 AI 消息
  const placeholder = document.createElement("div");
  placeholder.className = "chat-msg assistant";
  placeholder.innerHTML = `<div class="chat-msg-avatar">AI</div><div class="chat-msg-bubble"><span class="muted">思考中...</span></div>`;
  body.appendChild(placeholder);
  body.scrollTop = body.scrollHeight;
  setStatus("调用模型中...");
  api(`/api/projects/${pid}/chat`, {
    method: "POST",
    body: JSON.stringify({message: text}),
  }).then(resp => {
    placeholder.querySelector(".chat-msg-bubble").textContent = resp.reply || "（无回复）";
    // 保存到本地
    const p = PROJECTS.find(x => x.id === pid);
    if (p) p.messages = resp.messages || p.messages;
    body.scrollTop = body.scrollHeight;
    setStatus("就绪");
  }).catch(err => {
    placeholder.querySelector(".chat-msg-bubble").innerHTML = `<span style="color:#DC2626">错误：${esc(err.message)}</span>`;
    setStatus("出错");
  });
}

// =============================================================
// 弹窗：切换项目模型
// =============================================================
function openBindModal() {
  const pid = CURRENT_CHAT_PROJECT;
  if (!pid) return;
  const p = PROJECTS.find(x => x.id === pid);
  if (!p) return;
  $("#bind-proj").textContent = p.name;
  const sel = $("#bf-key");
  sel.innerHTML = `<option value="">OpenClaw 默认（gpt-5.5）</option>`;
  for (const k of APIKEYS) {
    if (!k.enabled) continue;
    const opt = document.createElement("option");
    opt.value = k.id;
    opt.textContent = `${k.name} · ${PROVIDERS[k.provider]?.name || k.provider}`;
    if (k.id === p.api_key_id) opt.selected = true;
    sel.appendChild(opt);
  }
  $("#modal-bind").hidden = false;
}
$("#bf-cancel").onclick = () => $("#modal-bind").hidden = true;
$("#bf-save").onclick = () => {
  const pid = CURRENT_CHAT_PROJECT;
  const api_key_id = $("#bf-key").value;
  api(`/api/projects/${pid}`, {
    method: "PUT",
    body: JSON.stringify({api_key_id}),
  }).then(p => {
    const i = PROJECTS.findIndex(x => x.id === pid);
    if (i >= 0) PROJECTS[i] = p;
    $("#modal-bind").hidden = true;
    openChat(pid);
    setStatus("已切换模型");
  }).catch(err => alert("切换失败：" + err.message));
};

// =============================================================
// 第三方 API 设置
// =============================================================
$("#btn-add-key").onclick = () => openKeyModal(null);
$("#lnk-api-help").onclick = (e) => {
  e.preventDefault();
  alert("在「第三方 API 设置」里加 Key（DeepSeek / 通义 / GLM / Kimi / OpenAI），\n然后在新建项目时绑定 Key，\n该项目对话就由该 LLM 处理。\n不绑 Key 默认走 OpenClaw（gpt-5.5）。");
};

async function renderApikeys() {
  const data = await api("/api/keys");
  APIKEYS = data.keys || [];
  $("#api-count").textContent = `共 ${APIKEYS.length} 条`;
  const tbody = $("#api-tbody");
  tbody.innerHTML = "";
  if (APIKEYS.length === 0) {
    tbody.innerHTML = `<tr><td colspan="5" style="text-align:center;color:#9CA3AF;padding:30px">还没有 API Key，点右上「+ 添加 API」开始</td></tr>`;
    return;
  }
  for (const k of APIKEYS) {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${esc(k.name)}</td>
      <td>${esc(PROVIDERS[k.provider]?.name || k.provider)}</td>
      <td class="api-key-mono">${esc(k.key_masked)}</td>
      <td><span class="status-pill ${k.enabled?"on":"off"}">${k.enabled?"启用":"停用"}</span></td>
      <td>
        <div class="row-actions">
          <button data-act="edit" data-id="${k.id}">修改</button>
          <button data-act="toggle" data-id="${k.id}">${k.enabled?"停用":"启用"}</button>
          <button data-act="del" data-id="${k.id}" class="danger">删除</button>
        </div>
      </td>
    `;
    tbody.appendChild(tr);
  }
  for (const btn of $$("#api-tbody button")) {
    btn.onclick = () => {
      const act = btn.dataset.act, id = btn.dataset.id;
      if (act === "edit") openKeyModal(id);
      else if (act === "toggle") toggleKey(id);
      else if (act === "del") delKey(id);
    };
  }
}

async function toggleKey(id) {
  await api(`/api/keys/${id}`, {method:"PUT", body: JSON.stringify({toggle: true})});
  await renderApikeys();
  setStatus("已切换状态");
}
async function delKey(id) {
  if (!confirm("确定删除？引用此 Key 的项目会自动改回 OpenClaw 默认。")) return;
  await api(`/api/keys/${id}`, {method:"DELETE"});
  await renderApikeys();
  await refreshProjects();
  setStatus("已删除 Key");
}

// =============================================================
// 弹窗：添加/修改 API Key
// =============================================================
let KEY_EDIT_ID = null;
function openKeyModal(id) {
  KEY_EDIT_ID = id;
  $("#key-modal-title").textContent = id ? "修改 API" : "添加 API";
  // 渲染服务商下拉
  const sel = $("#kf-provider");
  sel.innerHTML = "";
  for (const [key, val] of Object.entries(PROVIDERS)) {
    const opt = document.createElement("option");
    opt.value = key;
    opt.textContent = val.name;
    sel.appendChild(opt);
  }
  if (id) {
    const k = APIKEYS.find(x => x.id === id);
    if (k) {
      $("#kf-name").value = k.name;
      $("#kf-provider").value = k.provider;
      $("#kf-key").value = "";  // 不显示明文
      $("#kf-key").placeholder = "（保持不变则留空）";
    }
  } else {
    $("#kf-name").value = "";
    $("#kf-provider").value = "deepseek";
    $("#kf-key").value = "";
    $("#kf-key").placeholder = "sk-...";
  }
  $("#kf-test-result").hidden = true;
  $("#modal-key").hidden = false;
  setTimeout(() => $("#kf-name").focus(), 50);
}
$("#kf-cancel").onclick = () => $("#modal-key").hidden = true;
$("#kf-save").onclick = async () => {
  const name = $("#kf-name").value.trim();
  const provider = $("#kf-provider").value;
  const key = $("#kf-key").value;
  if (!name) { alert("API 名称不能为空"); return; }
  if (!KEY_EDIT_ID && !key) { alert("API Key 不能为空"); return; }
  const body = {name, provider, enabled: true};
  if (key) body.key = key;
  try {
    if (KEY_EDIT_ID) {
      await api(`/api/keys/${KEY_EDIT_ID}`, {method:"PUT", body: JSON.stringify(body)});
    } else {
      await api("/api/keys", {method:"POST", body: JSON.stringify(body)});
    }
    $("#modal-key").hidden = true;
    await renderApikeys();
    setStatus("已保存");
  } catch (err) {
    alert("保存失败：" + err.message);
  }
};
$("#kf-test").onclick = async () => {
  // 测试连接逻辑：
  // - 有 KEY_EDIT_ID（修改模式）：调用 /api/keys/{id}/test（用已存 Key）
  // - 新建模式：先临时保存到后端 → 测 → 立刻删除（保证数据干净）
  const el = $("#kf-test-result");
  el.hidden = false;
  el.className = "modal-test-result";
  el.textContent = "测试中...";
  try {
    if (KEY_EDIT_ID) {
      const r = await api(`/api/keys/${KEY_EDIT_ID}/test`, {method:"POST"});
      if (r.ok) { el.className = "modal-test-result success"; el.textContent = r.msg || "✅ 连接成功"; }
      else       { el.className = "modal-test-result error";   el.textContent = r.msg || "❌ 连接失败"; }
    } else {
      // 新建模式：临时存 → 测 → 删
      const name = $("#kf-name").value.trim() || "临时测试";
      const provider = $("#kf-provider").value;
      const key = $("#kf-key").value;
      if (!key) { el.className = "modal-test-result error"; el.textContent = "❌ 新建模式必须先填 Key"; return; }
      const created = await api("/api/keys", {method:"POST", body: JSON.stringify({name, provider, key, enabled: true})});
      try {
        const r = await api(`/api/keys/${created.id}/test`, {method:"POST"});
        if (r.ok) { el.className = "modal-test-result success"; el.textContent = r.msg || "✅ 连接成功"; }
        else       { el.className = "modal-test-result error";   el.textContent = r.msg || "❌ 连接失败"; }
      } finally {
        // 清理临时 Key
        await api(`/api/keys/${created.id}`, {method:"DELETE"});
      }
    }
  } catch (err) {
    el.className = "modal-test-result error";
    el.textContent = "❌ " + err.message;
  }
};

// =============================================================
// 工具：HTML 转义
// =============================================================
function esc(s) {
  return (s || "").toString()
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}
function setStatus(s) { $("#status-info").textContent = s; }

// =============================================================
// 启动
// =============================================================
async function refreshProjects() {
  const data = await api("/api/projects");
  PROJECTS = data.projects || [];
}
async function bootstrap() {
  try {
    const [cat, prov] = await Promise.all([api("/api/sidebar"), api("/api/providers")]);
    CATEGORIES = cat.categories || [];
    PROVIDERS = prov.providers || {};
    await refreshProjects();
    await renderSidebar();
    showView("welcome");
    setStatus("就绪");
  } catch (err) {
    setStatus("启动失败：" + err.message);
  }
}
bootstrap();
