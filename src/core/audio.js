/**
 * Prozedurales Sound-Design über die WebAudio-API.
 * Kein externes Asset noetig: Kick, Bass, Hats, Crowd-Noise und SFX
 * werden zur Laufzeit synthetisiert. Intensitaet folgt der Nacht.
 */

export function createAudio() {
  let ctx = null;
  let master = null;
  let musicGain = null;
  let sfxGain = null;
  let crowdGain = null;
  let crowdSource = null;
  let filter = null;
  let started = false;
  let muted = false;
  let intensity = 0.4;
  let bpm = 132;
  let nextNoteTime = 0;
  let step = 0;
  let timer = 0;

  function ensure() {
    if (ctx) return ctx;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    ctx = new AC();
    master = ctx.createGain();
    master.gain.value = 0.9;
    master.connect(ctx.destination);

    filter = ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.value = 900;
    filter.Q.value = 0.7;
    filter.connect(master);

    musicGain = ctx.createGain();
    musicGain.gain.value = 0.5;
    musicGain.connect(filter);

    sfxGain = ctx.createGain();
    sfxGain.gain.value = 0.55;
    sfxGain.connect(master);

    crowdGain = ctx.createGain();
    crowdGain.gain.value = 0.0;
    crowdGain.connect(master);
    crowdSource = createNoiseSource(ctx, 'brown');
    const crowdFilter = ctx.createBiquadFilter();
    crowdFilter.type = 'bandpass';
    crowdFilter.frequency.value = 700;
    crowdFilter.Q.value = 0.6;
    crowdSource.connect(crowdFilter);
    crowdFilter.connect(crowdGain);
    crowdSource.start();
    return ctx;
  }

  function kick(time, gain = 1) {
    const osc = ctx.createOscillator();
    const g = ctx.createGain();
    osc.frequency.setValueAtTime(150, time);
    osc.frequency.exponentialRampToValueAtTime(42, time + 0.11);
    g.gain.setValueAtTime(0.0001, time);
    g.gain.exponentialRampToValueAtTime(0.9 * gain, time + 0.005);
    g.gain.exponentialRampToValueAtTime(0.0001, time + 0.28);
    osc.connect(g);
    g.connect(musicGain);
    osc.start(time);
    osc.stop(time + 0.3);
  }

  function sub(time, freq, gain = 0.5) {
    const osc = ctx.createOscillator();
    const g = ctx.createGain();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(freq, time);
    g.gain.setValueAtTime(0.0001, time);
    g.gain.exponentialRampToValueAtTime(gain, time + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, time + 0.19);
    const lp = ctx.createBiquadFilter();
    lp.type = 'lowpass';
    lp.frequency.value = 320;
    osc.connect(lp);
    lp.connect(g);
    g.connect(musicGain);
    osc.start(time);
    osc.stop(time + 0.2);
  }

  function hat(time, gain = 0.18) {
    const src = createNoiseSource(ctx, 'white');
    const hp = ctx.createBiquadFilter();
    hp.type = 'highpass';
    hp.frequency.value = 7200;
    const g = ctx.createGain();
    g.gain.setValueAtTime(gain, time);
    g.gain.exponentialRampToValueAtTime(0.0001, time + 0.05);
    src.connect(hp);
    hp.connect(g);
    g.connect(musicGain);
    src.start(time);
    src.stop(time + 0.06);
  }

  function scheduler() {
    if (!ctx || muted) return;
    const secondsPerStep = 60 / bpm / 4;
    while (nextNoteTime < ctx.currentTime + 0.15) {
      const t = nextNoteTime;
      const s = step % 16;
      if (s % 4 === 0) kick(t, 0.7 + intensity * 0.4);
      if (intensity > 0.25 && s % 2 === 1) hat(t, 0.08 + intensity * 0.14);
      if (intensity > 0.45 && (s === 3 || s === 11)) sub(t, 55, 0.25 + intensity * 0.25);
      if (intensity > 0.7 && s === 14) sub(t, 73, 0.28);
      nextNoteTime += secondsPerStep;
      step++;
    }
  }

  return {
    get enabled() {
      return started && !muted;
    },
    /** Muss aus einer User-Geste heraus aufgerufen werden. */
    async start() {
      if (!ensure()) return false;
      if (ctx.state === 'suspended') await ctx.resume();
      if (!started) {
        started = true;
        nextNoteTime = ctx.currentTime + 0.05;
        timer = setInterval(scheduler, 25);
      }
      return true;
    },
    stop() {
      if (timer) clearInterval(timer);
      timer = 0;
      started = false;
      if (crowdGain && ctx) crowdGain.gain.setTargetAtTime(0, ctx.currentTime, 0.3);
    },
    toggleMute() {
      muted = !muted;
      if (master && ctx) master.gain.setTargetAtTime(muted ? 0 : 0.9, ctx.currentTime, 0.05);
      return muted;
    },
    get muted() {
      return muted;
    },
    /** intensity 0..1 steuert Filter, Crowd und Arrangement. */
    setIntensity(value) {
      intensity = Math.max(0, Math.min(1, value));
      if (!ctx) return;
      filter.frequency.setTargetAtTime(500 + intensity * 5200, ctx.currentTime, 0.4);
      crowdGain.gain.setTargetAtTime(0.02 + intensity * 0.1, ctx.currentTime, 0.6);
      bpm = 128 + Math.round(intensity * 10);
    },
    setMusicVolume(v) {
      if (musicGain && ctx) musicGain.gain.setTargetAtTime(v, ctx.currentTime, 0.1);
    },
    /** Kurze UI-/Gameplay-Sounds. */
    sfx(name) {
      if (!ctx || muted) return;
      const t = ctx.currentTime;
      switch (name) {
        case 'beep': tone(ctx, sfxGain, 'square', 1100, 0.06, 0.12, t); break;
        case 'scan': sweep(ctx, sfxGain, 420, 1700, 0.22, 0.1, t); break;
        case 'ok': tone(ctx, sfxGain, 'sine', 660, 0.09, 0.16, t);
          tone(ctx, sfxGain, 'sine', 990, 0.1, 0.14, t + 0.09); break;
        case 'deny': tone(ctx, sfxGain, 'sawtooth', 190, 0.18, 0.16, t);
          tone(ctx, sfxGain, 'sawtooth', 120, 0.22, 0.16, t + 0.1); break;
        case 'alarm': sweep(ctx, sfxGain, 900, 300, 0.35, 0.18, t);
          sweep(ctx, sfxGain, 900, 300, 0.35, 0.18, t + 0.4); break;
        case 'door': noiseHit(ctx, sfxGain, 220, 0.3, 0.35, t); break;
        case 'radio': tone(ctx, sfxGain, 'square', 1500, 0.04, 0.07, t);
          tone(ctx, sfxGain, 'square', 1200, 0.04, 0.07, t + 0.06); break;
        case 'cash': tone(ctx, sfxGain, 'triangle', 880, 0.07, 0.14, t);
          tone(ctx, sfxGain, 'triangle', 1320, 0.12, 0.12, t + 0.07); break;
        case 'upgrade': sweep(ctx, sfxGain, 300, 1400, 0.5, 0.14, t); break;
        default: break;
      }
    }
  };
}

