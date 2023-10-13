// SC class exercise 3: third (and final) adaptation
// 8-voice polyphony + smoothing
// written by Dan Derks + Ezra Buchla for monome.org

// synthDef written by sacha di piazza for norns with bits of code and inspiration from zack scholl and ezra buchla

Moonunit {

	classvar <voiceKeys;
	var <globalParams;
	var <voiceParams;
	var <voiceGroup;
	var <singleVoices;

	*initClass {
		voiceKeys = [ \1, \2, \3, \4, \5, \6, \7, \8 ];
		StartUp.add {
			var s = Server.default;

			s.waitForBoot {

				SynthDef("Moonunit",{
					arg busMain, amp = 1, pan = 0, freq = 110,
					vib_rate = 8, vib_depth = 0, vib_delay = 0, vib_onset = 0.2,
					sine_tune = 0, saw_tune = 0, pulse_tune = 0,
					sine_gain = 0, supersaw = 0, pulse_width = 0.5, pwm_freq = 1.2, pwm_depth = 0,
					sine_amp = 0, saw_amp = 1, pulse_amp, noise_amp = 0, crackle = 0,
					cutoff_lpf = 400, res_lpf = 0.1, cutoff_hpf = 20, res_hpf = 0,
					env_a = 0.01, env_d = 1, env_s = 1, env_r = 1, gate = 1,
					env_type = 0, env_mod_mode = 0, env_depth_hpf = 0, env_depth_lpf = 0,
					cut_slop = 0, env_slop = 0, pan_slop = 0;

					// osc drift
					var osc_drift = LFNoise2.kr(0.1, 0.001, 1);

					// add vibrato and drift to freq
					var vfreq = Vibrato.kr(freq, vib_rate, vib_depth, vib_delay, vib_onset) * osc_drift;

					// add tune to freqs. expected tune range [-24, 24] (semitones).
					var sine_freq = Lag.kr(vfreq * 2.pow(sine_tune/12));
					var saw_freq = Lag.kr(vfreq * 2.pow(saw_tune/12));
					var pulse_freq = Lag.kr(vfreq * 2.pow(pulse_tune/12));

					// JP800 supersaw emulation based on adam szbao's thesis,
					// ported to sc by eric skogan and adapted by zack scholl
					var detuneCurve = { |x|
						(10028.7312891634 * x.pow(11)) -
						(50818.8652045924 * x.pow(10)) +
						(111363.4808729368 * x.pow(9)) -
						(138150.6761080548 * x.pow(8)) +
						(106649.6679158292 * x.pow(7)) -
						(53046.9642751875 * x.pow(6)) +
						(17019.9518580080 * x.pow(5)) -
						(3425.0836591318 * x.pow(4)) +
						(404.2703938388 * x.pow(3)) -
						(24.1878824391 * x.pow(2)) +
						(0.6717417634 * x) +
						0.0030115596
					};

					var centerGain = { |x| (-0.55366 * x) + 0.99785 };
					var sideGain = { |x| (-0.73764 * x.pow(2)) + (1.2841 * x) + 0.044372 };
					var detuneFactor = freq * detuneCurve.(LFNoise2.kr(1).range(0.3, 0.5));
					var freqs = [
						(saw_freq - (detuneFactor * 0.11002313)),
						(saw_freq - (detuneFactor * 0.06288439)),
						(saw_freq - (detuneFactor * 0.01952356)),
						(saw_freq + (detuneFactor * 0.01991221)),
						(saw_freq + (detuneFactor * 0.06216538)),
						(saw_freq + (detuneFactor * 0.10745242))
					];

					// other variables
					var sig, env, env_ar, env_adsr,
					saw_osc, center_saw, side_saw, pulse_osc, sine_osc, main_osc, sub_osc, noise,
					cut_lin_scale = 1, cut_lin_lpf, cut_lpf_mod, cut_lin_hpf, cut_hpf_mod, rq_lpf, rq_hpf;

					// slews
					amp = Lag.kr(amp);
					pan = Lag.kr(pan);
					sine_amp = Lag.kr(sine_amp);
					sine_gain = Lag.kr(sine_gain);
					saw_amp = Lag.kr(saw_amp);
					pulse_amp = Lag.kr(pulse_amp);
					noise_amp = Lag.kr(noise_amp);
					cutoff_lpf = Lag.kr(cutoff_lpf);

					// slop
					cut_slop = cut_slop * ExpRand(0.2, 1);
					env_slop = env_slop * ExpRand(0.2, 1);
					pan_slop = pan_slop * ExpRand(0.2, 1);

					// lfos
					pulse_width = (pulse_width + (SinOsc.kr(pwm_freq, Rand(-6pi, 6pi), 0.5) * pwm_depth / 2)).max(0.02).min(0.98);

					// envelopes
					env_ar = EnvGen.kr(Env.perc(env_a, env_r + env_slop), gate, doneAction: Select.kr(env_type > 0, [2, 0]));
					env_adsr = EnvGen.kr(Env.adsr(env_a, env_d, env_s, env_r + env_slop), gate, doneAction: Select.kr(env_type > 0, [0, 2]));

					// select envelope type
					env = Select.kr(env_type > 0, [env_ar, env_adsr]);

					// sine osc
					sine_osc = SinOsc.ar(sine_freq, 0, sine_gain.linlin(0, 1, 1, 8)).tanh * sine_amp;

					// saw/supersaw osc
					center_saw = SawDPW.ar(saw_freq);
					side_saw = Mix.fill(6, {arg n; SawDPW.ar(freqs[n], Rand(-1, 1))});
					saw_osc = ((center_saw * centerGain.(supersaw)) + (side_saw * sideGain.(supersaw))) * saw_amp;

					// pulse osc
					pulse_osc = Pulse.ar(pulse_freq, pulse_width) * pulse_amp;

					// noise
					noise = WhiteNoise.ar(LFNoise1.kr(freq * 2).range(1 - crackle, 1)) * noise_amp;

					// mixdown
					sig = Mix.new([sine_osc, saw_osc, pulse_osc, noise]) * -6.dbamp;

					// low pass filter + modulation
					// (bipolar env mod by ezra buchla)
					cut_lin_lpf = cutoff_lpf.explin(20, 18000, 0, cut_lin_scale);
					cut_lpf_mod = cut_lin_lpf + (env * cut_lin_scale * env_depth_lpf) + cut_slop;
					cutoff_lpf = cut_lpf_mod.linexp(0, cut_lin_scale, 20, 18000).max(20).min(18000);
					cutoff_lpf = Select.kr(env_mod_mode > 0, [cutoff_lpf, cutoff_lpf * env]);

					rq_lpf = res_lpf.linlin(0, 1, 0, 4);
					sig = MoogFF.ar(sig, cutoff_lpf, rq_lpf);

					// high pass filter + modulation
					// (bipolar env mod by ezra buchla)
					cut_lin_hpf = cutoff_hpf.explin(20, 18000, 0, cut_lin_scale);
					cut_hpf_mod = cut_lin_hpf + (env * cut_lin_scale * env_depth_hpf);
					cutoff_hpf = cut_hpf_mod.linexp(0, cut_lin_scale, 20, 18000).max(20).min(18000);

					rq_hpf = res_hpf.linlin(0, 1, 1, 0.01);
					sig = RHPF.ar(sig, cutoff_hpf, rq_hpf);

					// make "stereo"
					pan = (pan + pan_slop).max(-1).min(1);
					sig = Pan2.ar(sig, pan);

					// final stage
					sig = (sig * amp * -6.dbamp);

					Out.ar(busMain, sig * env);

				}).add;
			}
		}
	}

	*new {
		^super.new.init;
	}

	init {

		var s = Server.default;

		voiceGroup = Group.new(s);

		globalParams = Dictionary.newFrom([
			\amp, 1,
			\pan, 0,
			\freq, 220,
			\vib_rate, 8,
			\vib_depth, 0,
			\vib_delay, 0,
			\vib_onset, 0.2,
			\sine_tune, 0,
			\saw_tune, 0,
			\pulse_tune, 0,
			\sine_amp, 0,
			\saw_amp, 1,
			\pulse_amp, 0,
			\sine_gain, 0,
			\supersaw, 0,
			\pulse_width, 0.5,
			\pwm_freq, 1.2,
			\pwm_depth, 0,
			\noise_amp, 0,
			\crackle, 0,
			\cutoff_lpf, 400,
			\res_lpf, 0.1,
			\env_mod_mode, 0,
			\env_depth_lpf, 0,
			\cutoff_hpf, 20,
			\res_hpf, 0,
			\env_depth_hpf, 0,
			\env_type, 0,
			\env_a, 0.01,
			\env_d, 0.2,
			\env_s, 0.6,
			\env_r, 1,
			\gate, 1,
			\cut_slop, 0,
			\env_slop, 0,
			\pan_slop, 0,
		]);

		singleVoices = Dictionary.new;
		voiceParams = Dictionary.new;
		voiceKeys.do({ arg voiceKey;
			singleVoices[voiceKey] = Group.new(voiceGroup);
			voiceParams[voiceKey] = Dictionary.newFrom(globalParams);
		});
	}

	playVoice { arg voiceKey, freq;
		singleVoices[voiceKey].set(\gate, -1.05); // -1.05 is 'forced release' with 50ms (0.05s) cutoff time
		voiceParams[voiceKey][\freq] = freq;
		Synth.new("Moonunit", [\freq, freq] ++ voiceParams[voiceKey].getPairs, singleVoices[voiceKey]);
	}

	trigger { arg voiceKey, freq;
		if( voiceKey == 'all',{
			voiceKeys.do({ arg vK;
				this.playVoice(vK, freq);
			});
		},
		{
			this.playVoice(voiceKey, freq);
		});
	}

	stopVoice { arg voiceKey;
		singleVoices[voiceKey].set(\gate, 0);
	}

	adjustVoice { arg voiceKey, paramKey, paramValue;
		singleVoices[voiceKey].set(paramKey, paramValue);
		voiceParams[voiceKey][paramKey] = paramValue
	}

	setParam { arg voiceKey, paramKey, paramValue;
		if( voiceKey == 'all',{
			voiceKeys.do({ arg vK;
				this.adjustVoice(vK, paramKey, paramValue);
			});
		},
		{
			this.adjustVoice(voiceKey, paramKey, paramValue);
		});
	}

	freeAllNotes {
		voiceGroup.set(\gate, -1.05);
	}

	free {
		voiceGroup.free;
	}

}
