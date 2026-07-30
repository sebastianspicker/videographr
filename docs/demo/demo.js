const shell = document.querySelector('.demo-shell');
const views = [...document.querySelectorAll('[data-view]')];
const tabs = [...document.querySelectorAll('[data-tab]')];
const toast = document.querySelector('#toast');
let toastTimer;

function showToast(message) {
  window.clearTimeout(toastTimer);
  toast.textContent = message;
  toast.hidden = false;
  toastTimer = window.setTimeout(() => { toast.hidden = true; }, 3600);
}

function openView(name, updateHash = true) {
  const next = views.find((view) => view.dataset.view === name) || views[0];
  views.forEach((view) => {
    const active = view === next;
    view.hidden = !active;
    view.classList.toggle('active', active);
  });
  tabs.forEach((tab) => {
    const active = tab.dataset.tab === next.dataset.view;
    tab.classList.toggle('active', active);
    if (active) tab.setAttribute('aria-current', 'page');
    else tab.removeAttribute('aria-current');
  });
  shell.dataset.theme = next.dataset.view === 'live' ? 'night' : 'day';
  if (updateHash) history.replaceState(null, '', `#${next.dataset.view}`);
  next.querySelector('h1')?.focus({ preventScroll: true });
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  window.scrollTo({ top: 0, behavior: reducedMotion ? 'auto' : 'smooth' });
}

tabs.forEach((tab) => tab.addEventListener('click', () => openView(tab.dataset.tab)));

document.querySelectorAll('[data-action]').forEach((button) => {
  button.addEventListener('click', () => {
    const action = button.dataset.action;
    if (action === 'record') {
      document.querySelector('#record-result').innerHTML = '<strong>Demo-Modus: Aufnahme nicht verfügbar</strong><p>Es wurde nichts aufgezeichnet. Der Zustand bleibt „nicht aufnehmend“.</p>';
      showToast('Simuliert: Keine Kamera oder Aufnahme wurde gestartet.');
    } else if (action === 'save-consent') {
      showToast('Simuliert: Die Scope-Auswahl bleibt nur bis zum Neuladen dieser Seite erhalten.');
    } else if (action === 'save-session') {
      showToast('Simuliert: Der Entwurf wurde nicht gespeichert oder übertragen.');
    } else if (action === 'import') {
      showToast('Simuliert: Die Demo öffnet keine Dateien und lädt kein Video.');
    } else if (action === 'save-note') {
      showToast('Simuliert: Die Reflexion wurde nicht dauerhaft gespeichert.');
    } else if (action === 'export') {
      const secondary = document.querySelector('[data-scope="secondary"]').checked;
      const sharing = document.querySelector('[data-scope="sharing"]').checked;
      showToast(secondary && sharing
        ? 'Simuliert: Metadatenpaket wäre freigegeben; keine Datei wurde erzeugt.'
        : 'Simuliert: Export bleibt ohne Sekundärnutzung und externe Weitergabe gesperrt.');
    } else if (action === 'back-catalogue') {
      document.querySelector('#topic-detail').hidden = true;
      document.querySelector('#catalogue-list').hidden = false;
      document.querySelector('[data-topic="method"]').focus();
    }
  });
});

document.querySelectorAll('[data-scope]').forEach((input) => {
  input.addEventListener('change', () => {
    const collection = document.querySelector('[data-scope="collection"]').checked;
    const consentCheck = document.querySelector('#consent-check');
    consentCheck.classList.toggle('met', collection);
    consentCheck.querySelector(':scope > span').textContent = collection ? '✓' : '○';

    const secondary = document.querySelector('[data-scope="secondary"]').checked;
    const sharing = document.querySelector('[data-scope="sharing"]').checked;
    const gate = document.querySelector('#export-gate');
    gate.classList.toggle('warning', !(secondary && sharing));
    gate.innerHTML = secondary && sharing
      ? '<strong>Scopes vollständig</strong><p>Eine echte App könnte nun ein Metadatenpaket vorbereiten. Diese Demo erzeugt keine Datei.</p>'
      : '<strong>Export gesperrt</strong><p>Sekundärnutzung und externe Weitergabe fehlen.</p>';
  });
});

document.querySelector('#reflection-note').addEventListener('input', (event) => {
  document.querySelector('#note-count').textContent = event.target.value.trim() ? '1 / 4 Antworten' : '0 / 4 Antworten';
});

document.querySelectorAll('[data-topic]').forEach((topic) => {
  topic.addEventListener('click', () => {
    const detail = document.querySelector('#topic-detail');
    const catalogue = document.querySelector('#catalogue-list');
    catalogue.hidden = true;
    detail.hidden = false;
    detail.querySelector('.eyebrow').textContent = topic.querySelector('strong').textContent.split(':')[0];
    detail.querySelector('h2').textContent = topic.querySelector('strong').textContent.replace(/^.*?:\s*/, '');
    detail.focus();
  });
});

openView(location.hash.slice(1) || 'setup', false);
