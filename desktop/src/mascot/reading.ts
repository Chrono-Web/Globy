// `ReadingPolicy` di GlobyCore: il fumetto resta il tempo di leggerlo, tra 2 e 15 secondi.
export const ReadingPolicy = {
  minimumLinger: 2,
  maximumLinger: 15,
  secondsPerWord: 0.3,
  linger(text: string): number {
    const words = text.split(/\s+/).filter(Boolean).length;
    return Math.min(this.maximumLinger, Math.max(this.minimumLinger, words * this.secondsPerWord));
  },
};
