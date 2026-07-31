const alarm = new Audio('../audio/alarm.mp3');
alarm.loop = true;

window.addEventListener('message', ({ data }) => {
    if (data.action === 'playAlarm') {
        alarm.volume = Math.max(0, Math.min(Number(data.volume) || 0.35, 1));
        alarm.currentTime = 0;
        alarm.play().catch(() => {});
    }

    if (data.action === 'stopAlarm') {
        alarm.pause();
        alarm.currentTime = 0;
    }
});
