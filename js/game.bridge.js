import { spotifyPlayer } from "./spotify.player.js";

export const gameBridge = (() => {
  async function startRun() {
    await spotifyPlayer.initPlayer();
    await nextTrackAndImage();
    if (window.startMazeGame) window.startMazeGame();
  }

  async function onCheckpointCollected(speedLevel) {
    try {
      // Change track every checkpoint; tune as needed
      await nextTrackAndImage();
    } catch (e) {
      console.warn("checkpoint handler:", e);
    }
  }

  async function nextTrackAndImage() {
    const track = await spotifyPlayer.getRandomTrack();
    const artistId = track.artists[0].id;

    const resp = await fetch("/assets/manifest.json", { cache: "force-cache" });
    const manifest = await resp.json();
    const imgs = manifest[artistId] || [];
    const url = imgs[Math.floor(Math.random() * imgs.length)] || "/assets/default.png";

    if (window.setEnemySprite) window.setEnemySprite(url);
    await spotifyPlayer.playTrack(track.uri);
  }

  return { startRun, onCheckpointCollected };
})();
