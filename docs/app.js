/* === AI Registry — App Logic === */
(function () {
  'use strict';

  // ── Config ──
  const REPO = {
    owner: 'sisques-labs',
    name: 'ai-registry',
    branch: 'main',
  };
  const INDEX_URL = `https://raw.githubusercontent.com/${REPO.owner}/${REPO.name}/${REPO.branch}/index.json`;
  const RAW_BASE = `https://raw.githubusercontent.com/${REPO.owner}/${REPO.name}/${REPO.branch}`;

  // ── State ──
  let registryData = null;

  // ── DOM refs ──
  const $ = (sel, ctx = document) => ctx.querySelector(sel);
  const $$ = (sel, ctx = document) => [...ctx.querySelectorAll(sel)];

  // ── Fetch ──
  async function fetchRegistry () {
    const res = await fetch(INDEX_URL);
    if (!res.ok) throw new Error(`HTTP ${res.status} — ${res.statusText}`);
    return res.json();
  }

  // ── Navigation ──
  function renderNav () {
    const current = location.pathname.split('/').pop() || 'index.html';
    const links = [
      { href: 'index.html', label: 'Home' },
      { href: 'catalog.html', label: 'Catalog' },
      { href: 'install.html', label: 'Install' },
      { href: 'docs.html', label: 'Docs' },
    ];

    const nav = document.getElementById('nav');
    if (!nav) return;

    nav.innerHTML = `
      <div class="nav-inner">
        <a href="index.html" class="nav-brand">ai-registry</a>
        <ul class="nav-links">
          ${links.map(l => `
            <li><a href="${l.href}" class="${current === l.href ? 'active' : ''}">${l.label}</a></li>
          `).join('')}
        </ul>
      </div>
    `;
  }

  function renderFooter () {
    const footer = document.getElementById('footer');
    if (!footer) return;
    footer.innerHTML = `
      <div class="container">
        <p>
          <a href="https://github.com/${REPO.owner}/${REPO.name}" target="_blank" rel="noopener">${REPO.owner}/${REPO.name}</a>
          &nbsp;·&nbsp; MIT &nbsp;·&nbsp; Built with &lt;/&gt;
        </p>
      </div>
    `;
  }

  // ── Copy to clipboard ──
  function setupCopyButtons () {
    $$('.copy-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const code = btn.parentElement.querySelector('pre, code');
        if (!code) return;
        const text = code.textContent.trim();

        navigator.clipboard.writeText(text).then(() => {
          btn.textContent = 'Copied!';
          btn.classList.add('copied');
          setTimeout(() => {
            btn.textContent = 'Copy';
            btn.classList.remove('copied');
          }, 2000);
        }).catch(() => {
          // Fallback
          const ta = document.createElement('textarea');
          ta.value = text;
          ta.style.position = 'fixed';
          ta.style.opacity = '0';
          document.body.appendChild(ta);
          ta.select();
          document.execCommand('copy');
          document.body.removeChild(ta);
          btn.textContent = 'Copied!';
          btn.classList.add('copied');
          setTimeout(() => {
            btn.textContent = 'Copy';
            btn.classList.remove('copied');
          }, 2000);
        });
      });
    });
  }

  // ── Terminal code blocks ──
  // Wraps <pre><code> blocks in terminal chrome
  function enhanceCodeBlocks () {
    $$('pre code').forEach(codeBlock => {
      // Skip if already enhanced
      if (codeBlock.closest('.terminal')) return;

      const pre = codeBlock.parentElement;
      const title = pre.getAttribute('data-title') || 'bash';
      const wrap = document.createElement('div');
      wrap.className = 'terminal';
      wrap.innerHTML = `
        <div class="terminal-bar">
          <span class="terminal-dot red"></span>
          <span class="terminal-dot amber"></span>
          <span class="terminal-dot green"></span>
          <span class="terminal-title">${escapeHtml(title)}</span>
        </div>
        <div class="terminal-body">
          ${pre.outerHTML}
          <button class="copy-btn">Copy</button>
        </div>
      `;
      pre.parentElement.replaceChild(wrap, pre);
    });
    setupCopyButtons();
  }

  // ── Escape HTML ──
  function escapeHtml (str) {
    const d = document.createElement('div');
    d.textContent = str;
    return d.innerHTML;
  }

  // ── Type badge ──
  function typeBadge (type) {
    const labels = { skill: 'Skill', agent: 'Agent', command: 'Command' };
    return `<span class="card-tag ${type}">${labels[type] || type}</span>`;
  }

  // ── Card HTML ──
  function itemCard (item, type) {
    const name = item.name;
    const slug = `${type}s`;
    const href = `detail.html?type=${type}&name=${encodeURIComponent(name)}`;
    return `
      <div class="card">
        ${typeBadge(type)}
        <h3><a href="${href}">${escapeHtml(name)}</a></h3>
        <div class="desc">${escapeHtml(truncate(item.description, 120))}</div>
        <div class="card-meta">
          ${item.author ? `<span>by ${escapeHtml(item.author)}</span>` : ''}
          ${item.version ? `<span>v${escapeHtml(item.version)}</span>` : ''}
        </div>
      </div>
    `;
  }

  function truncate (str, max) {
    if (!str) return '';
    if (str.length <= max) return str;
    return str.slice(0, max).replace(/\s+\S*$/, '') + '…';
  }

  // ── Catalog page ──
  async function initCatalog () {
    const grid = document.getElementById('catalog-grid');
    const tabsContainer = document.getElementById('catalog-tabs');
    const searchInput = document.getElementById('catalog-search');
    if (!grid) return;

    try {
      const data = await fetchRegistry();
      registryData = data;

      let currentTab = 'skill';
      let searchQuery = '';

      function render () {
        const items = data[currentTab + 's'] || [];
        const filtered = items.filter(item => {
          if (!searchQuery) return true;
          const q = searchQuery.toLowerCase();
          return item.name.toLowerCase().includes(q)
            || (item.description && item.description.toLowerCase().includes(q));
        });

        if (filtered.length === 0) {
          grid.innerHTML = `
            <div class="empty-state">
              <span class="emoji">🔍</span>
              <p>No ${currentTab}s match your search.</p>
            </div>
          `;
          return;
        }

        grid.innerHTML = filtered.map(item => itemCard(item, currentTab)).join('');
      }

      // Tabs
      if (tabsContainer) {
        tabsContainer.innerHTML = ['skill', 'agent', 'command'].map(t => `
          <button class="tab-btn ${t === currentTab ? 'active' : ''}" data-tab="${t}">
            ${t.charAt(0).toUpperCase() + t.slice(1)}s
            <span style="color:var(--text-muted);font-size:0.75rem">(${(data[t + 's'] || []).length})</span>
          </button>
        `).join('');

        tabsContainer.addEventListener('click', e => {
          const btn = e.target.closest('.tab-btn');
          if (!btn) return;
          currentTab = btn.dataset.tab;
          $$('.tab-btn', tabsContainer).forEach(b => b.classList.remove('active'));
          btn.classList.add('active');
          render();
        });
      }

      // Search
      if (searchInput) {
        searchInput.addEventListener('input', e => {
          searchQuery = e.target.value;
          render();
        });
      }

      render();
      enhanceCodeBlocks();

    } catch (err) {
      grid.innerHTML = `<div class="error-msg">Failed to load registry: ${escapeHtml(err.message)}</div>`;
    }
  }

  // ── Detail page ──
  async function initDetail () {
    const container = document.getElementById('detail-content');
    if (!container) return;

    const params = new URLSearchParams(location.search);
    const type = params.get('type');
    const name = params.get('name');

    if (!type || !name) {
      container.innerHTML = `<div class="error-msg">Missing type or name parameter. <a href="catalog.html">Browse catalog</a></div>`;
      return;
    }

    try {
      const data = await fetchRegistry();
      registryData = data;

      const items = data[type + 's'] || [];
      const item = items.find(i => i.name === name);

      if (!item) {
        container.innerHTML = `<div class="error-msg">${escapeHtml(type)} "${escapeHtml(name)}" not found. <a href="catalog.html">Browse catalog</a></div>`;
        return;
      }

      const labels = { skill: 'Skill', agent: 'Agent', command: 'Command' };
      const sourceUrl = `${RAW_BASE}/${type}s/${encodeURIComponent(name)}`;

      container.innerHTML = `
        <div class="breadcrumb">
          <a href="index.html">Home</a>
          <span class="sep">/</span>
          <a href="catalog.html">Catalog</a>
          <span class="sep">/</span>
          <span>${escapeHtml(name)}</span>
        </div>

        <div class="detail-header">
          ${typeBadge(type)}
          <h1>${escapeHtml(name)}</h1>
          <div class="detail-meta">
            ${item.author ? `<span><span class="label">Author:</span> ${escapeHtml(item.author)}</span>` : ''}
            ${item.version ? `<span><span class="label">Version:</span> ${escapeHtml(item.version)}</span>` : ''}
            <span><span class="label">Type:</span> ${labels[type] || type}</span>
          </div>
        </div>

        <div class="detail-description">
          <p>${escapeHtml(item.description)}</p>
        </div>

        <div class="btn-group" style="margin-top:var(--space-xl)">
          <a href="catalog.html" class="btn btn-ghost">← Back to Catalog</a>
          <a href="${sourceUrl}" target="_blank" rel="noopener" class="btn">View Source →</a>
        </div>
      `;

      enhanceCodeBlocks();

    } catch (err) {
      container.innerHTML = `<div class="error-msg">Failed to load detail: ${escapeHtml(err.message)}</div>`;
    }
  }

  // ── Home page ──
  async function initHome () {
    const statsContainer = document.getElementById('home-stats');
    const featuresContainer = document.getElementById('home-features');
    if (!statsContainer && !featuresContainer) return;

    try {
      const data = await fetchRegistry();
      registryData = data;

      const skillCount = (data.skills || []).length;
      const agentCount = (data.agents || []).length;
      const commandCount = (data.commands || []).length;
      const total = skillCount + agentCount + commandCount;

      if (statsContainer) {
        statsContainer.innerHTML = `
          <div class="stats">
            <div class="stat">
              <span class="stat-number">${skillCount}</span>
              <span class="stat-label">Skills</span>
            </div>
            <div class="stat">
              <span class="stat-number">${agentCount}</span>
              <span class="stat-label">Agents</span>
            </div>
            <div class="stat">
              <span class="stat-number">${commandCount}</span>
              <span class="stat-label">Commands</span>
            </div>
            <div class="stat">
              <span class="stat-number">${total}</span>
              <span class="stat-label">Total Items</span>
            </div>
          </div>
        `;
      }

      if (featuresContainer) {
        featuresContainer.innerHTML = `
          <div class="features">
            <div class="feature">
              <div class="feature-icon"></div>
              <h3>Skills</h3>
              <p>Reusable AI instructions for code reviews, testing, documentation, and more. Loaded contextually when needed.</p>
            </div>
            <div class="feature">
              <div class="feature-icon"></div>
              <h3>Agents</h3>
              <p>Specialized AI personas with domain expertise. Generate production-ready code following your conventions.</p>
            </div>
            <div class="feature">
              <div class="feature-icon"></div>
              <h3>Commands</h3>
              <p>Slash commands for quick actions — scaffold, review, test, and deploy from your AI editor.</p>
            </div>
            <div class="feature">
              <div class="feature-icon"></div>
              <h3>One-Liner Install</h3>
              <p>Single curl command to install everything at user or project level. Compatible with OpenCode, Claude Code, Cursor, and more.</p>
            </div>
          </div>
        `;
      }

      enhanceCodeBlocks();

    } catch (err) {
      const msg = `<div class="error-msg">Failed to load registry data: ${escapeHtml(err.message)}</div>`;
      if (statsContainer) statsContainer.innerHTML = '';
      if (featuresContainer) featuresContainer.innerHTML = msg;
    }
  }

  // ── Init ──
  function init () {
    renderNav();
    renderFooter();

    const page = location.pathname.split('/').pop() || 'index.html';

    switch (page) {
      case 'index.html':
      case '':
        initHome();
        break;
      case 'catalog.html':
        initCatalog();
        break;
      case 'detail.html':
        initDetail();
        break;
      default:
        enhanceCodeBlocks();
        break;
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
