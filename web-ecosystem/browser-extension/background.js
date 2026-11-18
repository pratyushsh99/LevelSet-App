
import {
  API_BASE_URL,
  DEDUCT_INTERVAL_MS,
  STATUS_REFRESH_ALARM,
  STATUS_REFRESH_PERIOD_MINUTES,
} from './config.js';

let deductTimerId = null;
let activeRestrictedTabId = null;

async function getToken() {
  const { deviceToken } = await chrome.storage.local.get('deviceToken');
  return deviceToken || null;
}

async function getCachedStatus() {
  const { status } = await chrome.storage.local.get('status');
  return status || { remainingSeconds: null, blockedDomains: [] };
}

async function setCachedStatus(status) {
  await chrome.storage.local.set({ status });
}

async function fetchStatus(token) {
  const res = await fetch(`${API_BASE_URL}/api/status`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) throw new Error(`Status fetch failed: ${res.status}`);
  return res.json();
}

async function deductTime(token, seconds = 5) {
  const res = await fetch(`${API_BASE_URL}/api/deduct-time`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ seconds }),
  });
  if (!res.ok) throw new Error(`Deduct-time failed: ${res.status}`);
  return res.json();
}

function extractDomain(url) {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return null;
  }
}

function isOwnSite(url) {
  try {
    return new URL(url).origin === new URL(API_BASE_URL).origin;
  } catch {
    return false;
  }
}

function isRestricted(domain, blockedDomains) {
  if (!domain) return false;
  return blockedDomains.some(
    (blocked) => domain === blocked || domain.endsWith(`.${blocked}`)
  );
}

async function redirectToLocked(tabId) {
  try {
    await chrome.tabs.update(tabId, { url: `${API_BASE_URL}/locked` });
  } catch (err) {

    console.warn('Could not redirect tab to /locked:', err);
  }
}

function stopDeductTimer() {
  if (deductTimerId !== null) {
    clearInterval(deductTimerId);
    deductTimerId = null;
  }
  activeRestrictedTabId = null;
}

function startDeductTimer(tabId) {
  if (deductTimerId !== null && activeRestrictedTabId === tabId) {
    return;
  }
  stopDeductTimer();
  activeRestrictedTabId = tabId;

  deductTimerId = setInterval(async () => {
    const token = await getToken();
    if (!token) {
      stopDeductTimer();
      return;
    }

    try {
      const { remainingSeconds, locked } = await deductTime(token, 5);
      await setCachedStatus({ ...(await getCachedStatus()), remainingSeconds });

      if (locked) {
        stopDeductTimer();
        await redirectToLocked(tabId);
      }
    } catch (err) {
      console.error('Deduct-time tick failed:', err);
    }
  }, DEDUCT_INTERVAL_MS);
}

async function evaluateTab(tabId, url) {
  const token = await getToken();
  if (!token || !url) {
    stopDeductTimer();
    return;
  }

  const domain = extractDomain(url);

  if (!domain || isOwnSite(url)) {
    stopDeductTimer();
    return;
  }

  let status;
  try {
    status = await fetchStatus(token);
    await setCachedStatus(status);
  } catch (err) {
    console.error('Failed to refresh status:', err);
    status = await getCachedStatus();
  }

  if (!isRestricted(domain, status.blockedDomains || [])) {
    stopDeductTimer();
    return;
  }

  if (status.locked) {
    stopDeductTimer();
    await redirectToLocked(tabId);
    return;
  }

  startDeductTimer(tabId);
}

chrome.tabs.onActivated.addListener(async ({ tabId }) => {
  try {
    const tab = await chrome.tabs.get(tabId);
    await evaluateTab(tabId, tab.url);
  } catch (err) {
    console.error('onActivated handler failed:', err);
  }
});

chrome.tabs.onUpdated.addListener(async (tabId, changeInfo, tab) => {

  if (changeInfo.status === 'complete' && tab.active) {
    await evaluateTab(tabId, tab.url);
  }
});

chrome.tabs.onRemoved.addListener((tabId) => {
  if (tabId === activeRestrictedTabId) {
    stopDeductTimer();
  }
});

chrome.runtime.onInstalled.addListener(() => {
  chrome.alarms.create(STATUS_REFRESH_ALARM, {
    periodInMinutes: STATUS_REFRESH_PERIOD_MINUTES,
  });
});

chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name !== STATUS_REFRESH_ALARM) return;

  const [activeTab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (activeTab) {
    await evaluateTab(activeTab.id, activeTab.url);
  }
});
