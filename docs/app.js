'use strict';

const playIcon = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m9 5 11 7-11 7z"/></svg>';
const pauseIcon = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 5h3v14H7zm7 0h3v14h-3z"/></svg>';
const time = value => `${Math.floor((Number.isFinite(value) ? value : 0) / 60).toString().padStart(2, '0')}:${Math.floor((Number.isFinite(value) ? value : 0) % 60).toString().padStart(2, '0')}`;
const allAudio = [...document.querySelectorAll('audio')];
allAudio.forEach(audio => audio.addEventListener('play', () => allAudio.forEach(other => { if (other !== audio) other.pause(); })));

document.querySelectorAll('[data-player]').forEach(player => {
  const audio = player.querySelector('audio');
  const toggle = player.querySelector('.play-toggle');
  const mute = player.querySelector('.mute-toggle');
  const seek = player.querySelector('.seek');
  const status = player.querySelector('.audio-status');
  let dragging = false;
  const sync = () => {
    const playing = !audio.paused && !audio.ended;
    toggle.innerHTML = playing ? pauseIcon : playIcon;
    toggle.setAttribute('aria-label', `${playing ? '暂停' : '播放'}清晨`);
    toggle.setAttribute('aria-pressed', String(playing));
    player.classList.toggle('is-playing', playing);
  };
  toggle.addEventListener('click', async () => {
    if (!audio.paused) { audio.pause(); return; }
    if (audio.ended) audio.currentTime = 0;
    status.textContent = '';
    try { await audio.play(); } catch { status.textContent = '暂时无法播放，请稍后重试。'; }
  });
  mute.addEventListener('click', () => {
    audio.muted = !audio.muted;
    mute.setAttribute('aria-pressed', String(audio.muted));
    mute.setAttribute('aria-label', audio.muted ? '取消静音' : '静音');
  });
  audio.addEventListener('loadedmetadata', () => {
    seek.max = audio.duration;
    player.querySelector('.duration').textContent = time(audio.duration);
  });
  audio.addEventListener('timeupdate', () => {
    if (!dragging) seek.value = audio.currentTime;
    player.querySelector('.elapsed').textContent = time(audio.currentTime);
  });
  seek.addEventListener('input', () => { dragging = true; player.querySelector('.elapsed').textContent = time(Number(seek.value)); });
  seek.addEventListener('change', () => { audio.currentTime = Number(seek.value); dragging = false; });
  ['play', 'pause', 'ended'].forEach(event => audio.addEventListener(event, sync));
  audio.addEventListener('error', () => { status.textContent = '音频读取失败，请刷新后重试。'; sync(); });
});

const quickButton = document.querySelector('[data-quick-play]');
const quickAudio = document.querySelector('#quick-audio');
if (quickButton && quickAudio) {
  const sync = () => {
    const playing = !quickAudio.paused && !quickAudio.ended;
    quickButton.innerHTML = (playing ? pauseIcon : playIcon) + `<span>${playing ? '暂停试听' : '试听 28 秒'}</span>`;
    quickButton.setAttribute('aria-label', `${playing ? '暂停' : '播放'}清晨`);
    quickButton.setAttribute('aria-pressed', String(playing));
  };
  quickButton.addEventListener('click', async () => {
    const status = document.querySelector('.quick-status');
    if (!quickAudio.paused) { quickAudio.pause(); return; }
    if (quickAudio.ended) quickAudio.currentTime = 0;
    status.textContent = '';
    try { await quickAudio.play(); } catch { status.textContent = '暂时无法试听，请稍后重试。'; }
  });
  ['play', 'pause', 'ended'].forEach(event => quickAudio.addEventListener(event, sync));
  quickAudio.addEventListener('error', () => { document.querySelector('.quick-status').textContent = '音频读取失败，请刷新后重试。'; });
}

const dialog = document.querySelector('#download-status');
let release = null;
fetch('release.json').then(response => { if (!response.ok) throw new Error('release unavailable'); return response.json(); }).then(info => {
  release = info;
  ['game', 'soundtrack'].forEach(kind => {
    const entry = info[kind];
    if (!entry?.url || entry.status !== 'published') return;
    let target;
    try { target = new URL(entry.url); } catch { return; }
    if (target.origin !== 'https://github.com' || !target.pathname.startsWith('/dongxilvdou/code1/releases/download/')) return;
    document.querySelectorAll(`[data-download="${kind}"]`).forEach(link => {
      link.href = target.href;
      link.download = entry.filename || '';
      link.querySelector('small').textContent = entry.label || '立即下载';
    });
  });
}).catch(() => { /* Pending state remains usable when release metadata is unavailable. */ });

document.querySelectorAll('[data-download]').forEach(link => link.addEventListener('click', event => {
  if (link.getAttribute('href') !== '#download-status') return;
  event.preventDefault();
  const kind = link.dataset.download;
  dialog.querySelector('h2').textContent = kind === 'game' ? '游戏还在准备中。' : '原声集还在整理中。';
  dialog.querySelector('.download-message').textContent = kind === 'game' ? '安装包完成后，这里会开放下载。现在可以先看看故事，或听一段游戏里的音乐。' : '完整原声带将在整理后开放下载。目前可以试听游戏里的《清晨》。';
  if (typeof dialog.showModal === 'function') dialog.showModal();
}));
dialog?.addEventListener('click', event => {
  const bounds = dialog.getBoundingClientRect();
  if (event.target === dialog && (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom)) dialog.close();
});
document.addEventListener('visibilitychange', () => { if (document.hidden) allAudio.forEach(audio => audio.pause()); });