function tone(ctx, dest, type, freq, dur, gain, time) {
  const osc = ctx.createOscillator();
  const g = ctx.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(freq, time);
  g.gain.setValueAtTime(0.0001, time);
  g.gain.exponentialRampToValueAtTime(gain, time + 0.008);
  g.gain.exponentialRampToValueAtTime(0.0001, time + dur);
  osc.connect(g);
  g.connect(dest);
  osc.start(time);
  osc.stop(time + dur + 0.02);
}

function sweep(ctx, dest, from, to, dur, gain, time) {
  const osc = ctx.createOscillator();
  const g = ctx.createGain();
  osc.type = 'sawtooth';
  osc.frequency.setValueAtTime(from, time);
  osc.frequency.exponentialRampToValueAtTime(Math.max(30, to), time + dur);
  g.gain.setValueAtTime(0.0001, time);
  g.gain.exponentialRampToValueAtTime(gain, time + 0.02);
  g.gain.exponentialRampToValueAtTime(0.0001, time + dur);
  const bp = ctx.createBiquadFilter();
  bp.type = 'bandpass';
  bp.Q.value = 3;
  bp.frequency.value = (from + to) / 2;
  osc.connect(bp);
  bp.connect(g);
  g.connect(dest);
  osc.start(time);
  osc.stop(time + dur + 0.02);
}

function noiseHit(ctx, dest, freq, dur, gain, time) {
  const src = createNoiseSource(ctx, 'white');
  const lp = ctx.createBiquadFilter();
  lp.type = 'lowpass';
  lp.frequency.value = freq;
  const g = ctx.createGain();
  g.gain.setValueAtTime(gain, time);
  g.gain.exponentialRampToValueAtTime(0.0001, time + dur);
  src.connect(lp);
  lp.connect(g);
  g.connect(dest);
  src.start(time);
  src.stop(time + dur + 0.02);
}

function createNoiseSource(ctx, type = 'white') {
  const seconds = 2;
  const buffer = ctx.createBuffer(1, ctx.sampleRate * seconds, ctx.sampleRate);
  const data = buffer.getChannelData(0);
  let lastOut = 0;
  for (let i = 0; i < data.length; i++) {
    const white = Math.random() * 2 - 1;
    if (type === 'brown') {
      lastOut = (lastOut + 0.02 * white) / 1.02;
      data[i] = lastOut * 3.5;
    } else {
      data[i] = white;
    }
  }
  const src = ctx.createBufferSource();
  src.buffer = buffer;
  src.loop = true;
  return src;
}
