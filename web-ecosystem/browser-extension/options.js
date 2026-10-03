
const input = document.getElementById('userId');
const status = document.getElementById('status');

chrome.storage.local.get('userId').then(({ userId }) => {
  if (userId) input.value = userId;
});

document.getElementById('save').addEventListener('click', async () => {
  const userId = input.value.trim();
  if (!userId) return;

  await chrome.storage.local.set({ userId });
  status.textContent = 'Saved.';
  setTimeout(() => (status.textContent = ''), 2000);
});
