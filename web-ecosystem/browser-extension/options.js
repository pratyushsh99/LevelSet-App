const input = document.getElementById('deviceToken');
const status = document.getElementById('status');
const KEY_PATTERN = /^[A-Za-z0-9_-]{43}$/;

chrome.storage.local.remove('userId');

chrome.storage.local.get('deviceToken').then(({ deviceToken }) => {
  if (deviceToken) input.placeholder = 'Saved. Paste a new key to replace it.';
});

function show(message, isError = false) {
  status.textContent = message;
  status.style.color = isError ? '#c0392b' : '#2a7f2a';
  setTimeout(() => (status.textContent = ''), 3000);
}

document.getElementById('save').addEventListener('click', async () => {
  const deviceToken = input.value.trim();
  if (!KEY_PATTERN.test(deviceToken)) {
    show('That doesn\'t look like an extension key. Copy it from the /pair page after linking.', true);
    return;
  }

  await chrome.storage.local.set({ deviceToken });
  input.value = '';
  input.placeholder = 'Saved. Paste a new key to replace it.';
  show('Saved.');
});
