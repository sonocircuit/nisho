// supercollider class based on the skilled labour study written by dan derks & ezra buchla for monome.org
// synthDef written by sacha di piazza with bits of code and inspiration from ezra buchla, zack scholl & naomi seyfer

Polyform {

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

				SynthDef("Polyform",{
					arg out, gate = 1, freq = 110,
					main_amp = 0.2, pan = 0, mix_osc_level = 1, mix_noise_level = 0,
					sendA = 0, sendB = 0, sendABus = 0, sendBBus = 0,
					// ptichbend
					pb_range = 0,
					pb_depth = 0,
					// saw output args
					saw_tune = 0,
					saw_shape = 0.5,
					saw_shape_mod = 0,
					saw_mod_freq = 6,
					saw_mod_depth = 0,
					// pulse output args
					pulse_tune = 0,
					pulse_width = 0.7,
					pulse_width_mod = 0.2,
					pulse_mod_freq = 6,
					pulse_mod_depth = 0,
					// noise args
					noise_amp_mod = 0,
					noise_crackle = 0,
					// envelope args
					env_type = 0,
					env_curve = -2,
					env_a = 0, env_d = 2, env_s = 0.5, env_r = 5,
					mod_source = 0, at_mod = 0,
					env_mod_curve = -4,
					envmod_h = 0, envmod_a = 0, envmod_d = 0.8, envmod_s = 0, envmod_r = 2,
					// filter args
					cutoff_lpf = 500, res_lpf = 0, env_lpf_depth = 0.5, env_lpf_mod = 0,
					cutoff_hpf = 20, res_hpf = 0, env_hpf_depth = 0, env_hpf_mod = 0,
					// vibrato
					vibrato_rate = 6,
					vibrato_depth = 0,
					vibrato_onset = 0,
					vibrato_delay = 0.1,
					//slop args
					freq_slop = 0, cut_slop = 0, env_slop = 0, pan_slop = 0;

					// variables
					var signal, osc_mix, osc_saw, osc_pulse, osc_noise,
					freq_saw, freq_pulse, lfo_saw, lfo_pulse,
					cut_lin_scale = 1, cut_lin_lpf, cut_lpf_mod, cut_lin_hpf, cut_hpf_mod, rq_lpf, rq_hpf,
					env, env_ar, env_adsr, action_ar, action_adsr, mod_val, env_mod, env_mod_ar, env_mod_adsr;

					// smooth args
					main_amp = Lag.kr(main_amp);
					pan = Lag.kr(pan);
					mix_osc_level = Lag.kr(mix_osc_level);
					mix_noise_level = Lag.kr(mix_noise_level) - 1;
					saw_tune = Lag.kr(saw_tune);
					saw_shape = Lag.kr(saw_shape);
					pulse_tune = Lag.kr(pulse_tune);
					pulse_width = Lag.kr(pulse_width);
					cutoff_lpf = Lag.kr(cutoff_lpf);
					res_lpf = Lag.kr(res_lpf);
					cutoff_hpf = Lag.kr(cutoff_hpf);
					res_hpf = Lag.kr(res_hpf);
					at_mod = Lag.kr(at_mod);
					pb_depth = Lag.kr(pb_depth);

					// randomize slop
					freq_slop = freq_slop * Rand(-2, 2);
					cut_slop = cut_slop * Rand(0.3, 0.6);
					env_slop = env_slop * Rand(-0.1, 1.2);
					pan_slop = pan_slop * Rand(-0.7, 0.7);

					// main envelope
					action_ar = Select.kr(env_type > 0, [2, 0]);
					action_adsr = Select.kr(env_type > 0, [0, 2]);

					env_ar = EnvGen.kr(Env.perc(env_a, env_d + env_slop, curve: env_curve), gate, doneAction: action_ar);
					env_adsr = EnvGen.kr(Env.adsr(env_a, env_d + env_slop, env_s, env_r, curve: env_curve), gate, doneAction: action_adsr);
					env = Select.kr(env_type > 0, [env_ar, env_adsr]);

					// mod envelope
					env_mod_ar = EnvGen.kr(Env.new([0, 0, 1, 0], [envmod_h, envmod_a, envmod_d], env_mod_curve), gate);
					env_mod_adsr = EnvGen.kr(Env.new([0, 0, 1, envmod_s, 0], [envmod_h, envmod_a, envmod_d, envmod_r], env_mod_curve, 3), gate);
					env_mod = Select.kr(env_type > 0, [env_mod_ar, env_mod_adsr]);

					// mod source
					mod_val = Select.kr(mod_source > 0, [env_mod, at_mod]);

					// freq slop, ptichbend  vibrato
					freq = freq + freq_slop;
					freq = Lag.kr(freq * 2.pow((pb_depth * pb_range) / 12));
					freq = Vibrato.kr(freq, vibrato_rate, vibrato_depth / 10, vibrato_delay, vibrato_onset);

					// tune oscillators. expected range [-24, 24] semitones.
					freq_saw = Lag.kr(freq * 2.pow(saw_tune / 12));
					freq_pulse = Lag.kr(freq * 2.pow(pulse_tune / 12));

					// pulse oscillator
					lfo_pulse = SinOsc.kr(pulse_mod_freq, Rand(-6pi, 6pi), 0.46) * pulse_mod_depth;
					pulse_width = (pulse_width + lfo_pulse + (pulse_width_mod * mod_val)).max(0.02).min(0.98);
					osc_pulse = Pulse.ar(freq_pulse, pulse_width);

					// variable sawtooth oscillator
					lfo_saw = SinOsc.kr(saw_mod_freq, Rand(-6pi, 6pi), 0.5) * saw_mod_depth;
					saw_shape = (saw_shape + lfo_saw + (saw_shape_mod * mod_val)).max(0).min(1);
					osc_saw = VarSaw.ar(freq_saw, 0, saw_shape);

					// osc mix
					osc_mix = XFade2.ar(osc_saw, osc_pulse, mix_osc_level);

					// noise
					osc_noise = WhiteNoise.ar(LFNoise1.kr(freq * 2).range(1 - noise_crackle, 1));
					mix_noise_level = Select.kr(noise_amp_mod > 0, [mix_noise_level, mix_noise_level + (noise_amp_mod * mod_val)]).max(-1).min(0);

					// mix
					signal = XFade2.ar(osc_mix, osc_noise, mix_noise_level) * -6.dbamp;

					// low pass filter + modulation
					cut_lin_lpf = cutoff_lpf.explin(20, 18000, 0, cut_lin_scale);
					cut_lpf_mod = cut_lin_lpf + (env * cut_lin_scale * env_lpf_depth) + (mod_val * cut_lin_scale * env_lpf_mod) + cut_slop;
					cutoff_lpf = cut_lpf_mod.linexp(0, cut_lin_scale, 20, 18000).max(20).min(18000);

					rq_lpf = res_lpf.linlin(0, 1, 0, 4);
					signal = MoogFF.ar(signal, cutoff_lpf, rq_lpf);

					// high pass filter + modulation
					cut_lin_hpf = cutoff_hpf.explin(20, 8000, 0, cut_lin_scale);
					cut_hpf_mod = cut_lin_hpf + (env * cut_lin_scale * env_hpf_depth) + (mod_val * cut_lin_scale * env_hpf_mod);
					cutoff_hpf = cut_hpf_mod.linexp(0, cut_lin_scale, 20, 8000).max(20).min(8000);

					rq_hpf = res_hpf.linlin(0, 1, 1, 0.01);
					signal = RHPF.ar(signal, cutoff_hpf, rq_hpf);

					// pan
					signal = Pan2.ar(signal, (pan + pan_slop).max(-1).min(1));

					//output
					signal = signal * env * main_amp;

					// ouptut stage
					Out.ar(out, signal);
					Out.ar(sendABus, sendA * signal);
					Out.ar(sendBBus, sendB * signal);

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
			\freq, 220,
			\main_amp, 1,
			\pan, 0,
			\sendA, 0,
			\sendB, 0,
			\mix_osc_level, 0,

			\pb_range, 0,
			\pb_depth, 0,

			\saw_tune, 0,
			\saw_shape, 0,
			\saw_shape_mod, 0,
			\saw_mod_freq, 6,
			\saw_mod_depth, 0,

			\pulse_tune, 0,
			\pulse_width, 0.5,
			\pulse_width_mod, 0.5,
			\pulse_mod_freq, 6,
			\pulse_mod_depth, 0,

			\mix_noise_level, 0,
			\noise_amp_mod, 0,
			\noise_crackle, 0,

			\cutoff_lpf, 400,
			\res_lpf, 0.1,
			\env_lpf_depth, 0,
			\env_lpf_mod, 0,

			\cutoff_hpf, 20,
			\res_hpf, 0,
			\env_hpf_depth, 0,
			\env_hpf_mod, 0,

			\env_type, 0,
			\env_curve, -1,
			\env_a, 0.01,
			\env_d, 0.2,
			\env_s, 0.6,
			\env_r, 1,
			\gate, 1,

			\mod_source, 0,
			\at_mod, 0,

			\env_mod_curve, -1,
			\envmod_h, 0,
			\envmod_a, 0.01,
			\envmod_d, 0.2,
			\envmod_s, 0.6,
			\envmod_r, 1,

			\vibrato_rate, 8,
			\vibrato_depth, 0,
			\vibrato_delay, 0,
			\vibrato_onset, 0.2,

			\freq_slop, 0,
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
		singleVoices[voiceKey].set(\gate, -1.05);
		voiceParams[voiceKey][\freq] = freq;
		Synth.new("Polyform",
		[
			\freq, freq,
			\sendABus, ~sendA ? Server.default.outputBus,
			\sendBBus, ~sendB ? Server.default.outputBus,
		] ++ voiceParams[voiceKey].getPairs, singleVoices[voiceKey]);
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
