Nisho_drmFM {

	*initClass {

		StartUp.add {

			CroneDefs.add(
				SynthDef.new(\drmFM_FX, {
					arg outBus, inBus,
					mainAmp = 1, lpfHz = 20000, hpfHz = 20, tapeSat = 1, tapeDrive = 1;

					var mono, stereo, snd;
					var xHz = 60, tapeBias = 0.5;

					mainAmp = Lag.kr(mainAmp);
					lpfHz = Lag.kr(lpfHz).clip(20, 20000);
					hpfHz = Lag.kr(hpfHz).clip(20, 20000);

					snd = In.ar(inBus, 2);
					snd = RHPF.ar(snd, hpfHz);
					snd = RLPF.ar(snd, lpfHz);

					//snd = AnalogTape.ar(snd, tapeBias, tapeSat, tapeDrive);

					//mono = LPF.ar(LPF.ar(Mix(snd), xHz), xHz);
					//stereo = HPF.ar(HPF.ar(snd, xHz), xHz);
					//snd = mono + stereo;

					snd = snd * mainAmp;

					Out.ar(outBus, snd);
				});
			);

			CroneDefs.add(
				SynthDef(\drmFM_BD,{
					arg outBus, sendABus, sendBBus, nWBuf, nSBuf, nGBuf, nPBuf,
					mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0,
					pitch = 0, tune = 0, gate = 1, decay = 0.8, decRnd = 0, dist = 0,
					mod1 = 0, mod2 = 0, mod3 = 0, mod4 = 0, mod5 = 0, mod6 = 0, mod7 = 0, mod8 = 0,
					kitMod = 0, keyMod = 0, sendAM = 0, sendBM = 0, decayM = 0, distM = 0,
					mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0, mod7M = 0, mod8M = 0;

					var pitchOff = 36, atk = 0.001, carCrv = -8, modCrv = -10, frqCrv = -14, frqMul = 3.2, modHz = 64;

					var attn, gain, hz, mod, car, snd, carEnv, modEnv, modIndex, frqEnv, toneLo, toneHi, toneCo;
					var frqDepth, frqDecay, modDepth, modRatio, modDecay, modFb, punch, tone;

					// rescale, smooth, clamp ///////////////////////////////////////////////////////////////////////

					kitMod = (kitMod + keyMod).clip(0, 1);
					mod1 = (mod1 + (mod1M * kitMod));
					mod2 = (mod2 + (mod2M * kitMod));
					mod3 = (mod3 + (mod3M * kitMod));
					mod4 = (mod4 + (mod4M * kitMod));
					mod5 = (mod5 + (mod5M * kitMod));
					mod6 = (mod6 + (mod6M * kitMod));
					mod7 = (mod7 + (mod7M * kitMod));
					mod8 = (mod8 + (mod8M * kitMod));

					frqDepth = mod1.clip(0, 1);
					frqDecay = mod2.linlin(0, 1, 0.1, 1);
					modDepth = mod3.clip(0, 1);
					modRatio = mod4.linlin(0, 1, 1, 4);
					modDecay = mod5.linlin(0, 1, 0.02, 0.8);
					modFb = mod6.linlin(0, 1, 4, 12);
					punch = mod7.clip(0, 1);
					tone = mod8.clip(0, 1);

					modIndex = modDepth.linexp(0, 1, 40, 120);

					atk = punch.linexp(0, 1, 0.0024, 0.0002);
					toneLo = tone.linexp(0, 0.5, 320, 20000);
					toneHi = tone.linexp(0.5, 1, 20, 140);

					decay = (decay + (decayM * 8 * kitMod) + (decRnd * Rand(0.2, 1.2))).clip(0, 8);
					sendA = (sendA + (sendAM * kitMod)).clip(0, 1);
					sendB = (sendB + (sendBM * kitMod)).clip(0, 1);
					pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

					dist = (dist + (distM * kitMod)).clip(0, 1);
					gain = dist.linlin(0, 1, 12, 24).dbamp;
					attn = dist.linlin(0, 1, 0, -12).dbamp;

					// synthesis ////////////////////////////////////////////////////////////////////////////////////

					// envelopes
					carEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay], carCrv), gate, doneAction: 2);
					modEnv = EnvGen.kr(Env.new([0, 1, 0], [atk, modDecay * decay], modCrv)) * modDepth;
					frqEnv = EnvGen.kr(Env.new([0, 1, 0], [atk, frqDecay * decay], frqCrv)) * frqDepth;

					// pitch
					hz = (pitch + tune + pitchOff).midicps;
					hz = (hz + (hz * frqMul * frqEnv)).clip(20, 12000);

					// modulator
					mod = SinOscFB.ar(modHz * modRatio, modFb) * modIndex * modRatio * modEnv;

					// carrier
					car = SinOsc.ar(hz + mod, pi/2) * carEnv;

					// tone
					snd = LPF.ar(car, toneLo);
					snd = HPF.ar(snd, toneHi);

					// distortion
					snd = (snd * (1 - dist)) + ((snd * gain).tanh * dist * attn);

					// output stage
					snd = snd * vel * amp * mainAmp;
					snd = Pan2.ar(snd, pan);

					Out.ar(outBus, snd);
					Out.ar(sendABus, snd * sendA);
					Out.ar(sendBBus, snd * sendB);
				});
			);

			CroneDefs.add(
				SynthDef(\drmFM_SD,{
					arg outBus, sendABus, sendBBus, nWBuf, nSBuf, nGBuf, nPBuf,
					mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0,
					pitch = 0, tune = 0, gate = 1, decay = 0.8, decRnd = 0, dist = 0,
					mod1 = 0, mod2 = 0, mod3 = 0, mod4 = 0, mod5 = 0, mod6 = 0, mod7 = 0, mod8 = 0,
					kitMod = 0, keyMod = 0, sendAM = 0, sendBM = 0, decayM = 0, distM = 0,
					mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0, mod7M = 0, mod8M = 0;

					var pitchOff = 55, atk = 0.001, carCrv = -8, modCrv = -4, nozCrv = -4, pitchCrv = -12, modHz = 21, modFb = 4;

					var attn, gain, hz, mod, car, wNoz, gNoz, noz, snd, carEnv, bodEnv, modEnv, modIndex, nozEnv, nozCrk;
					var balance, nozColor, nozFloor, bodDecay, modDepth, modRatio, modDecay, bpfHz, bpfRq;

					// rescale, smooth, clamp ///////////////////////////////////////////////////////////////////////

					kitMod = (kitMod + keyMod).clip(0, 1);
					mod1 = (mod1 + (mod1M * kitMod));
					mod2 = (mod2 + (mod2M * kitMod));
					mod3 = (mod3 + (mod3M * kitMod));
					mod4 = (mod4 + (mod4M * kitMod));
					mod5 = (mod5 + (mod5M * kitMod));
					mod6 = (mod6 + (mod6M * kitMod));
					mod7 = (mod7 + (mod7M * kitMod));
					mod8 = (mod8 + (mod8M * kitMod));

					balance  = mod1.linlin(0, 1, -0.9, 0.8);
					bpfHz    = mod2.linexp(0, 1, 400, 1200);
					bpfRq    = mod2.linlin(0, 1, 8, 1);
					nozColor = mod3.linlin(0, 1, -1, 1);
					nozFloor = mod4.linlin(0, 1, 0, 0.5);
					nozCrk   = mod4.linlin(0, 1, 1, 0.6);
					bodDecay = mod5.linlin(0, 1, 0.2, 1);
					modDepth = mod6.clip(0, 1);
					modIndex = mod6.linlin(0, 1, 12, 60);
					modRatio = mod7.linlin(0, 1, 1, 8);
					modDecay = mod8.linlin(0, 1, 0.01, 2);

					decay = (decay + (decayM * 4 * kitMod) + (decRnd * Rand(0.2, 1.2))).clip(0, 4);
					sendA = (sendA + (sendAM * kitMod)).clip(0, 1);
					sendB = (sendB + (sendBM * kitMod)).clip(0, 1);
					pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

					dist = (dist + (distM * kitMod)).clip(0, 1);
					gain = dist.linlin(0, 1, 12, 24);
					attn = dist.linlin(0, 1, 0, -12);

					// synthesis ////////////////////////////////////////////////////////////////////////////////////

					// envelopes
					nozEnv = EnvGen.kr(Env.new([0, 1, nozFloor], [atk, decay], nozCrv), gate, doneAction: 2);
					modEnv = EnvGen.kr(Env.new([0, 1, 0], [atk, modDecay * decay], modCrv)) * modDepth;
					carEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, bodDecay * decay], carCrv));
					bodEnv = EnvGen.kr(Env([2, 1], [0.1], pitchCrv));

					// pitch
					hz = (pitch + tune + pitchOff).midicps;
					hz = hz * bodEnv;

					// modulator
					mod = SinOscFB.ar((hz * modRatio) + modHz, modFb) * modIndex * modRatio * modEnv;
					// noise
					wNoz = PlayBuf.ar(1, nWBuf, startPos: IRand.new(0, 48000 * 6), loop: 1) * -9.dbamp;
					gNoz = PlayBuf.ar(1, nGBuf, startPos: IRand.new(0, 48000 * 6), loop: 1) * -6.dbamp;
					noz = XFade2.ar(wNoz, gNoz, nozColor) * nozEnv * -12.dbamp;
					noz = HPF.ar(noz, 60) * LFNoise0.kr(hz).range(nozCrk, 1);

					// carrier
					car = Mix.ar([
						SinOsc.ar(hz + mod, pi/2),
						SinOsc.ar((hz * 1.47) + (mod * 0.68)) * -16.dbamp
					]) * carEnv;

					// mix
					car = (car * 2.dbamp).softclip;
					noz = (noz * 12.dbamp).tanh;
					snd = XFade2.ar(car, noz, balance);

					// filter & distortion
					snd = BPF.ar(snd, bpfHz, bpfRq);
					snd = (snd * (1 - dist)) + ((snd * gain.dbamp).tanh * dist * attn.dbamp);

					// output stage
					snd = snd * vel * amp * mainAmp;
					snd = Pan2.ar(snd, pan);

					Out.ar(outBus, snd);
					Out.ar(sendABus, snd * sendA);
					Out.ar(sendBBus, snd * sendB);
				});
			);

			CroneDefs.add(
				SynthDef(\drmFM_XT,{
					arg outBus, sendABus, sendBBus, nWBuf, nSBuf, nGBuf, nPBuf,
					mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0,
					pitch = 0, tune = 0, gate = 1, decay = 0.8, decRnd = 0, dist = 0,
					mod1 = 0, mod2 = 0, mod3 = 0, mod4 = 0, mod5 = 0, mod6 = 0, mod7 = 0, mod8 = 0,
					kitMod = 0, keyMod = 0, sendAM = 0, sendBM = 0, decayM = 0, distM = 0,
					mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0, mod7M = 0, mod8M = 0;

					var pitchOff = 48, atk = 0.001, carCrv = -4, modCrv = -4, frqCrv = -12, frqMul = 3, modFb = 4.2;

					var attn, gain, hz, mod, car, snd, carEnv, modEnv, modIndex, frqEnv, hpfHz;
					var toneHz, toneAmp, punchAmt, frqDepth, frqDecay, modDepth, modRatio, modDecay;


					// rescale, smooth, clamp ///////////////////////////////////////////////////////////////////////

					kitMod = (kitMod + keyMod).clip(0, 1);
					mod1 = (mod1 + (mod1M * kitMod));
					mod2 = (mod2 + (mod2M * kitMod));
					mod3 = (mod3 + (mod3M * kitMod));
					mod4 = (mod4 + (mod4M * kitMod));
					mod5 = (mod5 + (mod5M * kitMod));
					mod6 = (mod6 + (mod6M * kitMod));
					mod7 = (mod7 + (mod7M * kitMod));
					mod8 = (mod8 + (mod8M * kitMod));

					frqDepth = mod1.linlin(0, 1, 0, 1);
					frqDecay = mod2.linlin(0, 1, 0.02, 2);
					punchAmt = mod3.linlin(0, 1, 0, pi/2);
					modDepth = mod4.clip(0, 1);
					modIndex = mod4.linexp(0, 1, 1, 18);
					modRatio = mod5.linexp(0, 1, 0.5, 8);
					modDecay = mod6.linlin(0, 1, 0.01, 2);
					toneHz   = mod7.linlin(0, 1, 80, 2200);
					toneAmp  = mod8.linlin(0, 1, -6, 18);

					decay = (decay + (decayM * 4 * kitMod) + (decRnd * Rand(0.2, 1.2))).clip(0, 4);
					sendA = (sendA + (sendAM * kitMod)).clip(0, 1);
					sendB = (sendB + (sendBM * kitMod)).clip(0, 1);
					pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

					dist = (dist + (distM * kitMod)).clip(0, 1);
					gain = dist.linlin(0, 1, 12, 24);
					attn = dist.linlin(0, 1, 0, -12);

					// synthesis ////////////////////////////////////////////////////////////////////////////////////

					// envelopes
					carEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay], carCrv), gate, doneAction: 2);
					modEnv = EnvGen.kr(Env.new([0, 1, 0], [atk, modDecay * decay], modCrv)) * modDepth;
					frqEnv = EnvGen.kr(Env.new([0, 1, 0], [atk, frqDecay * decay], frqCrv)) * frqDepth;

					// pitch
					hz = (pitch + tune + pitchOff).midicps;
					hpfHz = hz.clip(40, 200);
					hz = (hz + (hz * frqMul * frqEnv)).clip(20, 12000);

					// modulator
					mod = SinOscFB.ar(hz * modRatio, modFb) * hz * modIndex * modEnv;
					// carrier
					car = SinOsc.ar(hz + mod, punchAmt) * -6.dbamp * carEnv;
					// distortion
					snd = (car * (1 - dist)) + ((car * gain.dbamp).tanh * dist * attn.dbamp);
					// tone
					snd = MidEQ.ar(snd, toneHz, 1, toneAmp);
					snd = HPF.ar(snd, hpfHz);
					// output stage
					snd = snd * vel * amp * mainAmp;
					snd = Pan2.ar(snd, pan);

					Out.ar(outBus, snd);
					Out.ar(sendABus, snd * sendA);
					Out.ar(sendBBus, snd * sendB);
				});
			);

			CroneDefs.add(
				SynthDef(\drmFM_CP,{
					arg outBus, sendABus, sendBBus, nWBuf, nSBuf, nGBuf, nPBuf,
					mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0,
					pitch = 0, tune = 0, gate = 1, decay = 0.8, decRnd = 0, dist = 0,
					mod1 = 0, mod2 = 0, mod3 = 0, mod4 = 0, mod5 = 0, mod6 = 0, mod7 = 0, mod8 = 0,
					kitMod = 0, keyMod = 0, sendAM = 0, sendBM = 0, decayM = 0, distM = 0,
					mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0, mod7M = 0, mod8M = 0;

					var pitchOff = 84, atk = 0.001, carCrv = -6, modCrv = -2, clpCrv = -6, modFb = 20, maxClps = 12, modHz = 200, modIndex = 320;

					var attn, gain, hz, mod, car, noz, snd, carEnv, modEnv, preEnv, clpEnv, preClpDur, preClpLevels, preClpTimes;
					var clpNum, clpDecay, modDepth, modRatio, modDecay, tone, lpfHz, hpfHz;

					// rescale, smooth, clamp ///////////////////////////////////////////////////////////////////////

					kitMod = (kitMod + keyMod).clip(0, 1);
					mod1 = (mod1 + (mod1M * kitMod));
					mod2 = (mod2 + (mod2M * kitMod));
					mod3 = (mod3 + (mod3M * kitMod));
					mod4 = (mod4 + (mod4M * kitMod));
					mod5 = (mod5 + (mod5M * kitMod));
					mod6 = (mod6 + (mod6M * kitMod));
					mod7 = (mod7 + (mod7M * kitMod));
					mod8 = (mod8 + (mod8M * kitMod));

					clpNum   = mod1.linlin(0, 1, 1, maxClps).round;
					clpDecay = mod2.linexp(0, 1, 0.01, 0.1);
					modDepth = mod3.linlin(0, 1, 1, 2);
					modRatio = mod4.linlin(0, 1, 2, 8);
					modDecay = mod5.linexp(0, 1, 0.1, 1);
					tone     = mod6.linexp(0, 1, 200, 12000);
					lpfHz    = mod7.linexp(0, 1, 800, 20000);
					hpfHz    = mod8.linexp(0, 1, 60, 800);

					decay = (decay + (decayM * 4 * kitMod) + (decRnd * Rand(0.2, 1.2))).clip(0, 4);
					sendA = (sendA + (sendAM * kitMod)).clip(0, 1);
					sendB = (sendB + (sendBM * kitMod)).clip(0, 1);
					pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

					dist = (dist + (distM * kitMod)).clip(0, 1);
					gain = dist.linlin(0, 1, 12, 24);
					attn = dist.linlin(0, 1, 0, -12);

					preClpDur = clpDecay * (clpNum - 1);
					preClpLevels = Array.fill(maxClps, { [1, 0.24] }).flat;
					preClpTimes  = Array.fill(maxClps, { [0.001, clpDecay] }).flat;

					// synthesis ////////////////////////////////////////////////////////////////////////////////////

					// envelopes
					carEnv = EnvGen.ar(Env.linen(atk, preClpDur, decay, curve: carCrv), gate, doneAction: 2);
					preEnv = EnvGen.ar(Env.new(
						levels: [0] ++ preClpLevels ++ [0],
						times:  preClpTimes ++ [decay],
						curve: clpCrv));
					clpEnv = Select.ar(EnvGen.ar(Env.new([0, 0, 1], [preClpDur, 0]));, [preEnv, carEnv]);
					modEnv = EnvGen.kr(Env.linen(atk, preClpDur, modDecay * decay, curve: modCrv)) + 0.5;

					// pitch
					hz = (pitch + tune + pitchOff).midicps;

					// modulator
					mod = SinOscFB.ar((hz * modRatio) + modHz, modFb) * modIndex * modRatio * modEnv.range(1 - modDepth, 1);

					// carrier
					car = SinOsc.ar(hz + mod, pi/2);

					// mix
					snd = car * clpEnv * -9.dbamp;

					// distortion & filter
					snd = (snd * (1 - dist) + ((snd * gain.dbamp).tanh * dist)) * attn.dbamp;
					snd = HPF.ar(snd, hpfHz);
					snd = LPF.ar(snd, lpfHz);
					snd = MidEQ.ar(snd, tone, 1, 9);

					// output stage
					snd = snd * vel * amp * mainAmp;
					snd = Pan2.ar(snd, pan);

					Out.ar(outBus, snd);
					Out.ar(sendABus, snd * sendA);
					Out.ar(sendBBus, snd * sendB);
				});
			);

			CroneDefs.add(
				SynthDef(\drmFM_RS,{
					arg outBus, sendABus, sendBBus, nWBuf, nSBuf, nGBuf, nPBuf,
					mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0,
					pitch = 0, tune = 0, gate = 1, decay = 0.8, decRnd = 0, dist = 0,
					mod1 = 0, mod2 = 0, mod3 = 0, mod4 = 0, mod5 = 0, mod6 = 0, mod7 = 0, mod8 = 0,
					kitMod = 0, keyMod = 0, sendAM = 0, sendBM = 0, decayM = 0, distM = 0,
					mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0, mod7M = 0, mod8M = 0;

					var pitchOff = 72, atk = 0.001, rimCrv = -4, snrCrv = -4, modFbRim = 2, modFbSnr = 8, modRatioSnr = 4.42;

					var attn, gain, hzRim, hzSnr, modRim, modSnr, carRim, carSnr, snd, rimEnv, snrEnv;
					var rimMod, modRatioRim, snrAmp, snrDecay, snrMod, snrRatio, lpfHz, hpfHz;

					// rescale, smooth, clamp ///////////////////////////////////////////////////////////////////////

					kitMod = (kitMod + keyMod).clip(0, 1);
					mod1 = (mod1 + (mod1M * kitMod));
					mod2 = (mod2 + (mod2M * kitMod));
					mod3 = (mod3 + (mod3M * kitMod));
					mod4 = (mod4 + (mod4M * kitMod));
					mod5 = (mod5 + (mod5M * kitMod));
					mod6 = (mod6 + (mod6M * kitMod));
					mod7 = (mod7 + (mod7M * kitMod));
					mod8 = (mod8 + (mod8M * kitMod));

					rimMod      = mod1.linlin(0, 1, 1, 2);
					modRatioRim = mod2.linlin(0, 1, 2, 5);
					snrAmp      = mod3.clip(0, 1);
					snrDecay    = mod4.linlin(0, 1, 0, 2);
					snrMod      = mod5.linlin(0, 1, 0.4, 6);
					snrRatio    = mod6.linlin(0, 1, 1, 10);
					lpfHz       = mod7.linexp(0, 1, 600, 20000);
					hpfHz       = mod8.linexp(0, 1, 120, 600);

					decay = (decay + (decayM * 4 * kitMod) + (decRnd * Rand(0.2, 1.2))).clip(0, 8);
					sendA = (sendA + (sendAM * kitMod)).clip(0, 1);
					sendB = (sendB + (sendBM * kitMod)).clip(0, 1);
					pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

					dist = (dist + (distM * kitMod)).clip(0, 1);
					gain = dist.linlin(0, 1, 12, 24);
					attn = dist.linlin(0, 1, 0, -12);

					// synthesis ////////////////////////////////////////////////////////////////////////////////////

					// envelopes
					rimEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay], [rimCrv, rimCrv]), gate, doneAction: 2);
					snrEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, snrDecay * decay], [snrCrv, snrCrv])) * snrAmp;

					// pitch
					hzRim = (pitch + tune + pitchOff).midicps;
					hzSnr = hzRim * snrRatio;

					// modulator
					modRim = SinOscFB.ar(hzRim * modRatioRim, modFbRim) * 60 * modRatioRim * rimMod;
					modSnr = SinOscFB.ar(hzSnr * modRatioSnr, modFbSnr) * 320 * modRatioSnr * snrMod;

					// carrier
					carRim = SinOsc.ar(hzRim + modRim, 0) * rimEnv;
					carSnr = SinOsc.ar(hzSnr + modSnr, 0) * snrEnv;

					// mix
					carRim = (carRim * 2).tanh;
					carSnr = (carSnr * 3.2).softclip;
					snd = (carRim + carSnr) * -12.dbamp;

					// filter & distortion
					snd = HPF.ar(snd, hpfHz);
					snd = LPF.ar(snd, lpfHz);
					snd = (snd * (1 - dist)) + ((snd * gain.dbamp).tanh * dist * attn.dbamp);


					// output stage
					snd = snd * vel * amp * mainAmp;
					snd = Pan2.ar(snd, pan);

					Out.ar(outBus, snd);
					Out.ar(sendABus, snd * sendA);
					Out.ar(sendBBus, snd * sendB);
				});
			);

			CroneDefs.add(
				SynthDef(\drmFM_CB,{
					arg outBus, sendABus, sendBBus, nWBuf, nSBuf, nGBuf, nPBuf,
					mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0,
					pitch = 0, tune = 0, gate = 1, decay = 0.8, decRnd = 0, dist = 0,
					mod1 = 0, mod2 = 0, mod3 = 0, mod4 = 0, mod5 = 0, mod6 = 0, mod7 = 0, mod8 = 0,
					kitMod = 0, keyMod = 0, sendAM = 0, sendBM = 0, decayM = 0, distM = 0,
					mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0, mod7M = 0, mod8M = 0;

					var pitchOff = 60, atk = 0.001, modCrv = -6, priCrv = -6, secCrv = -10, secDecf = 0.62;

					var attn, gain, hzA, hzB, modA, modB, carA, carB, snd, modEnv, priEnv, secEnv;
					var secAmp, carFb, carDetn, modDepth, modRatio, modDecay, lpfHz, hpfHz;

					// rescale, smooth, clamp ///////////////////////////////////////////////////////////////////////

					kitMod = (kitMod + keyMod).clip(0, 1);
					mod1 = (mod1 + (mod1M * kitMod));
					mod2 = (mod2 + (mod2M * kitMod));
					mod3 = (mod3 + (mod3M * kitMod));
					mod4 = (mod4 + (mod4M * kitMod));
					mod5 = (mod5 + (mod5M * kitMod));
					mod6 = (mod6 + (mod6M * kitMod));
					mod7 = (mod7 + (mod7M * kitMod));
					mod8 = (mod8 + (mod8M * kitMod));

					secAmp   = mod1.clip(0, 1);
					carFb    = mod2.linlin(0, 1, 0, 2.4);
					carDetn  = mod3.linlin(0, 1, 1.02, 1.98);
					modDepth = mod4.linlin(0, 1, 0, 2);
					modRatio = mod5.linexp(0, 1, 0.01, 1);
					modDecay = mod6.linlin(0, 1, 0, 2);
					lpfHz    = mod7.linexp(0, 1, 600, 20000);
					hpfHz    = mod8.linexp(0, 1, 60, 600);

					decay = (decay + (decayM * 4 * kitMod) + (decRnd * Rand(0.2, 1.2))).clip(0, 8);
					sendA = (sendA + (sendAM * kitMod)).clip(0, 1);
					sendB = (sendB + (sendBM * kitMod)).clip(0, 1);
					pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

					dist = (dist + (distM * kitMod)).clip(0, 1);
					gain = dist.linlin(0, 1, 12, 24);
					attn = dist.linlin(0, 1, 0, -12);

					// synthesis ////////////////////////////////////////////////////////////////////////////////////

					// envelopes
					priEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay], [priCrv.neg, priCrv]), gate, doneAction: 2) * (1 - secAmp);
					secEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay * secDecf], [secCrv, secCrv])) * secAmp;
					modEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay * modDecay], [modCrv, modCrv])) * modDepth;

					// pitch
					hzA = (pitch + tune + pitchOff).midicps;
					hzB = hzA * carDetn; // 1.48

					// modulators
					modA = SinOsc.ar(hzA * modRatio) * hzA * modRatio * modEnv;
					modB = SinOsc.ar(hzB * modRatio) * hzB * modRatio * modEnv;

					// carrier
					carA = SinOscFB.ar(hzA + modA, carFb);
					carB = SinOscFB.ar(hzB + modB, carFb);
					carA = (carA * 1.47).tanh;

					// mix
					snd = (carA + carB) * -9.dbamp * (priEnv + secEnv);

					// filter & distortion
					snd = HPF.ar(snd, hpfHz);
					snd = LPF.ar(snd, lpfHz);
					snd = (snd * (1 - dist)) + ((snd * gain.dbamp).tanh * dist * attn.dbamp);

					// output stage
					snd = snd * vel * amp * mainAmp;
					snd = Pan2.ar(snd, pan);

					Out.ar(outBus, snd);
					Out.ar(sendABus, snd * sendA);
					Out.ar(sendBBus, snd * sendB);
				});
			);

			CroneDefs.add(
				SynthDef(\drmFM_HH,{
					arg outBus, sendABus, sendBBus, nWBuf, nSBuf, nGBuf, nPBuf,
					mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0,
					pitch = 0, tune = 0, gate = 1, decay = 0.8, decRnd = 0, dist = 0,
					mod1 = 0, mod2 = 0, mod3 = 0, mod4 = 0, mod5 = 0, mod6 = 0, mod7 = 0, mod8 = 0,
					kitMod = 0, keyMod = 0, sendAM = 0, sendBM = 0, decayM = 0, distM = 0,
					mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0, mod7M = 0, mod8M = 0;

					var pitchOff = 84, atk = 0.0001, modCrv = -6, carCrv = -12;

					var attn, gain, hzA, hzB, hzC, hzD, modA, modB, modC, modD, carA, carB, carC, carD, snd, modEnv, carEnv;
					var envSat, carFb, bpfHz, bpfRq, modDepth, modRatio, modIndex, modDecay, lpfHz, hpfHz;

					// rescale, smooth, clamp ///////////////////////////////////////////////////////////////////////

					kitMod = (kitMod + keyMod).clip(0, 1);
					mod1 = (mod1 + (mod1M * kitMod));
					mod2 = (mod2 + (mod2M * kitMod));
					mod3 = (mod3 + (mod3M * kitMod));
					mod4 = (mod4 + (mod4M * kitMod));
					mod5 = (mod5 + (mod5M * kitMod));
					mod6 = (mod6 + (mod6M * kitMod));
					mod7 = (mod7 + (mod7M * kitMod));
					mod8 = (mod8 + (mod8M * kitMod));

					envSat   = mod1.linlin(0, 1, 0.8, 2.4);
					carFb    = mod2.linlin(0, 1, 0.5, 2);
					bpfHz    = mod3.linexp(0, 1, 4000, 12000);
					bpfRq    = mod3.linlin(0, 1, 0.6, 0.15);
					modDepth = mod4.linlin(0, 1, 0.2, 0.5);
					modRatio = mod5.linexp(0, 1, 0.5, 1.5);
					modDecay = mod6.linlin(0, 1, 0.5, 1);
					lpfHz    = mod7.linexp(0, 1, 1200, 20000);
					hpfHz    = mod8.linexp(0, 1, 1200, 3200);

					decay = (decay + (decayM * 4 * kitMod) + (decRnd * Rand(0.2, 1.2))).clip(0.01, 4);
					sendA = (sendA + (sendAM * kitMod)).clip(0, 1);
					sendB = (sendB + (sendBM * kitMod)).clip(0, 1);
					pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

					dist = (dist + (distM * kitMod)).clip(0, 1);
					gain = dist.linlin(0, 1, 12, 24);
					attn = dist.linlin(0, 1, 0, -12);

					// synthesis ////////////////////////////////////////////////////////////////////////////////////

					// envelopes
					modEnv = EnvGen.ar(Env.new([0, 1, 0.5], [atk, decay * modDecay], modCrv)) * modDepth;
					carEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay], carCrv), gate, doneAction: 2);
					carEnv = (carEnv * envSat).clip(0, 1);

					// pitch
					hzA = (pitch + tune + pitchOff).midicps;
					hzB = hzA * 1.79;
					hzC = hzA * 1.48;
					hzD = hzA * 2.64;

					// modulators
					modIndex = hzA.linlin(500, 2000, 8000, 1200);
					modA = SinOsc.ar(hzA * modRatio) * modIndex * modRatio * modEnv;
					modB = SinOsc.ar(hzB * modRatio) * modIndex * modRatio * modEnv;
					modC = SinOsc.ar(hzC * modRatio) * modIndex * modRatio * modEnv;
					modD = SinOsc.ar(hzD * modRatio) * modIndex * modRatio * modEnv;

					// carriers
					carA = SinOscFB.ar(hzA + modA, carFb);
					carB = SinOscFB.ar(hzB + modB, carFb * 1.7) * -1.dbamp;
					carC = SinOscFB.ar(hzC + modC, carFb * 1.3) * -4.dbamp;
					carD = SinOscFB.ar(hzD + modD, carFb * 0.8) * -2.dbamp;

					// mix
					snd = (carA + carB + carC + carD).tanh * -14.dbamp * carEnv;

					// filter & distortion
					snd = HPF.ar(snd, hpfHz);
					snd = BPF.ar(snd, bpfHz, bpfRq);
					snd = LPF.ar(snd, lpfHz);
					snd = (snd * (1 - dist)) + ((snd * gain.dbamp).tanh * dist * attn.dbamp);

					// output stage
					snd = snd * vel * amp * mainAmp;
					snd = Pan2.ar(snd, pan);

					Out.ar(outBus, snd);
					Out.ar(sendABus, snd * sendA);
					Out.ar(sendBBus, snd * sendB);
				});
			);

			CroneDefs.add(
				SynthDef(\drmFM_CY,{
					arg outBus, sendABus, sendBBus, nWBuf, nSBuf, nGBuf, nPBuf,
					mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0,
					pitch = 0, tune = 0, gate = 1, decay = 0.8, decRnd = 0, dist = 0,
					mod1 = 0, mod2 = 0, mod3 = 0, mod4 = 0, mod5 = 0, mod6 = 0, mod7 = 0, mod8 = 0,
					kitMod = 0, keyMod = 0, sendAM = 0, sendBM = 0, decayM = 0, distM = 0,
					mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0, mod7M = 0, mod8M = 0;

					var pitchOff = 48, atk = 0.0001, modCrv = -4, carCrv = -6;

					var attn, gain, hzA, hzB, hzC, hzD, modA, modB, modC, modD, carA, carB, carC, carD, noz, snd, modEnv, carEnv;
					var envSat, nozLevel, bpfHz, bpfRq, modDepth, modRatio, modIndex, modDecay, lpfHz, hpfHz;

					// rescale, smooth, clamp ///////////////////////////////////////////////////////////////////////

					kitMod = (kitMod + keyMod).clip(0, 1);
					mod1 = (mod1 + (mod1M * kitMod));
					mod2 = (mod2 + (mod2M * kitMod));
					mod3 = (mod3 + (mod3M * kitMod));
					mod4 = (mod4 + (mod4M * kitMod));
					mod5 = (mod5 + (mod5M * kitMod));
					mod6 = (mod6 + (mod6M * kitMod));
					mod7 = (mod7 + (mod7M * kitMod));
					mod8 = (mod8 + (mod8M * kitMod));

					envSat   = mod1.linlin(0, 1, 1, 2);
					nozLevel = mod2.clip(0, 1);
					modDepth = mod3.linlin(0, 1, 0.2, 0.6);
					modRatio = mod4.linlin(0, 1, 2, 6);
					modIndex = mod4.linlin(0, 1, 4000, 400);
					modDecay = mod5.linlin(0, 1, 0.8, 2);
					bpfHz    = mod6.linexp(0, 1, 4000, 8000);
					bpfRq    = mod6.linlin(0, 1, 0.6, 0.3);
					lpfHz    = mod7.linexp(0, 1, 800, 18000);
					hpfHz    = mod8.linexp(0, 1, 1200, 3200);

					decay = (decay + (decayM * 4 * kitMod) + (decRnd * Rand(0.2, 1.2))).clip(0, 4);
					sendA = (sendA + (sendAM * kitMod)).clip(0, 1);
					sendB = (sendB + (sendBM * kitMod)).clip(0, 1);
					pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

					dist = (dist + (distM * kitMod)).clip(0, 1);
					gain = dist.linlin(0, 1, 12, 24);
					attn = dist.linlin(0, 1, 0, -12);

					// synthesis ////////////////////////////////////////////////////////////////////////////////////

					// envelopes
					carEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay], carCrv), gate, doneAction: 2);
					modEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay * modDecay], modCrv)) * modDepth;
					carEnv = (carEnv * envSat).clip(0, 1).lag(0.02);

					// pitch
					hzA = (pitch + tune + pitchOff).midicps;
					hzB = hzA * 1.48;
					hzC = hzA * 1.74;
					hzD = hzA * 2.42;

					// modulators
					modA = LFTri.ar(hzA * modRatio) * modIndex * modRatio * modEnv;
					modB = LFTri.ar(hzB * modRatio) * modIndex * modRatio * modEnv;
					modC = LFTri.ar(hzC * modRatio) * modIndex * modRatio * modEnv;
					modD = LFTri.ar(hzD * modRatio) * modIndex * modRatio * modEnv;

					// carriers
					carA = SinOsc.ar(hzA + modA);
					carB = SinOsc.ar(hzB + modB);
					carC = SinOsc.ar(hzC + modC);
					carD = SinOsc.ar(hzD + modD);

					// noise
					noz = PlayBuf.ar(1, nPBuf, startPos: IRand.new(0, 48000 * 6), loop: 1);
					noz = noz * LFNoise0.ar(hzD).range(carEnv + 0.2, 1);
					noz = LPF.ar(noz, bpfHz) * -9.dbamp;
					noz = noz * nozLevel;

					// mix
					snd = Mix.ar(carA + carB + carC + carD + noz) * carEnv;

					// filter & distortion
					snd = HPF.ar(snd, hpfHz);
					snd = BPF.ar(snd, bpfHz, bpfRq);
					snd = LPF.ar(snd, lpfHz);
					snd = (snd * 28.dbamp).tanh * -20.dbamp;
					snd = (snd * (1 - dist)) + ((snd * gain.dbamp).tanh * dist * attn.dbamp);

					// output stage
					snd = snd * vel * amp * mainAmp;
					snd = Pan2.ar(snd, pan);

					Out.ar(outBus, snd);
					Out.ar(sendABus, snd * sendA);
					Out.ar(sendBBus, snd * sendB);
				});
			);

			CroneDefs.add(
				// crushed olican
				SynthDef(\drmFM_OC, {
					arg outBus, sendABus, sendBBus, nWBuf, nSBuf, nGBuf, nPBuf,
					mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0,
					pitch = 0, tune = 0, gate = 1, decay = 0.8, decRnd = 0, dist = 0,
					mod1 = 0, mod2 = 0, mod3 = 0, mod4 = 0, mod5 = 0, mod6 = 0, mod7 = 0, mod8 = 0,
					kitMod = 0, keyMod = 0, sendAM = 0, sendBM = 0, decayM = 0, distM = 0,
					mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0, mod7M = 0, mod8M = 0;

					var pitchOff = 48, atk = 0.0001, carCrv = -4, modCrv = -4;

					var attn, gain, hz, mod, car, noz, snd, carEnv, modEnv, nozEnv;
					var nozDepth, wavFold, modDest, modDepth, modRatio, modDecay, lpfHz, hpfHz;

					// rescale, smooth, clamp ///////////////////////////////////////////////////////////////////////

					kitMod = (kitMod + keyMod).clip(0, 1);
					mod1 = (mod1 + (mod1M * kitMod));
					mod2 = (mod2 + (mod2M * kitMod));
					mod3 = (mod3 + (mod3M * kitMod));
					mod4 = (mod4 + (mod4M * kitMod));
					mod5 = (mod5 + (mod5M * kitMod));
					mod6 = (mod6 + (mod6M * kitMod));
					mod7 = (mod7 + (mod7M * kitMod));
					mod8 = (mod8 + (mod8M * kitMod));

					nozDepth = mod1.clip(0, 1);
					wavFold  = mod2.linlin(0, 1, 1, 6);
					modDest  = mod3.clip(0, 1);
					modDepth = mod4.linlin(0, 1, -1, 1);
					modRatio = mod5.linlin(0, 1, 1, 10);
					modDecay = mod6.linlin(0, 1, 0, 2);
					lpfHz    = mod7.linexp(0, 1, 20, 18000);
					hpfHz    = mod8.linexp(0, 1, 20, 18000);

					decay = (decay + (decayM * 4 * kitMod) + (decRnd * Rand(0.2, 1.2))).clip(0, 4);
					sendA = (sendA + (sendAM * kitMod)).clip(0, 1);
					sendB = (sendB + (sendBM * kitMod)).clip(0, 1);
					pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

					dist = (dist + (distM * kitMod)).clip(0, 1);
					gain = dist.linlin(0, 1, 12, 24);
					attn = dist.linlin(0, 1, 0, -6);

					// envelopes
					carEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay], carCrv), gate, doneAction: 2);
					modEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, modDecay * decay], modCrv)) * modDepth;

					// pitch
					hz = (pitch + tune + pitchOff).midicps;
					hz = (hz + (carEnv * hz * modDepth)).clip(20, 12000);

					// modulator
					mod = SinOscFB.ar(hz * modRatio, modDest.linlin(0, 1, 0, 4));
					mod = Fold.ar(mod * wavFold, -1, 1) * modEnv;

					// carrier
					car = SinOsc.ar(hz + (mod * 10000 * modDest));

					// noise gen
					noz = PlayBuf.ar(1, nSBuf, startPos: IRand.new(0, 48000 * 6), loop: 1).range(1, 1 - nozDepth);

					// mix & fold
					snd = Mix.ar([car, (mod * (1 - modDest))]) * carEnv;
					snd = Fold.ar(snd * wavFold * noz, -1, 1);

					// distortion & filter
					snd = (snd * (1 - dist)) + ((snd * gain.dbamp).tanh * dist * attn.dbamp);
					snd = RHPF.ar(snd, hpfHz, 0.8);
					snd = RLPF.ar(snd, lpfHz, 0.8);

					// output stage
					snd = snd * vel * amp * mainAmp;
					snd = Pan2.ar(snd, pan);

					Out.ar(outBus, snd);
					Out.ar(sendABus, snd * sendA);
					Out.ar(sendBBus, snd * sendB);
				});
			);

			CroneDefs.add(
				// user wav synthDef - sample playback
				SynthDef(\drmFM_UW_mono,{
					arg outBus, sendABus, sendBBus,
					mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0,
					pitch = 0, gate = 1, mode = 0, buf = 0, dist = 0,
					mod1 = 0, mod2 = 0, mod3 = 0, mod4 = 0, mod5 = 0, mod6 = 0, mod7 = 0, mod8 = 0,
					kitMod = 0, keyMod = 0, sendAM = 0, sendBM = 0, decayM = 0, distM = 0,
					mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0, mod7M = 0, mod8M = 0;

					var rate, numFrames, srtFrame, endFrame, endRel, envOne, envHld, envAmp, sDur, phasePos;
					var attn, gain, snd, lpfQ, hpfQ, duckFrames, duckGate, envDuck, duckTime = 0.01, rateSlew = 0.2;
					var tune, plyDir, srtRel, lenRel, fadeIn, fadeOut, lpfHz, hpfHz;

					// rescale, smooth, clamp ///////////////////////////////////////////////////////////////////////

					kitMod  = (kitMod + keyMod).clip(0, 1);
					tune    = Lag.kr(mod1.linlin(0, 1, -1, 1) + (12 * mod1M * kitMod)).clip(-12, 12);
					plyDir  = Lag.kr((mod2 + (mod2M * kitMod)).clip(0, 1));
					srtRel  = Lag.kr((mod3 + (mod3M * kitMod)).linlin(0, 1, 0, 0.99));
					lenRel  = Lag.kr((mod4 + (mod4M * kitMod)).linlin(0, 1, 0.01, 1));
					fadeIn  = Lag.kr(mod5.linexp(0, 1, 0.001, 2));
					fadeOut = Lag.kr(mod6.linexp(0, 1, 0.001, 2));
					lpfHz   = Lag.kr(mod7.linexp(0, 1, 20, 20000));
					hpfHz   = Lag.kr(mod8.linexp(0, 1, 20, 20000));

					sendA = Lag.kr(sendA + (sendAM * kitMod)).clip(0, 1);
					sendB = Lag.kr(sendB + (sendBM * kitMod)).clip(0, 1);
					pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

					dist = Lag.kr(dist + (distM * kitMod)).clip(0, 1);
					gain = dist.linlin(0, 1, 12, 24);
					attn = dist.linlin(0, 1, 0, -6);

					// frame math
					plyDir = Select.kr(plyDir < 0.5, [1, -1]);
					rate = Lag3.kr((pitch + tune).midiratio * BufRateScale.kr(buf) * plyDir, rateSlew);
					endRel = (srtRel + lenRel).clip(0.01, 1);
					numFrames = BufFrames.ir(buf);
					srtFrame = numFrames * Select.kr(rate > 0, [endRel, srtRel]);
					endFrame = numFrames * Select.kr(rate > 0, [srtRel, endRel]);
					duckFrames = BufSampleRate.ir(buf) * duckTime * rate.abs;
					sDur = (numFrames * lenRel / rate.abs / 48000) - (fadeIn + fadeOut);

					// envelopes
					envOne = EnvGen.ar(Env.linen(fadeIn, sDur, fadeOut, curve: \sine), gate, doneAction: Select.kr(mode, [2, 0]));
					envHld = EnvGen.ar(Env.asr(fadeIn, 1, fadeOut, curve: \sine), gate, doneAction: Select.kr(mode, [0, 2]));
					envAmp = Select.kr(mode, [envOne, envHld]);

					// phasor
					phasePos = Phasor.ar(gate, rate, srtFrame, endFrame, srtFrame);

					// ducking
					duckGate = Select.ar(rate > 0, [
						InRange.ar(phasePos, endFrame, endFrame + duckFrames),
						InRange.ar(phasePos, endFrame - duckFrames, endFrame)
					]);
					envDuck = EnvGen.ar(Env.new([1, 0, 1], [duckTime], \sine), duckGate);

					// buffer read
					snd = BufRd.ar(1, buf, phasePos, interpolation: 4) * -3.dbamp;

					// eq and distortion
					snd = (snd * (1 - dist)) + ((snd * gain.dbamp).tanh * dist * attn.dbamp);
					snd = RHPF.ar(snd, hpfHz, 0.9);
					snd = RLPF.ar(snd, lpfHz, 0.9);

					// output stage
					snd = snd * envDuck * envAmp;
					snd = snd * vel * amp * mainAmp;
					snd = Pan2.ar(snd, pan);

					Out.ar(outBus, snd);
					Out.ar(sendABus, snd * sendA);
					Out.ar(sendBBus, snd * sendB);
				});
			);

			CroneDefs.add(
				SynthDef(\drmFM_UW_stereo,{
					arg outBus, sendABus, sendBBus,
					mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0,
					pitch = 0, gate = 1, mode = 0, buf = 0, dist = 0,
					mod1 = 0, mod2 = 0, mod3 = 0, mod4 = 0, mod5 = 0, mod6 = 0, mod7 = 0, mod8 = 0,
					kitMod = 0, keyMod = 0, sendAM = 0, sendBM = 0, decayM = 0, distM = 0,
					mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0, mod7M = 0, mod8M = 0;

					var rate, numFrames, srtFrame, endFrame, endRel, envOne, envHld, envAmp, sDur, phasePos;
					var attn, gain, snd, lpfQ, hpfQ, duckFrames, duckGate, envDuck, duckTime = 0.01, rateSlew = 0.2;
					var tune, plyDir, srtRel, lenRel, fadeIn, fadeOut, lpfHz, hpfHz;

					// rescale, smooth, clamp ///////////////////////////////////////////////////////////////////////

					kitMod  = (kitMod + keyMod).clip(0, 1);
					tune    = Lag.kr(mod1.linlin(0, 1, -1, 1) + (12 * mod1M * kitMod)).clip(-12, 12);
					plyDir  = Lag.kr((mod2 + (mod2M * kitMod)).clip(0, 1));
					srtRel  = Lag.kr((mod3 + (mod3M * kitMod)).linlin(0, 1, 0, 0.99));
					lenRel  = Lag.kr((mod4 + (mod4M * kitMod)).linlin(0, 1, 0.01, 1));
					fadeIn  = Lag.kr(mod5.linexp(0, 1, 0.001, 2));
					fadeOut = Lag.kr(mod6.linexp(0, 1, 0.001, 2));
					lpfHz   = Lag.kr(mod7.linexp(0, 1, 20, 20000));
					hpfHz   = Lag.kr(mod8.linexp(0, 1, 20, 20000));

					sendA = Lag.kr(sendA + (sendAM * kitMod)).clip(0, 1);
					sendB = Lag.kr(sendB + (sendBM * kitMod)).clip(0, 1);
					pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

					dist = Lag.kr(dist + (distM * kitMod)).clip(0, 1);
					gain = dist.linlin(0, 1, 12, 24);
					attn = dist.linlin(0, 1, 0, -6);

					// frame math
					plyDir = Select.kr(plyDir < 0.5, [1, -1]);
					rate = Lag3.kr((pitch + tune).midiratio * BufRateScale.kr(buf) * plyDir, rateSlew);
					endRel = (srtRel + lenRel).clip(0.01, 1);
					numFrames = BufFrames.ir(buf);
					srtFrame = numFrames * Select.kr(rate > 0, [endRel, srtRel]);
					endFrame = numFrames * Select.kr(rate > 0, [srtRel, endRel]);
					duckFrames = BufSampleRate.ir(buf) * duckTime * rate.abs;
					sDur = (numFrames * lenRel / rate.abs / 48000) - (fadeIn + fadeOut);

					// envelopes
					envOne = EnvGen.ar(Env.linen(fadeIn, sDur, fadeOut, curve: \sine), gate, doneAction: Select.kr(mode, [2, 0]));
					envHld = EnvGen.ar(Env.asr(fadeIn, 1, fadeOut, curve: \sine), gate, doneAction: Select.kr(mode, [0, 2]));
					envAmp = Select.kr(mode, [envOne, envHld]);

					// phasor
					phasePos = Phasor.ar(gate, rate, srtFrame, endFrame, srtFrame);

					// ducking
					duckGate = Select.ar(rate > 0, [
						InRange.ar(phasePos, endFrame, endFrame + duckFrames),
						InRange.ar(phasePos, endFrame - duckFrames, endFrame)
					]);
					envDuck = EnvGen.ar(Env.new([1, 0, 1], [duckTime], \sine), duckGate);

					// buffer read
					snd = BufRd.ar(2, buf, phasePos, interpolation: 4) * -3.dbamp;

					// eq and distortion
					snd = (snd * (1 - dist)) + ((snd * gain.dbamp).tanh * dist * attn.dbamp);
					snd = RHPF.ar(snd, hpfHz, 0.9);
					snd = RLPF.ar(snd, lpfHz, 0.9);

					// output stage
					snd = snd * envDuck * envAmp;
					snd = snd * vel * amp * mainAmp;
					snd = Balance2.ar(snd[0], snd[1], pan);

					Out.ar(outBus, snd);
					Out.ar(sendABus, snd * sendA);
					Out.ar(sendBBus, snd * sendB);
				});
			);

		}

	}

}