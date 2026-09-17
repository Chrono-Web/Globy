// Suono breve all'arrivo, generato: niente file audio da registrare tra gli asset.
let context: AudioContext | null = null;

export function tink(): void {
  try {
    context ??= new AudioContext();
    const now = context.currentTime;
    const gain = context.createGain();
    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(0.12, now + 0.005);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.25);
    gain.connect(context.destination);
    for (const [frequency, level] of [[1760, 1], [2637, 0.35]]) {
      const tone = context.createOscillator();
      const partial = context.createGain();
      tone.type = "sine";
      tone.frequency.value = frequency;
      partial.gain.value = level;
      tone.connect(partial).connect(gain);
      tone.start(now);
      tone.stop(now + 0.26);
    }
  } catch {
    // Audio non disponibile: Globy arriva in silenzio.
  }
}
