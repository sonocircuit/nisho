// nisho engine for norns
// two synths, a drummachine and sample player
// v2.0 @sonoCircuit

Engine_Nisho : CroneEngine {

	var numMono = 2;
	var numPoly = 6;
	var numKit = 16;

	var kitParams;
	var kitVoiceParams;
	var synthParams;
	var monoParams;
	var polyParams;

	var mainGroup;
	var kitGroup;
	var monoGroup;
	var polyGroup;

	var kitVoices;
	var kitBuffers;
	var kitDef;

	var monoVoices;
	var polyVoices;

	var delayBus;
	var reverbBus;
	var delayFx;
	var reverbFx;
	var nozBuf;
	var sR;

	var loadQueue;
	var loadingSamples = false;

	// inherit from crone class
	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	// allocate to engine
	alloc {

		// create dictionaries
		synthParams = Dictionary.newFrom([
			\level, 1,
			\pan, 0,
			\sendA, 0,
			\sendB, 0,
			\pb_range, 0,
			\pb_depth, 0,

			\saw_tune, 0,
			\saw_shape, 0,
			\saw_lfo_freq, 6,
			\saw_lfo_depth, 0,
			\fm_index, 0,
			\fm_ratio, 1.5,

			\pulse_tune, 0,
			\pulse_width, 0.5,
			\pulse_lfo_freq, 6,
			\pulse_lfo_depth, 0,

			\osc_mix, 0,
			\noise_amp, 0,
			\noise_density, 1,

			\cutoff_lpf, 400,
			\res_lpf, 0.1,
			\env_depth_lpf, 0,
			\keytrack_lpf, 0,
			\cutoff_hpf, 20,
			\res_hpf, 0,
			\env_depth_hpf, 0,
			\keytrack_hpf, 0,

			\env_curve, -1,
			\env_a, 0.01,
			\env_d, 0.2,
			\env_s, 0.6,
			\env_r, 1,

			\mod_wheel, 0,
			\mod_sawshape, 0,
			\mod_pulsewidth, 0,
			\mod_oscmix, 0,
			\mod_noiseamp, 0,
			\mod_lpfcut, 0,
			\mod_hpfcut, 0,
			\mod_sendA, 0,
			\mod_sendB, 0,
			\mod_fm_ratio, 0,
			\mod_fm_index, 0,
			\mod_saw_lfo_depth, 0,
			\mod_pwm_depth, 0,
			\mod_vibrate, 0,
			\mod_vibdepth, 0,

			\menv_amp, 1,
			\menv_curve, -1,
			\menv_h, 0,
			\menv_a, 0.01,
			\menv_d, 0.2,
			\menv_s, 0.6,
			\menv_r, 1,

			\vib_rate, 8,
			\vib_depth, 0,
			\vib_delay, 0,
			\vib_onset, 0.2,

			\freq_drift, 0,
			\cut_drift, 0,
			\env_drift, 0,
			\pan_drift, 0
		]);

		monoParams = Dictionary.newFrom(synthParams);
		polyParams = Dictionary.newFrom(synthParams);

		kitParams = Dictionary.newFrom([
			\mainAmp, 1,
			\amp, 1,
			\pan, 0,
			\sendA, 0,
			\sendB, 0,
			\note, 36,
			\tune, 0,
			\pitch, 0, // uw only
			\mode, 0,  // uw only
			\decay, 0.8,
			\dist, 0,
			\lpfHz, 18000,
			\lpfRz, 0,
			\hpfHz, 220,
			\hpfRz, 0,
			\perfMod, 0,
			\mod1, 0.4,
			\mod2, 0.08,
			\mod3, 0.24,
			\mod4, 0.55,
			\mod5, 0.1,
			\mod6, 0.4,
			\mod1M, 0,
			\mod2M, 0,
			\mod3M, 0,
			\mod4M, 0,
			\mod5M, 0,
			\mod6M, 0,
			\sendAM, 0,
			\sendBM, 0,
			\decayM, 0,
			\distM, 0,
			\lpfM, 0,
			\hpfM, 0
		]);

		kitVoiceParams = Array.fill(numKit, { Dictionary.newFrom(kitParams) });

		// add synthdefs
		SynthDef(\polyForm, {
			arg out, sendABus, sendBBus, delayBus, reverbBus, noiseBfr,
			// levels
			vel = 1, level = 0.2, pan = 0, sendA = 0, sendB = 0,
			// pitch
			freq = 110, pb_range = 0, pb_depth = 0, vib_rate = 6, vib_depth = 0, vib_onset = 0, vib_delay = 0.1,
			// oscillators
			saw_tune = 0, saw_shape = 0.5, saw_lfo_freq = 6, saw_lfo_depth = 0, fm_index = 0, fm_ratio = 1.5,
			pulse_tune = 0, pulse_width = 0.7, pulse_lfo_freq = 6, pulse_lfo_depth = 0,
			osc_mix = 1, noise_amp = 0, noise_density = 1,
			// envelope
			gate = 1, env_curve = -2, env_a = 0, env_d = 2, env_s = 0.5, env_r = 2,
			// modulation
			mod_wheel = 0, mod_oscmix = 0, mod_sawshape = 0, mod_pulsewidth = 0.2,
			mod_noiseamp = 0, mod_lpfcut = 0, mod_hpfcut = 0, mod_vibrate = 0, mod_vibdepth = 0,
			mod_sendA = 0, mod_sendB = 0, mod_fm_index = 0, mod_fm_ratio = 0, mod_saw_lfo_depth = 0, mod_pwm_depth = 0,
			menv_amp = 1, menv_curve = -4, menv_h = 0, menv_a = 0, menv_d = 0.8, menv_s = 0, menv_r = 2,
			// filter
			cutoff_lpf = 800, res_lpf = 0, env_depth_lpf = 0.5, keytrack_lpf = 0,
			cutoff_hpf = 20, res_hpf = 0, env_depth_hpf = 0, keytrack_hpf = 0,
			//drift
			freq_drift = 0, cut_drift = 0, env_drift = 0, pan_drift = 0;

			// variables
			var snd, osc_mod, osc_saw, osc_pulse, osc_noise, freq_saw, freq_pulse, lfo_saw, lfo_pulse,
			key_cut, cut_lin_lpf, cut_lin_hpf, rq_lpf, rq_hpf, env, menv, mod_val, vib_freq, vib_amount;

			// main envelope
			env_d = (env_d + (env_drift * Rand(-0.2, 1.2))).max(0);
			env = EnvGen.kr(Env.adsr(env_a, env_d, env_s, env_r, curve: env_curve), gate, doneAction: 2);

			// mod envelope
			menv = EnvGen.kr(Env.new([0, 0, 1, menv_s, 0], [menv_h, menv_a, menv_d, menv_r], menv_curve, 3), gate) * menv_amp;

			// mod amount
			mod_val = (menv + mod_wheel).clip(0, 1);

			// osc pitch
			key_cut = freq.cpsmidi.linlin(12, 108, 0, 1); // 12-108: used midi range
			vib_freq = (vib_rate + (10 * mod_vibrate)).clip(0.2, 20);
			vib_amount = ((vib_depth + mod_vibdepth) * 0.1).clip(0, 0.1);
			freq = freq + (freq_drift * Rand(-4, 4));
			freq = freq * 2.pow((pb_depth * pb_range) / 12);
			freq = Vibrato.kr(freq, vib_freq, vib_amount, vib_delay, vib_onset);
			freq_saw = Lag.kr(freq * 2.pow(saw_tune / 12), 0.05);
			freq_pulse = Lag.kr(freq * 2.pow(pulse_tune / 12), 0.05);

			// pulse oscillator
			pulse_lfo_depth = (pulse_lfo_depth + (mod_pwm_depth * mod_val)).clip(0, 1);
			lfo_pulse = SinOsc.kr(pulse_lfo_freq, Rand(0, 2pi), 0.44) * pulse_lfo_depth;
			pulse_width = Lag.kr(pulse_width + lfo_pulse + (mod_pulsewidth * mod_val), 0.05).clip(0.06, 0.94);
			osc_pulse = Pulse.ar(freq_pulse, pulse_width);

			// variable sawtooth oscillator
			saw_lfo_depth = (saw_lfo_depth + (mod_saw_lfo_depth * mod_val)).clip(0, 1);
			lfo_saw = SinOsc.kr(saw_lfo_freq, Rand(0, 2pi), 0.5) * saw_lfo_depth;
			saw_shape = Lag.kr(saw_shape.linlin(0, 1, 0.1, 0.9) + lfo_saw + (mod_sawshape * mod_val), 0.05).clip(0.1, 0.9);
			fm_ratio = Lag.kr(fm_ratio + (mod_fm_ratio * mod_val)).clip(0.5, 5);
			fm_index = Lag.kr(fm_index + (mod_fm_index * mod_val)).clip(0, 1);
			osc_mod = SinOsc.ar(freq_saw * fm_ratio, mul: freq_saw * fm_ratio * fm_index);
			osc_saw = VarSaw.ar(freq_saw + osc_mod, saw_shape/2, saw_shape);

			// noise
			osc_noise = PlayBuf.ar(1, noiseBfr, startPos: IRand.new(0, context.server.sampleRate * 6), loop: 1);

			// mix
			osc_mix = Lag.kr((osc_mix + (mod_oscmix * mod_val)).clip(-1, 1));
			noise_amp = Lag.kr((noise_amp + (mod_noiseamp * mod_val)) - 1).clip(-1, 0);
			snd = XFade2.ar(osc_saw, osc_pulse, osc_mix);
			snd = XFade2.ar(snd, osc_noise, noise_amp) * -6.dbamp;

			// low pass filter + modulation
			mod_lpfcut = mod_lpfcut * mod_val;
			cut_lin_lpf = cutoff_lpf.explin(20, 18000, 0, 1);
			cut_lin_lpf = cut_lin_lpf + (env * env_depth_lpf) + mod_lpfcut + (key_cut * keytrack_lpf) + (cut_drift * Rand(0.01, 0.40));
			cutoff_lpf = Lag.kr(cut_lin_lpf.linexp(0, 1, 20, 18000));

			rq_lpf = Lag.kr(res_lpf.linlin(0, 1, 0, 4));
			snd = MoogFF.ar(snd, cutoff_lpf, rq_lpf);

			// high pass filter + modulation
			mod_hpfcut = mod_hpfcut * mod_val;
			cut_lin_hpf = cutoff_hpf.explin(20, 8000, 0, 1);
			cut_lin_hpf = cut_lin_hpf + (env * env_depth_hpf) + mod_hpfcut + (key_cut * keytrack_hpf);
			cutoff_hpf = Lag.kr(cut_lin_hpf.linexp(0, 1, 20, 8000));

			rq_hpf = Lag.kr(res_hpf.linlin(0, 1, 1, 0.01));
			snd = RHPF.ar(snd, cutoff_hpf, rq_hpf);

			// pan & levels
			pan = Lag.kr(pan + (pan_drift * Rand(-0.7, 0.7))).clip(-1, 1);
			level = Lag.kr(level);
			sendA = Lag.kr(sendA + (mod_sendA * mod_val)).clip(0, 1);
			sendB = Lag.kr(sendB + (mod_sendB * mod_val)).clip(0, 1);

			snd = (snd * env * level * vel).tanh;
			snd = Pan2.ar(snd, pan);

			Out.ar(out, snd);
			Out.ar(sendABus, sendA * snd);
			Out.ar(sendBBus, sendB * snd);
		}).add;

		// fm algos – roughly based on EFM-MD paper
		SynthDef(\drmfm_BD,{
			arg out, sendABus, sendBBus, nWbfr, nSbfr, nRbfr, nBbfr,
			mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0, note = 36, tune = 0,
			gate = 1, decay = 0.8, decRnd = 0, dist = 0, lpfHz = 18000, lpfRz = 0, hpfHz = 20, hpfRz = 0,
			mod1 = 0.4, mod2 = 0.08, mod3 = 0.24, mod4 = 0.55, mod5 = 0.1, mod6 = 0.4,
			perfMod = 0, mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0,
			sendAM = 0, sendBM = 0, decayM = 0, distM = 0, lpfM = 0, hpfM = 0;

			var atk = 0.001, carCrv = -4, modCrv = -4, frqCrv = -4, frqMul = 3.6;
			var att, boost, hz, mod, car, snd, carEnv, modEnv, frqEnv, lpfQ, hpfQ;

			// rescale, smooth, clamp
			var frqDepth = (mod1 + (mod1M * perfMod)).clip(0, 1);
			var frqDecay = (mod2 + (mod2M * perfMod)).clip(0, 1);
			var modDepth = (mod3 + (mod3M * perfMod)).clip(0, 1);
			var modRatio = (mod4 + (mod4M * perfMod)).linlin(0, 1, 1, 5);
			var modDecay = (mod5 + (mod5M * perfMod)).clip(0, 1);
			var modFb = (mod6 + (mod6M * perfMod)).linlin(0, 1, 0, 10);

			lpfHz = (lpfHz.explin(20, 18000, 0, 1) + (lpfM * perfMod)).linexp(0, 1, 20, 18000);
			hpfHz = (hpfHz.explin(20, 18000, 0, 1) + (hpfM * perfMod)).linexp(0, 1, 20, 18000);
			lpfQ = lpfRz.linlin(0, 1, 1, 0.1);
			hpfQ = hpfRz.linlin(0, 1, 1, 0.1);

			decay = (decay + (decayM * 8 * perfMod) + (decRnd * Rand(0.2, 1.2))).clip(0, 8);
			sendA = (sendA + (sendAM * perfMod)).clip(0, 1);
			sendB = (sendB + (sendBM * perfMod)).clip(0, 1);
			pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

			dist = (dist + (distM * perfMod)).clip(0, 1);
			boost = dist.linlin(0, 1, 12, 24);
			att = dist.linlin(0, 1, 0, -6);

			// envelopes
			carEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay], [carCrv.neg, carCrv]), gate, doneAction: 2);
			modEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, modDecay * decay], [modCrv.neg, modCrv])) * modDepth;
			frqEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, frqDecay * decay], [frqCrv.neg, frqCrv])) * frqDepth;

			// pitch
			hz = (note + tune).midicps;
			hz = (hz + (hz * frqMul * frqEnv)).clip(20, 12000);

			// modulator
			mod = SinOscFB.ar(hz * modRatio, modFb) * hz * modRatio * modEnv;

			// carrier
			car = SinOsc.ar(hz + mod, pi/2) * carEnv;

			// distortion & filter
			snd = (car * (1 - dist) + ((car * boost.dbamp).tanh * dist)) * att.dbamp;
			snd = RHPF.ar(snd, hpfHz, hpfQ);
			snd = RLPF.ar(snd, lpfHz, lpfQ);

			// output stage
			snd = snd * vel * amp * mainAmp;
			snd = Pan2.ar(snd, pan);

			Out.ar(out, snd);
			Out.ar(sendABus, snd * sendA);
			Out.ar(sendBBus, snd * sendB);
		}).add;

		SynthDef(\drmfm_SD,{
			arg out, sendABus, sendBBus, nWbfr, nSbfr, nRbfr, nBbfr,
			mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0, note = 36, tune = 0,
			gate = 1, decay = 0.8, decRnd = 0, dist = 0, lpfHz = 18000, lpfRz = 0, hpfHz = 20, hpfRz = 0,
			mod1 = 0.4, mod2 = 0.08, mod3 = 0.24, mod4 = 0.55, mod5 = 0.1, mod6 = 0.4,

			perfMod = 0, mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0,
			sendAM = 0, sendBM = 0, decayM = 0, distM = 0, lpfM = 0, hpfM = 0;

			var atk = 0.001, carCrv = -4, modCrv = -4, nozCrv = -4, mixHpHz = 360, modFb = 12;
			var att, boost, hz, mod, car, wNoz, bNoz, noz, snd, carEnv, modEnv, nozEnv, lpfQ, hpfQ;

			var nozDepth = (mod1 + (mod1M * perfMod)).linlin(0, 1, 0, 2);
			var nozDecay = (mod2 + (mod2M * perfMod)).linlin(0, 1, 0, 2);
			var nozColor = (mod3 + (mod3M * perfMod)).linlin(0, 1, -1, 1);
			var modDepth = (mod4 + (mod4M * perfMod)).clip(0, 1);
			var modRatio = (mod5 + (mod5M * perfMod)).linlin(0, 1, 1, 10);
			var modDecay = (mod6 + (mod6M * perfMod)).linlin(0, 2, 0, 2);

			lpfHz = (lpfHz.explin(20, 18000, 0, 1) + (lpfM * perfMod)).linexp(0, 1, 20, 18000);
			hpfHz = (hpfHz.explin(20, 18000, 0, 1) + (hpfM * perfMod)).linexp(0, 1, 20, 18000);
			lpfQ = lpfRz.linlin(0, 1, 1, 0.1);
			hpfQ = hpfRz.linlin(0, 1, 1, 0.1);

			decay = (decay + (decayM * 8 * perfMod) + (decRnd * Rand(0.2, 1.2))).clip(0, 8);
			sendA = (sendA + (sendAM * perfMod)).clip(0, 1);
			sendB = (sendB + (sendBM * perfMod)).clip(0, 1);
			pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

			dist = (dist + (distM * perfMod)).clip(0, 1);
			boost = dist.linlin(0, 1, 12, 24);
			att = dist.linlin(0, 1, 0, -6);

			// envelopes
			carEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay], [carCrv.neg, carCrv]), gate, doneAction: 2);
			modEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, modDecay * decay], [modCrv.neg, modCrv])) * modDepth;
			nozEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, nozDecay * decay], [nozCrv.neg, nozCrv])) * nozDepth;

			// pitch
			hz = (note + tune).midicps;

			// modulator
			mod = SinOscFB.ar(hz * modRatio, modFb) * hz * modRatio * modEnv;

			// noise
			wNoz = PlayBuf.ar(1, nWbfr, startPos: IRand.new(0, context.server.sampleRate * 6), loop: 1);
			bNoz = PlayBuf.ar(1, nBbfr, startPos: IRand.new(0, context.server.sampleRate * 6), loop: 1);
			noz = XFade2.ar(wNoz, bNoz, nozColor) * nozEnv;

			// carrier
			car = SinOsc.ar(hz + mod, pi/2) * carEnv * -6.dbamp;

			// mix & hpf
			snd = Mix.ar([car, noz]);
			snd = HPF.ar(snd, mixHpHz);

			// distortion & filter
			snd = (snd * (1 - dist) + ((snd * boost.dbamp).tanh * dist)) * att.dbamp;
			snd = RHPF.ar(snd, hpfHz, hpfQ);
			snd = RLPF.ar(snd, lpfHz, lpfQ);

			// output stage
			snd = snd * vel * amp * mainAmp;
			snd = Pan2.ar(snd, pan);

			Out.ar(out, snd);
			Out.ar(sendABus, snd * sendA);
			Out.ar(sendBBus, snd * sendB);
		}).add;

		SynthDef(\drmfm_XT,{
			arg out, sendABus, sendBBus, nWbfr, nSbfr, nRbfr, nBbfr,
			mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0, note = 36, tune = 0,
			gate = 1, decay = 0.8, decRnd = 0, dist = 0, lpfHz = 18000, lpfRz = 0, hpfHz = 20, hpfRz = 0,
			mod1 = 0.4, mod2 = 0.08, mod3 = 0.24, mod4 = 0.55, mod5 = 0.1, mod6 = 0.4,
			perfMod = 0, mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0,
			sendAM = 0, sendBM = 0, decayM = 0, distM = 0, lpfM = 0, hpfM = 0;

			var atk = 0.001, carCrv = -2, modCrv = -2, frqCrv = -2, frqMul = 3.6, modFb = 8;
			var att, boost, hz, mod, car, snd, carEnv, modEnv, frqEnv, lpfQ, hpfQ;

			// rescale, smooth, clamp
			var frqDepth = (mod1 + (mod1M * perfMod)).linlin(0, 1, -1, 1);
			var frqDecay = (mod2 + (mod2M * perfMod)).linlin(0, 1, 0, 2);
			var initClik = (mod3 + (mod3M * perfMod)).linlin(0, 1, 0, pi/2);
			var modDepth = (mod4 + (mod4M * perfMod)).clip(0, 1);
			var modRatio = (mod5 + (mod5M * perfMod)).linlin(0, 1, 1, 6);
			var modDecay = (mod6 + (mod6M * perfMod)).linlin(0, 1, 0, 2);

			lpfHz = (lpfHz.explin(20, 18000, 0, 1) + (lpfM * perfMod)).linexp(0, 1, 20, 18000);
			hpfHz = (hpfHz.explin(20, 18000, 0, 1) + (hpfM * perfMod)).linexp(0, 1, 20, 18000);
			lpfQ = lpfRz.linlin(0, 1, 1, 0.1);
			hpfQ = hpfRz.linlin(0, 1, 1, 0.1);

			decay = (decay + (decayM * 8 * perfMod) + (decRnd * Rand(0.2, 1.2))).clip(0, 8);
			sendA = (sendA + (sendAM * perfMod)).clip(0, 1);
			sendB = (sendB + (sendBM * perfMod)).clip(0, 1);
			pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

			dist = (dist + (distM * perfMod)).clip(0, 1);
			boost = dist.linlin(0, 1, 12, 24);
			att = dist.linlin(0, 1, 0, -6);

			// envelopes
			carEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay], [carCrv.neg, carCrv]), gate, doneAction: 2);
			modEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, modDecay * decay], [modCrv.neg, modCrv])) * modDepth;
			frqEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, frqDecay * decay], [frqCrv.neg, frqCrv])) * frqDepth;

			// pitch
			hz = (note + tune).midicps;
			hz = (hz + (hz * frqMul * frqEnv)).clip(20, 12000);

			// modulator
			mod = SinOscFB.ar(hz * modRatio, modFb) * hz * modRatio * modEnv;

			// carrier
			car = SinOsc.ar(hz + mod, initClik) * -6.dbamp * carEnv;

			// distortion & filter
			snd = (car * (1 - dist) + ((car * boost.dbamp).tanh * dist)) * att.dbamp;
			snd = RHPF.ar(snd, hpfHz, hpfQ);
			snd = RLPF.ar(snd, lpfHz, lpfQ);

			// output stage
			snd = snd * vel * amp * mainAmp;
			snd = Pan2.ar(snd, pan);

			Out.ar(out, snd);
			Out.ar(sendABus, snd * sendA);
			Out.ar(sendBBus, snd * sendB);
		}).add;

		SynthDef(\drmfm_CP,{
			arg out, sendABus, sendBBus, nWbfr, nSbfr, nRbfr, nBbfr,
			mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0, note = 36, tune = 0,
			gate = 1, decay = 0.8, decRnd = 0, dist = 0, lpfHz = 18000, lpfRz = 0, hpfHz = 20, hpfRz = 0,
			mod1 = 0.4, mod2 = 0.08, mod3 = 0.24, mod4 = 0.55, mod5 = 0.1, mod6 = 0.4,
			perfMod = 0, mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0,
			sendAM = 0, sendBM = 0, decayM = 0, distM = 0, lpfM = 0, hpfM = 0;

			var atk = 0.001, carCrv = -4, modCrv = -4, clpCrv = -8, modFb = 12, maxClps = 12;
			var att, boost, hz, mod, car, noz, snd, carEnv, modEnv, preEnv, clpEnv, preClpDur, preClpLevels, preClpTimes, lpfQ, hpfQ;

			// rescale, smooth, clamp
			var clpNum = (mod1 + (mod1M * perfMod)).linlin(0, 1, 1, maxClps).round;
			var clpDecay = (mod2 + (mod2M * perfMod)).linlin(0, 1, 0, 0.1);
			var nozLevel = (mod3 + (mod3M * perfMod)).clip(0, 1);
			var modDepth = (mod4 + (mod4M * perfMod)).linlin(0, 1, 1, 2);
			var modRatio = (mod5 + (mod5M * perfMod)).linlin(0, 1, 1, 10);
			var modDecay = (mod6 + (mod6M * perfMod)).linlin(0, 1, 0, 2);

			lpfHz = (lpfHz.explin(20, 18000, 0, 1) + (lpfM * perfMod)).linexp(0, 1, 20, 18000);
			hpfHz = (hpfHz.explin(20, 18000, 0, 1) + (hpfM * perfMod)).linexp(0, 1, 20, 18000);
			lpfQ = lpfRz.linlin(0, 1, 1, 0.1);
			hpfQ = hpfRz.linlin(0, 1, 1, 0.1);

			decay = (decay + (decayM * 8 * perfMod) + (decRnd * Rand(0.2, 1.2))).clip(0, 8);
			sendA = (sendA + (sendAM * perfMod)).clip(0, 1);
			sendB = (sendB + (sendBM * perfMod)).clip(0, 1);
			pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

			dist = (dist + (distM * perfMod)).clip(0, 1);
			boost = dist.linlin(0, 1, 12, 24);
			att = dist.linlin(0, 1, 0, -6);

			preClpDur = clpDecay * (clpNum - 1);
			preClpLevels = Array.fill(maxClps, { [1, 0.24] }).flat;
			preClpTimes  = Array.fill(maxClps, { [0.001, clpDecay] }).flat;

			// envelopes
			carEnv = EnvGen.ar(Env.linen(atk, preClpDur, decay, curve: -4), gate, doneAction: 2);
			modEnv = EnvGen.ar(Env.linen(atk, preClpDur, modDecay * decay, curve: modCrv)) * modDepth;
			preEnv = EnvGen.ar(Env.new(
				levels: [0] ++ preClpLevels ++ [0],
				times:  preClpTimes ++ [decay],
				curve: clpCrv));
			clpEnv = Select.ar(EnvGen.ar(Env.new([0, 0, 1], [preClpDur, 0]));, [preEnv, carEnv]);

			// pitch
			hz = (note + tune).midicps;

			// modulator
			mod = SinOscFB.ar(hz * modRatio, modFb) * hz * modRatio * (modEnv + modDepth);

			// carrier
			car = SinOsc.ar(hz + mod, pi/2);

			//noise
			noz = PlayBuf.ar(1, nRbfr, startPos: IRand.new(0, context.server.sampleRate * 6), loop: 1) * nozLevel;

			// mix
			snd = (car + noz) * -9.dbamp * clpEnv;

			// distortion & filter
			snd = (snd * (1 - dist) + ((snd * boost.dbamp).tanh * dist)) * att.dbamp;
			snd = RHPF.ar(snd, hpfHz, hpfQ);
			snd = RLPF.ar(snd, lpfHz, lpfQ);

			// output stage
			snd = snd * vel * amp;
			snd = Pan2.ar(snd, pan);

			Out.ar(out, snd);
			Out.ar(sendABus, snd * sendA);
			Out.ar(sendBBus, snd * sendB);
		}).add;

		SynthDef(\drmfm_RS,{
			arg out, sendABus, sendBBus, nWbfr, nSbfr, nRbfr, nBbfr,
			mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0, note = 36, tune = 0,
			gate = 1, decay = 0.8, decRnd = 0, dist = 0, lpfHz = 18000, lpfRz = 0, hpfHz = 20, hpfRz = 0,
			mod1 = 0.4, mod2 = 0.08, mod3 = 0.24, mod4 = 0.55, mod5 = 0.1, mod6 = 0.4,
			perfMod = 0, mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0,
			sendAM = 0, sendBM = 0, decayM = 0, distM = 0, lpfM = 0, hpfM = 0;

			var atk = 0.001, rimCrv = -4, snrCrv = -4, modFbRim = 2, modFbSnr = 8, modRatioSnr = 4.42;
			var att, boost, hzRim, hzSnr, modRim, modSnr, carRim, carSnr, snd, rimEnv, snrEnv, lpfQ, hpfQ;

			// rescale, smooth, clamp
			var rimMod = (mod1 + (mod1M * perfMod)).linlin(0, 1, 1, 2);
			var modRatioRim = (mod2 + (mod2M * perfMod)).linlin(0, 1, 1, 5);
			var snrAmp = (mod3 + (mod3M * perfMod)).clip(0, 1);
			var snrDecay = (mod4 + (mod4M * perfMod)).linlin(0, 1, 0, 2);
			var snrMod = (mod5 + (mod5M * perfMod)).linlin(0, 1, 0.4, 6);
			var snrRatio = (mod6 + (mod6M * perfMod)).linlin(0, 1, 1, 10);

			lpfHz = (lpfHz.explin(20, 18000, 0, 1) + (lpfM * perfMod)).linexp(0, 1, 20, 18000);
			hpfHz = (hpfHz.explin(20, 18000, 0, 1) + (hpfM * perfMod)).linexp(0, 1, 20, 18000);
			lpfQ = lpfRz.linlin(0, 1, 1, 0.1);
			hpfQ = hpfRz.linlin(0, 1, 1, 0.1);

			decay = (decay + (decayM * 4 * perfMod) + (decRnd * Rand(0.2, 1.2))).clip(0, 8);
			sendA = (sendA + (sendAM * perfMod)).clip(0, 1);
			sendB = (sendB + (sendBM * perfMod)).clip(0, 1);
			pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

			dist = (dist + (distM * perfMod)).clip(0, 1);
			boost = dist.linlin(0, 1, 12, 24);
			att = dist.linlin(0, 1, 0, -6);

			// envelopes
			rimEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay], [rimCrv.neg, rimCrv]), gate, doneAction: 2);
			snrEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, snrDecay * decay], [snrCrv.neg, snrCrv])) * snrAmp;

			// pitch
			hzRim = (note + tune).midicps;
			hzSnr = hzRim * snrRatio;

			// modulator
			modRim = SinOscFB.ar(hzRim * modRatioRim, modFbRim) * hzRim * modRatioRim * rimMod;
			modSnr = SinOscFB.ar(hzSnr * modRatioSnr, modFbSnr) * hzSnr * modRatioSnr * snrMod;

			// carrier
			carRim = SinOsc.ar(hzRim + modRim, 0) * rimEnv;
			carSnr = SinOsc.ar(hzSnr + modSnr, 0) * snrEnv;

			// mix
			snd = (carRim + carSnr) * -9.dbamp;

			// distortion & filter
			snd = (snd * (1 - dist) + ((snd * boost.dbamp).tanh * dist)) * att.dbamp;
			snd = RHPF.ar(snd, hpfHz, hpfQ);
			snd = RLPF.ar(snd, lpfHz, lpfQ);

			// output stage
			snd = snd * vel * amp * mainAmp;
			snd = Pan2.ar(snd, pan);

			Out.ar(out, snd);
			Out.ar(sendABus, snd * sendA);
			Out.ar(sendBBus, snd * sendB);
		}).add;

		SynthDef(\drmfm_CB,{
			arg out, sendABus, sendBBus, nWbfr, nSbfr, nRbfr, nBbfr,
			mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0, note = 36, tune = 0,
			gate = 1, decay = 0.8, decRnd = 0, dist = 0, lpfHz = 18000, lpfRz = 0, hpfHz = 20, hpfRz = 0,
			mod1 = 0.4, mod2 = 0.08, mod3 = 0.24, mod4 = 0.55, mod5 = 0.1, mod6 = 0.4,
			perfMod = 0, mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0,
			sendAM = 0, sendBM = 0, decayM = 0, distM = 0, lpfM = 0, hpfM = 0;

			var atk = 0.001, modCrv = -4, priCrv = -4, secCrv = -8, secDecf = 0.62;
			var att, boost, hzA, hzB, modA, modB, carA, carB, snd, modEnv, priEnv, secEnv, lpfQ, hpfQ;

			// rescale, smooth, clamp
			var secAmp = (mod1 + (mod1M * perfMod)).clip(0, 1);
			var carFb = (mod2 + (mod2M * perfMod)).linlin(0, 1, 0, 10);
			var carDetn = (mod3 + (mod3M * perfMod)).linlin(0, 1, 0, 4).round;
			var modDepth = (mod4 + (mod4M * perfMod)).linlin(0, 1, 0, 2);
			var modRatio = (mod5 + (mod5M * perfMod)).linlin(0, 1, 1, 10);
			var modDecay = (mod6 + (mod6M * perfMod)).linlin(0, 1, 0, 2);

			lpfHz = (lpfHz.explin(20, 18000, 0, 1) + (lpfM * perfMod)).linexp(0, 1, 20, 18000);
			hpfHz = (hpfHz.explin(20, 18000, 0, 1) + (hpfM * perfMod)).linexp(0, 1, 20, 18000);
			lpfQ = lpfRz.linlin(0, 1, 1, 0.1);
			hpfQ = hpfRz.linlin(0, 1, 1, 0.1);

			decay = (decay + (decayM * 4 * perfMod) + (decRnd * Rand(0.2, 1.2))).clip(0, 8);
			sendA = (sendA + (sendAM * perfMod)).clip(0, 1);
			sendB = (sendB + (sendBM * perfMod)).clip(0, 1);
			pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

			dist = (dist + (distM * perfMod)).clip(0, 1);
			boost = dist.linlin(0, 1, 12, 24);
			att = dist.linlin(0, 1, 0, -6);

			// envelopes
			priEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay], [priCrv.neg, priCrv]), gate, doneAction: 2) * (1 - secAmp);
			secEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay * secDecf], [secCrv.neg, secCrv])) * secAmp;
			modEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay * modDecay], [modCrv.neg, modCrv])) * modDepth;

			// pitch
			hzA = (note + tune).midicps;
			hzB = hzA * 1.48 * carDetn;

			// modulators
			modA = SinOsc.ar(hzA * modRatio) * hzA * modRatio * modEnv;
			modB = SinOsc.ar(hzB * modRatio) * hzB * modRatio * modEnv;

			// carrier
			carA = SinOscFB.ar(hzA + modA, carFb);
			carB = SinOscFB.ar(hzB + modB, carFb);

			// mix
			snd = (carA + carB) * -9.dbamp * (priEnv + secEnv);

			// distortion & filter
			snd = (snd * (1 - dist) + ((snd * boost.dbamp).tanh * dist)) * att.dbamp;
			snd = RHPF.ar(snd, hpfHz, hpfQ);
			snd = RLPF.ar(snd, lpfHz, lpfQ);

			// output stage
			snd = snd * vel * amp * mainAmp;
			snd = Pan2.ar(snd, pan);

			Out.ar(out, snd);
			Out.ar(sendABus, snd * sendA);
			Out.ar(sendBBus, snd * sendB);
		}).add;

		SynthDef(\drmfm_CY,{
			arg out, sendABus, sendBBus, nWbfr, nSbfr, nRbfr, nBbfr,
			mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0, note = 36, tune = 0,
			gate = 1, decay = 0.8, decRnd = 0, dist = 0, lpfHz = 18000, lpfRz = 0, hpfHz = 20, hpfRz = 0,
			mod1 = 0.4, mod2 = 0.08, mod3 = 0.24, mod4 = 0.55, mod5 = 0.1, mod6 = 0.4,
			perfMod = 0, mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0,
			sendAM = 0, sendBM = 0, decayM = 0, distM = 0, lpfM = 0, hpfM = 0;

			var atk = 0.001, modCrv = -12, carCrv = -12;
			var att, boost, hzA, hzB, hzC, hzD, mod, carA, carB, carC, carD, noz, snd, modEnv, carEnv, lpfQ, hpfQ;

			// rescale, smooth, clamp
			var envSat = (mod1 + (mod1M * perfMod)).linlin(0, 1, 1, 2);
			var nozLevel = (mod2 + (mod2M * perfMod)).clip(0, 1);
			var tone = (mod3 + (mod3M * perfMod)).linexp(0, 1, 2200, 8800);
			var modDepth = (mod4 + (mod4M * perfMod)).linlin(0, 1, 0.1, 1);
			var modRatio = (mod5 + (mod5M * perfMod)).linlin(0, 1, 1.8, 2.2);
			var modDecay = (mod6 + (mod6M * perfMod)).linlin(0, 1, 1, 4);

			lpfHz = (lpfHz.explin(20, 18000, 0, 1) + (lpfM * perfMod)).linexp(0, 1, 20, 18000);
			hpfHz = (hpfHz.explin(20, 18000, 0, 1) + (hpfM * perfMod)).linexp(0, 1, 20, 18000);
			lpfQ = lpfRz.linlin(0, 1, 1, 0.1);
			hpfQ = hpfRz.linlin(0, 1, 1, 0.1);

			decay = (decay + (decayM * 8 * perfMod) + (decRnd * Rand(0.2, 1.2))).clip(0, 8);
			sendA = (sendA + (sendAM * perfMod)).clip(0, 1);
			sendB = (sendB + (sendBM * perfMod)).clip(0, 1);
			pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

			dist = (dist + (distM * perfMod)).clip(0, 1);
			boost = dist.linlin(0, 1, 12, 24);
			att = dist.linlin(0, 1, 0, -6);

			// envelopes
			carEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay], [carCrv.neg, carCrv]), gate, doneAction: 2);
			modEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay * modDecay], [modCrv.neg, modCrv])) * modDepth;
			carEnv = (carEnv * envSat).clip(0, 1);

			// pitch
			hzA = (note + tune).midicps;
			hzB = hzA * 1.48;
			hzC = hzA * 1.79;
			hzD = hzA * 2.64;

			// modulator
			mod = SinOsc.ar(hzA * modRatio) * hzD * modRatio * modEnv;

			// carrier
			carA = LFPulse.ar(hzA + mod);
			carB = LFPulse.ar(hzB + mod);
			carC = LFPulse.ar(hzC + mod);
			carD = LFPulse.ar(hzD + mod);

			// noise
			noz = PlayBuf.ar(1, nRbfr, startPos: IRand.new(0, context.server.sampleRate * 6), loop: 1).range(1, 1 - nozLevel);

			// mix & tone
			snd = (carA + carB + carC + carD) * -14.dbamp;
			snd = snd * noz * carEnv;
			snd = HPF.ar(snd, 2200);
			snd = BPeakEQ.ar(snd, tone, 1, 9);

			// distortion & filter
			snd = (snd * (1 - dist) + ((snd * boost.dbamp).tanh * dist)) * att.dbamp;
			snd = RHPF.ar(snd, hpfHz, hpfQ);
			snd = RLPF.ar(snd, lpfHz, lpfQ);

			// output stage
			snd = snd * vel * amp * mainAmp;
			snd = Pan2.ar(snd, pan);

			Out.ar(out, snd);
			Out.ar(sendABus, snd * sendA);
			Out.ar(sendBBus, snd * sendB);
		}).add;

		SynthDef(\drmfm_HH,{
			arg out, sendABus, sendBBus, nWbfr, nSbfr, nRbfr, nBbfr,
			mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0, note = 36, tune = 0,
			gate = 1, decay = 0.8, decRnd = 0, dist = 0, lpfHz = 18000, lpfRz = 0, hpfHz = 20, hpfRz = 0,
			mod1 = 0.4, mod2 = 0.08, mod3 = 0.24, mod4 = 0.55, mod5 = 0.1, mod6 = 0.4,
			perfMod = 0, mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0,
			sendAM = 0, sendBM = 0, decayM = 0, distM = 0, lpfM = 0, hpfM = 0;

			var atk = 0.001, modCrv = -10, carCrv = -12;
			var att, boost, hzA, hzB, hzC, hzD, mod, carA, carB, carC, carD, snd, modEnv, carEnv, lpfQ, hpfQ;

			// rescale, smooth, clamp
			var envSat = (mod1 + (mod1M * perfMod)).linlin(0, 1, 1, 2);
			var carFb = (mod2 + (mod2M * perfMod)).linlin(0, 1, 4, 10);
			var tone = (mod3 + (mod3M * perfMod)).linexp(0, 1, 2200, 8800);
			var modDepth = (mod4 + (mod4M * perfMod)).linlin(0, 1, 0.2, 2);
			var modRatio = (mod5 + (mod5M * perfMod)).linlin(0, 1, 2, 12);
			var modDecay = (mod6 + (mod6M * perfMod)).linlin(0, 1, 0, 2.4);

			lpfHz = (lpfHz.explin(20, 18000, 0, 1) + (lpfM * perfMod)).linexp(0, 1, 20, 18000);
			hpfHz = (hpfHz.explin(20, 18000, 0, 1) + (hpfM * perfMod)).linexp(0, 1, 20, 18000);
			lpfQ = lpfRz.linlin(0, 1, 1, 0.1);
			hpfQ = hpfRz.linlin(0, 1, 1, 0.1);

			decay = (decay + (decayM * 8 * perfMod) + (decRnd * Rand(0.2, 1.2))).clip(0, 8);
			sendA = (sendA + (sendAM * perfMod)).clip(0, 1);
			sendB = (sendB + (sendBM * perfMod)).clip(0, 1);
			pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

			dist = (dist + (distM * perfMod)).clip(0, 1);
			boost = dist.linlin(0, 1, 12, 24);
			att = dist.linlin(0, 1, 0, -6);

			// envelopes
			modEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay * modDecay], [modCrv.neg, modCrv])) * modDepth;
			carEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay], [carCrv.neg, carCrv]), gate, doneAction: 2);
			carEnv = (carEnv * envSat).clip(0, 1);

			// pitch
			hzA = (note + tune).midicps;
			hzB = hzA * 1.79;
			hzC = hzA * 1.48;
			hzD = hzA * 2.64;

			// modulator
			mod = LFTri.ar(hzD * modRatio) * hzA * modRatio * modEnv;

			// carrier
			carA = SinOscFB.ar(hzA + mod, carFb);
			carB = SinOscFB.ar(hzB + mod, carFb);
			carC = SinOscFB.ar(hzC + mod, carFb);
			carD = SinOscFB.ar(hzD + mod, carFb);

			// mix & tone
			snd = (carA + carB + carC + carD) * -14.dbamp * carEnv;
			snd = HPF.ar(snd, 1600);
			snd = BPeakEQ.ar(snd, tone, 1, 6);

			// distortion & filter
			snd = (snd * (1 - dist) + ((snd * boost.dbamp).tanh * dist)) * att.dbamp;
			snd = RHPF.ar(snd, hpfHz, hpfQ);
			snd = RLPF.ar(snd, lpfHz, lpfQ);

			// output stage
			snd = snd * vel * amp * mainAmp;
			snd = Pan2.ar(snd, pan);

			Out.ar(out, snd);
			Out.ar(sendABus, snd * sendA);
			Out.ar(sendBBus, snd * sendB);
		}).add;

		// crushed olican
		SynthDef(\drmfm_OC,{
			arg out, sendABus, sendBBus, nWbfr, nSbfr, nRbfr, nBbfr,
			mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0, note = 36, tune = 0,
			gate = 1, decay = 0.8, decRnd = 0, dist = 0, lpfHz = 18000, lpfRz = 0, hpfHz = 20, hpfRz = 0,
			mod1 = 0.4, mod2 = 0.08, mod3 = 0.24, mod4 = 0.55, mod5 = 0.1, mod6 = 0.4,
			perfMod = 0, mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0,
			sendAM = 0, sendBM = 0, decayM = 0, distM = 0, lpfM = 0, hpfM = 0;

			var atk = 0.001, carCrv = -4, modCrv = -4;
			var att, boost, hz, mod, car, noz, snd, carEnv, modEnv, nozEnv, lpfQ, hpfQ;

			// rescale, smooth, clamp
			var nozDepth = (mod1 + (mod1M * perfMod)).clip(0, 1);
			var wavFold = (mod2 + (mod2M * perfMod)).linlin(0, 1, 1, 6);
			var modDest = (mod3 + (mod3M * perfMod)).clip(0, 1);
			var modDepth = (mod4 + (mod4M * perfMod)).linlin(0, 1, -1, 1);
			var modRatio = (mod5 + (mod5M * perfMod)).linlin(0, 1, 1, 10);
			var modDecay = (mod6 + (mod6M * perfMod)).linlin(0, 1, 0, 2);

			lpfHz = (lpfHz.explin(20, 18000, 0, 1) + (lpfM * perfMod)).linexp(0, 1, 20, 18000);
			hpfHz = (hpfHz.explin(20, 18000, 0, 1) + (hpfM * perfMod)).linexp(0, 1, 20, 18000);
			lpfQ = lpfRz.linlin(0, 1, 1, 0.1);
			hpfQ = hpfRz.linlin(0, 1, 1, 0.1);

			decay = (decay + (decayM * 8 * perfMod) + (decRnd * Rand(0.2, 1.2))).clip(0, 8);
			sendA = (sendA + (sendAM * perfMod)).clip(0, 1);
			sendB = (sendB + (sendBM * perfMod)).clip(0, 1);
			pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

			dist = (dist + (distM * perfMod)).clip(0, 1);
			boost = dist.linlin(0, 1, 12, 24);
			att = dist.linlin(0, 1, 0, -6);

			// envelopes
			carEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, decay], [carCrv.neg, carCrv]), gate, doneAction: 2);
			modEnv = EnvGen.ar(Env.new([0, 1, 0], [atk, modDecay * decay], [modCrv.neg, modCrv])) * modDepth;

			// pitch
			hz = (note + tune).midicps;
			hz = (hz + (carEnv * hz * modDepth)).clip(20, 12000);

			// modulator
			mod = SinOscFB.ar(hz * modRatio, modDest.linlin(0, 1, 0, 4));
			mod = Fold.ar(mod * wavFold, -1, 1) * modEnv;

			// carrier
			car = SinOsc.ar(hz + (mod * 10000 * modDest));

			// noise gen
			noz = PlayBuf.ar(1, nSbfr, startPos: IRand.new(0, context.server.sampleRate * 6), loop: 1).range(1, 1 - nozDepth);

			// mix & fold
			snd = Mix.ar([car, (mod * (1 - modDest))]) * carEnv;
			snd = Fold.ar(snd * wavFold * noz, -1, 1);

			// distortion & filter
			snd = (snd * (1 - dist) + ((snd * boost.dbamp).tanh * dist)) * att.dbamp;
			snd = RHPF.ar(snd, hpfHz, hpfQ);
			snd = RLPF.ar(snd, lpfHz, lpfQ);

			// output stage
			snd = snd * vel * amp * mainAmp;
			snd = Pan2.ar(snd, pan);

			Out.ar(out, snd);
			Out.ar(sendABus, snd * sendA);
			Out.ar(sendBBus, snd * sendB);
		}).add;

		// user wav synthDef - sample playback
		SynthDef(\drmfm_UW_mono,{
			arg out = 0, sendABus, sendBBus,
			mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0, pitch = 0, gate = 1,
			mode = 0, bfr = 0, dist = 0, lpfHz = 18000, lpfRz = 0, hpfHz = 220, hpfRz = 0,
			mod1 = 0.5, mod2 = 0.4, mod3 = 0.24, mod4 = 1, mod5 = 0.3, mod6 = 0.05,
			perfMod = 0, mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0,
			sendAM = 0, sendBM = 0, decayM = 0, distM = 0, lpfM = 0, hpfM = 0;

			var rate, numFrames, srtFrame, endFrame, endRel, envOne, envHld, envAmp, sDur, phasePos;
			var att, boost, snd, lpfQ, hpfQ, duckFrames, duckGate, envDuck, duckTime = 0.01, rateSlew = 0.2;

			// rescale, smooth, clamp
			var tune = Lag.kr(mod1.linlin(0, 1, -1, 1) + (12 * mod1M * perfMod)).clip(-12, 12);
			var plyDir = Lag.kr((mod2 + (mod2M * perfMod)).clip(0, 1));
			var srtRel = Lag.kr((mod3 + (mod3M * perfMod)).linlin(0, 1, 0, 0.99));
			var lenRel = Lag.kr((mod4 + (mod4M * perfMod)).linlin(0, 1, 0.01, 1));
			var fadeIn = Lag.kr(mod5.linexp(0, 1, 0.01, 2));
			var fadeOut = Lag.kr(mod6.linexp(0, 1, 0.01, 2));

			lpfHz = Lag.kr((lpfHz.explin(20, 18000, 0, 1) + (lpfM * perfMod)).linexp(0, 1, 20, 18000));
			hpfHz = Lag.kr((hpfHz.explin(20, 18000, 0, 1) + (hpfM * perfMod)).linexp(0, 1, 20, 18000));
			lpfQ = Lag.kr(lpfRz.linlin(0, 1, 1, 0.1));
			hpfQ = Lag.kr(hpfRz.linlin(0, 1, 1, 0.1));

			sendA = Lag.kr(sendA + (sendAM * perfMod)).clip(0, 1);
			sendB = Lag.kr(sendB + (sendBM * perfMod)).clip(0, 1);
			pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

			dist = Lag.kr(dist + (distM * perfMod)).clip(0, 1);
			boost = dist.linlin(0, 1, 12, 24);
			att = dist.linlin(0, 1, 0, -6);

			// frame math
			plyDir = Select.kr(plyDir < 0.5, [1, -1]);
			rate = Lag3.kr((pitch + tune).midiratio * BufRateScale.kr(bfr) * plyDir, rateSlew);
			endRel = (srtRel + lenRel).clip(0.01, 1);
			numFrames = BufFrames.ir(bfr);
			srtFrame = numFrames * Select.kr(rate > 0, [endRel, srtRel]);
			endFrame = numFrames * Select.kr(rate > 0, [srtRel, endRel]);
			duckFrames = BufSampleRate.ir(bfr) * duckTime * rate.abs;
			sDur = (numFrames * lenRel / rate.abs / context.server.sampleRate) - (fadeIn + fadeOut);

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
			snd = BufRd.ar(1, bfr, phasePos, interpolation: 4) * -3.dbamp;

			// eq and distortion
			snd = (snd * (1 - dist) + ((snd * boost.dbamp).tanh * dist)) * att.dbamp;
			snd = RHPF.ar(snd, hpfHz, hpfQ);
			snd = RLPF.ar(snd, lpfHz, lpfQ);

			// output stage
			snd = snd * envDuck * envAmp;
			snd = snd * vel * amp * mainAmp;
			snd = Pan2.ar(snd, pan);

			Out.ar(out, snd);
			Out.ar(sendABus, snd * sendA);
			Out.ar(sendBBus, snd * sendB);
		}).add;

		SynthDef(\drmfm_UW_stereo,{
			arg out = 0, sendABus, sendBBus,
			mainAmp = 1, vel = 1, amp = 1, pan = 0, panRnd = 0, sendA = 0, sendB = 0, pitch = 0, gate = 1,
			mode = 0, bfr = 0, dist = 0, lpfHz = 18000, lpfRz = 0, hpfHz = 220, hpfRz = 0,
			mod1 = 0.5, mod2 = 0.4, mod3 = 0.24, mod4 = 1, mod5 = 0.3, mod6 = 0.05,
			perfMod = 0, mod1M = 0, mod2M = 0, mod3M = 0, mod4M = 0, mod5M = 0, mod6M = 0,
			sendAM = 0, sendBM = 0, decayM = 0, distM = 0, lpfM = 0, hpfM = 0;

			var rate, numFrames, srtFrame, endFrame, endRel, envOne, envHld, envAmp, sDur, phasePos;
			var att, boost, snd, lpfQ, hpfQ, duckFrames, duckGate, envDuck, duckTime = 0.01, rateSlew = 0.2;

			// rescale, smooth, clamp
			var tune = Lag.kr(mod1.linlin(0, 1, -1, 1) + (12 * mod1M * perfMod)).clip(-12, 12);
			var plyDir = Lag.kr((mod2 + (mod2M * perfMod)).clip(0, 1));
			var srtRel = Lag.kr((mod3 + (mod3M * perfMod)).linlin(0, 1, 0, 0.99));
			var lenRel = Lag.kr((mod4 + (mod4M * perfMod)).linlin(0, 1, 0.01, 1));
			var fadeIn = Lag.kr(mod5.linlin(0, 1, 0.01, 2));
			var fadeOut = Lag.kr(mod6.linlin(0, 1, 0.01, 2));

			lpfHz = Lag.kr((lpfHz.explin(20, 18000, 0, 1) + (lpfM * perfMod)).linexp(0, 1, 20, 18000));
			hpfHz = Lag.kr((hpfHz.explin(20, 18000, 0, 1) + (hpfM * perfMod)).linexp(0, 1, 20, 18000));
			lpfQ = Lag.kr(lpfRz.linlin(0, 1, 1, 0.1));
			hpfQ = Lag.kr(hpfRz.linlin(0, 1, 1, 0.1));

			sendA = Lag.kr(sendA + (sendAM * perfMod)).clip(0, 1);
			sendB = Lag.kr(sendB + (sendBM * perfMod)).clip(0, 1);
			pan = (pan + (panRnd * Rand(-0.8, 0.8))).clip(-1, 1);

			dist = Lag.kr(dist + (distM * perfMod)).clip(0, 1);
			boost = dist.linlin(0, 1, 12, 24);
			att = dist.linlin(0, 1, 0, -6);

			// frame math
			plyDir = Select.kr(plyDir < 0.5, [1, -1]);
			rate = Lag3.kr((pitch + tune).midiratio * BufRateScale.kr(bfr) * plyDir, rateSlew);
			endRel = (srtRel + lenRel).clip(0.01, 1);
			numFrames = BufFrames.ir(bfr);
			srtFrame = numFrames * Select.kr(rate > 0, [endRel, srtRel]);
			endFrame = numFrames * Select.kr(rate > 0, [srtRel, endRel]);
			duckFrames = BufSampleRate.ir(bfr) * duckTime * rate.abs;
			sDur = (numFrames * lenRel / rate.abs / context.server.sampleRate) - (fadeIn + fadeOut);

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
			snd = BufRd.ar(2, bfr, phasePos, interpolation: 4) * -3.dbamp;

			// eq and distortion
			snd = (snd * (1 - dist) + ((snd * boost.dbamp).tanh * dist)) * att.dbamp;
			snd = RHPF.ar(snd, hpfHz, hpfQ);
			snd = RLPF.ar(snd, lpfHz, lpfQ);

			// output stage
			snd = snd * envDuck * envAmp;
			snd = snd * vel * amp * mainAmp;
			snd = Pan2.ar(snd, pan);

			Out.ar(out, snd);
			Out.ar(sendABus, snd * sendA);
			Out.ar(sendBBus, snd * sendB);
		}).add;

		SynthDef.new(\leDelay, { |inBus, outBus, sendBus|

			var modHz = 12, tMax = 4, modF = 0.008;

			var modT = modF * \mod.kr(0);
			var modOsc = LFNoise2.ar(modHz);
			var tL = modOsc.range(\timeL.kr(0.4), \timeL.kr(0.4) + modT);
			var tR = Select.ar(\mode.kr(0) < 1,[modOsc.range(\timeR.kr(0.8) + modT, \timeR.kr(0.8)), tL]);

			var rtn = LocalIn.ar(2);
			var rtnL = Select.ar(\mode.kr(0) < 2, [rtn[1], rtn[0]]);
			var rtnR = Select.ar(\mode.kr(0) < 2, [rtn[0], rtn[1]]);

			var dry = In.ar(inBus, 2);
			var dlyL = DelayC.ar(dry[0] + (rtnL * \fb.kr(0.6)), tMax, Lag.kr(tL, 0.2));
			var dlyR = DelayC.ar(dry[1] + (rtnR * \fb.kr(0.6)), tMax, Lag.kr(tR, 0.2));

			var dly = LeakDC.ar([dlyL, dlyR]);
			dly = HPF.ar(LPF.ar(dly, \hzLpf.kr(1600)), \hzHpf.kr(80));
			LocalOut.ar(dly);
			Out.ar(sendBus, dly  * \send.kr(0));
			Out.ar(outBus, dly * \amp.kr(1));
		}).add;

		// modified version of @khoin's implementation of dattorros reverb (thank you!)
		// https://github.com/khoin/dx463-final/blob/b863d1982d34823f8f39df9b92e3ea948c8243c0/sdefs.sc#L150
		SynthDef(\datVerb, {
			arg inBus = 0, outBus = 0,
			amp = 1, preDelay = 0.1, preFilter = 0.1,
			decayRate = 0.8, damping = 0.22,
			modDepth = 0.2, modRate = 1;

			// signals
			var dry = In.ar(inBus, 2);
			var wetL = Silent.ar;
			var wetR = Silent.ar;
			var preTank, tank, wet;

			// sample rate used by dattorro
			var dSR = 29761;

			// max excursion (samples) dattoro used 16@29khz
			var exMax = 24;

			// exp decay rate
			var gFacT60 = { |delay, gFac|
				gFac.sign * (-3 * delay / log10(gFac.abs));
			};

			// values for pre tank
			var preTankVals = [
				[0.75, 0.75, 0.625, 0.625], // gFacs
				[142, 107, 379, 277] / dSR  // times
			].flop;

			// values for tank part
			var tankAP1GFac = -0.64; // tail density > seems a nice spot
			var tankAP1Time = 672;
			var tankDel1    = 4453/dSR;
			var tankAP2GFac = (decayRate + 0.15).clip(0.25, 0.5); // decay2 as from paper
			var tankAP2Time = 1800/dSR;
			var tankDel2    = 3720/dSR;

			var tankAP3GFac = tankAP1GFac;
			var tankAP3Time = 908;
			var tankDel3    = 4217/dSR;
			var tankAP4GFac = tankAP2GFac;
			var tankAP4Time = 2656/dSR;
			var tankDel4    = 3163/dSR;

			// map and clamp
			damping = damping.lincurve(0, 1, 0.002, 0.998, -2.2).lag3; // remap damp to log curve
			preFilter = preFilter.linlin(0, 1, 0.002, 0.78);
			decayRate = decayRate.linlin(0, 1, 0.01, 0.99);

			// PreTank
			preTank = (dry[0] + dry[1]) * -6.dbamp;
			preTank = DelayN.ar(preTank, 0.5, preDelay);
			preTank = OnePole.ar(preTank, preFilter);
			preTankVals.do({ arg pair; // 0: gFac, 1: time
				preTank = AllpassN.ar(preTank, pair[1], pair[1], gFacT60.value(pair[1], pair[0]));
			});

			//// reverb tank
			// first branch
			tank  = AllpassC.ar(preTank + (decayRate * LocalIn.ar(1)),
				maxdelaytime: (tankAP1Time + exMax) / dSR,
				delaytime: (tankAP1Time/dSR) + ((exMax/dSR) * SinOsc.ar(modRate, 0, modDepth)),
				decaytime: gFacT60.value(tankAP1Time/dSR, tankAP1GFac)
			);

			wetL = -0.6 * DelayN.ar(tank, 1990/dSR, 1990/dSR) + wetL;
			wetR = 0.6 * tank + wetR;
			wetR = 0.6 * DelayN.ar(tank, 3300/dSR, 3300/dSR) + wetR;
			tank = DelayN.ar(tank, tankDel1, tankDel1);
			tank = OnePole.ar(tank, damping) * decayRate;
			wetL = -0.6 * tank + wetL;
			tank = AllpassN.ar(tank, tankAP2Time, tankAP2Time, gFacT60.value(tankAP2Time, tankAP2GFac));
			wetR = -0.6 * tank + wetR;
			tank = DelayN.ar(tank, tankDel2, tankDel2);
			wetR = 0.6 * tank + wetR;

			// second branch
			tank  = AllpassC.ar((tank * decayRate) + preTank,
				maxdelaytime: (tankAP3Time + exMax)/dSR,
				delaytime: (tankAP3Time/dSR) + ((exMax/dSR) * SinOsc.ar(modRate * 0.8, pi, modDepth)),
				decaytime: gFacT60.value(tankAP3Time/dSR, tankAP3GFac)
			);

			wetL = 0.6 * tank + wetL;
			wetL = 0.6 * DelayN.ar(tank, 2700/dSR, 2700/dSR) + wetL;
			wetR = -0.6 * DelayN.ar(tank, 2100/dSR, 2100/dSR) + wetR;
			tank = DelayC.ar(tank, tankDel3, tankDel3);
			tank = OnePole.ar(tank, damping) * decayRate;
			tank = AllpassN.ar(tank, tankAP4Time, tankAP4Time, gFacT60.value(tankAP4Time, tankAP4GFac));
			wetL = -0.6 * tank + wetL;
			wetR = -0.6 * DelayN.ar(tank, 200/dSR, 200/dSR) + wetR;

			tank = DelayN.ar(tank, tankDel4, tankDel4);
			wetL = 0.6 * tank + wetL;
			tank = tank * decayRate;
			LocalOut.ar(tank);
			//// end of tank

			wet = [wetL, wetR];
			wet = HPF.ar(wet, 60);
			Out.ar(outBus, wet * amp);
		}).add;


		// add groups
		context.server.sync;
		mainGroup = Group.new(context.xg);

		monoGroup = Group.new(mainGroup);
		monoVoices = Array.newClear(numMono);

		polyGroup = Group.new(mainGroup);
		polyVoices = Array.newClear(numPoly);

		kitGroup = Group.new(mainGroup);
		kitVoices = Array.newClear(numKit);
		kitDef = Array.fill(numKit, { \UW });

		// add kit buffer
		loadQueue = Array.new(numKit);
		kitBuffers = Array.newClear(numKit);

		// add noise buffers (thx naomi aka sixolet!)
		context.server.sync;
		nozBuf = Array.newClear(4);
		sR = context.server.sampleRate;
		// whiteish noise
		nozBuf[0] = Buffer.loadCollection(context.server, FloatArray.fill(sR * 6, { 1.0.rand2 }));
		// static noise
		nozBuf[1] = Buffer.loadCollection(context.server, {
			var n = 0;
			FloatArray.fill(sR * 6, { |i| if(i % 240 == 0) {n = 2.0.rand2} {(n * 0.8.rand2).clip(-1, 1)} });
		}.value);
		// redux noise
		nozBuf[2] = Buffer.loadCollection(context.server, {
			var n = 0;
			FloatArray.fill(sR * 6, { |i| if(i % 480 == 0) {n = 1.0.rand2} {(n + 1.0.rand2).clip(-1, 1)} });
		}.value);
		// brownish noise
		nozBuf[3] = Buffer.loadCollection(context.server, {
			var n = 0;
			FloatArray.fill(sR * 6, {n = (n + 0.14.rand2).clip(-1, 1)});
		}.value);

		context.server.sync;
		
		// add commands
		this.addCommands();
	}

	// functions
	queueLoadSample {
		arg vox, path;
		var t = (vox: vox, path: path);
		loadQueue = loadQueue.addFirst(t);
		if (loadingSamples.not) {this.loadSample()};
	}

	clearSample { arg vox;
		if (kitVoices[vox].notNil) { kitVoices[vox].set(\gate, -1) };
		if (kitBuffers[vox].notNil) {
			if (kitBuffers[vox].bufnum.notNil) { kitBuffers[vox].free };
			kitBuffers[vox] = nil;
		};
	}

	loadSample {
		var t;
		if (loadQueue.notEmpty) {
			t = loadQueue.pop;
			loadingSamples = true;
			("Loading..." + t.vox + t.path).postln;
			this.clearSample(t.vox);
			kitBuffers[t.vox] = Buffer.read(context.server, t.path, action: { this.loadSample() });
		}{
			loadingSamples = false;
		};
	}

	// commands
	addCommands {

		this.addCommand(\polyform_on, "siffi", { arg msg;
			var syn = msg[1].asSymbol;
			var vox = msg[2].asInteger;
			var freq = msg[3].asFloat;
			var vel = msg[4].asFloat;
			var nID = msg[5].asInteger;
			var v;
			if (syn == \poly) {
				if (polyVoices[vox].notNil) { polyVoices[vox].set(\gate, -1.05) };
				v = Synth.new(\polyForm,
					[
						\freq, freq,
						\vel, vel,
						\noiseBfr, nozBuf[nID],
						\out, context.out_b,
						\sendABus, delayBus ? ~sendA,
						\sendBBus, reverbBus ? ~sendB,
					] ++ polyParams.getPairs, polyGroup
				);
				v.onFree({ if (polyVoices[vox] === v) {polyVoices[vox] = nil} });
				polyVoices[vox] = v;
			}{
				if (monoVoices[vox] != nil) { monoVoices[vox].set(\gate, -1.05) };
				v = Synth.new(\polyForm,
					[
						\freq, freq,
						\vel, vel,
						\noiseBfr, nozBuf[nID],
						\out, context.out_b,
						\sendABus, delayBus ? ~sendA,
						\sendBBus, reverbBus ? ~sendB,
					] ++ monoParams.getPairs, monoGroup
				);
				v.onFree({ if (monoVoices[vox] === v) {monoVoices[vox] = nil} });
				monoVoices[vox] = v;
			}
		});

		this.addCommand(\polyform_off, "si", { arg msg;
			var syn = msg[1].asSymbol;
			var vox = msg[2].asInteger;
			if (syn == \poly) {
				if (polyVoices[vox].notNil) { polyVoices[vox].set(\gate, 0) }
			}{
				if (monoVoices[vox].notNil) { monoVoices[vox].set(\gate, 0) }
			};
		});

		this.addCommand(\set_polyform, "ssf", { arg msg;
			var syn = msg[1].asSymbol;
			var key = msg[2].asSymbol;
			var val = msg[3].asFloat;
			if (syn == \poly) {
				polyGroup.set(key, val);
				polyParams[key] = val;
			}{
				monoGroup.set(key, val);
				monoParams[key] = val;
			};
		});

		this.addCommand(\polyform_panic, "s", { arg msg;
			var syn = msg[1].asSymbol;
			if (syn == \poly) {
				polyGroup.set(\gate, -1.05);
			}{
				monoGroup.set(\gate, -1.05);
			};
		});

		this.addCommand(\drmfm_trig, "if", { arg msg;
			var vox = msg[1].asInteger;
			var vel = msg[2].asFloat;
			var v;
			if (kitVoices[vox].notNil) { kitVoices[vox].set(\gate, -1.05) };
			if (kitDef[vox] != \UW) {
				v = Synth.new(("drmfm_"++kitDef[vox]).asSymbol,
					[
						\vel, vel,
						\nWbfr, nozBuf[0],
						\nSbfr, nozBuf[1],
						\nRbfr, nozBuf[2],
						\nBbfr, nozBuf[3],
						\out, context.out_b,
						\sendABus, delayBus ? ~sendA,
						\sendBBus, reverbBus ? ~sendB,
					] ++ kitVoiceParams[vox].getPairs, kitGroup
				);
				v.onFree({ if (kitVoices[vox] === v) {kitVoices[vox] = nil} });
				kitVoices[vox] = v;
			} {
				if (kitBuffers[vox].notNil) {
					var def = if (kitBuffers[vox].numChannels > 1) {\drmfm_UW_stereo} {\drmfm_UW_mono};
					v = Synth.new(def,
						[
							\vel, vel,
							\bfr, kitBuffers[vox],
							\sendABus, delayBus ? ~sendA,
							\sendBBus, reverbBus ? ~sendB,
						] ++ kitVoiceParams[vox].getPairs, kitGroup
					);
					v.onFree({ if (kitVoices[vox] === v) {kitVoices[vox] = nil} });
					kitVoices[vox] = v;
				};
			};
		});

		this.addCommand(\drmfm_stop, "i", { arg msg;
			var vox = msg[1].asInteger;
			if (kitVoices[vox].notNil) { kitVoices[vox].set(\gate, 0) }
		});

		this.addCommand(\drmfm_set_def, "is", { arg msg;
			var vox = msg[1].asInteger;
			var def = msg[2].asSymbol;
			kitDef[vox] = def;
		});

		this.addCommand(\set_drmfm_level, "f", { arg msg;
			var val = msg[1].asFloat;
			kitGroup.set(\mainAmp, val);
			numKit.do{arg vox;
				kitVoiceParams[vox][\mainAmp] = val;
			};
		});

		this.addCommand(\set_drmfm, "isf", { arg msg;
			var vox = msg[1].asInteger;
			var key = msg[2].asSymbol;
			var val = msg[3].asFloat;
			kitVoiceParams[vox][key] = val;
			if (kitDef[vox] == \UW && kitVoices[vox].notNil) {
				kitVoices[vox].set(key, val);
			};
		});

		this.addCommand(\drmfm_perf, "f", { arg msg;
			var val = msg[1].asFloat;
			numKit.do{arg vox;
				kitVoiceParams[vox][\perfMod] = val;
				if (kitDef[vox] == \UW && kitVoices[vox].notNil) {
					kitVoices[vox].set(\perfMod, val);
				};
			};
		});

		this.addCommand(\load_sample, "is", { arg msg;
			var vox = msg[1].asInteger;
			var path = msg[2].asString;
			this.queueLoadSample(vox, path);
		});

		this.addCommand(\clear_sample, "i", { arg msg;
			var vox = msg[1].asInteger;
			this.clearSample(vox);
		});

		this.addCommand(\drmfm_panic, "", { arg msg;
			kitGroup.set(\gate, -1.05);
		});

		this.addCommand(\toggle_fx, "s", { arg msg;
			var state = msg[1].asSymbol;
			if (state == \on) {
				delayBus = Bus.audio(context.server, 2);
				reverbBus = Bus.audio(context.server, 2);
				delayFx = Synth.new(\leDelay, [\inBus, delayBus, \sendBus, reverbBus, \outBus, context.out_b], mainGroup, 'addToTail');
				reverbFx = Synth.new(\datVerb, [\inBus, reverbBus, \outBus, context.out_b], mainGroup, 'addToTail');
			}{
				delayBus.free;
				reverbBus.free;
				delayFx.free;
				reverbFx.free;
			};
		});

		this.addCommand(\set_fx, "ssf", { arg msg;
			var fx = msg[1].asSymbol;
			var key = msg[2].asSymbol;
			var val = msg[3].asFloat;
			if (fx == \delay) {
				if (delayFx.notNil) { delayFx.set(key, val) }
			}{
				if (reverbFx.notNil) { reverbFx.set(key, val) }
			};
		});

	}

	free {
		numKit.do{ |vox| this.clearSample(vox) };
		nozBuf.do{_.free};
		monoGroup.set(\gate, -1.05);
		polyGroup.set(\gate, -1.05);
		kitGroup.set(\gate, -1.05);
		mainGroup.free;
	}

}
