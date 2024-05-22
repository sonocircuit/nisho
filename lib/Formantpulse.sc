// supercollider class based on the skilled labour study written by dan derks & ezra buchla for monome.org
// synthDef written by sacha di piazza with bits of code and inspiration from ezra buchla, zack scholl & trent gill

Formantpulse {

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

				SynthDef("Formantpulse",{
					arg out, gate = 1, freq = 110, main_amp = 0.2, pan = 0, mix_osc_level = 0.5, mix_noise_level = 0,
					sendA = 0, sendB = 0, sendABus = 0, sendBBus = 0,
					// formant output args
					formant_tune = 0,
					formant_type = 0,
					formant_shape = 0,
					formant_shape_mod = 0,
					formant_curve = 0,
					formant_width = 2,
					// pulse output args
					pulse_tune = 0,
					pulse_width = 0.5,
					pulse_width_mod = 0,
					pulse_mod_freq = 6,
					pulse_mod_depth = 0,
					// noise args
					noise_amp_mod = 0,
					noise_crackle = 0,
					// envelope args
					env_type = 0,
					env_curve = -4,
					env_a = 0, env_d = 2, env_s = 0.5, env_r = 5,
					env_mod_curve = -4,
					envmod_h = 1, envmod_a = 1, envmod_d = 1, envmod_s = 0.5, envmod_r = 2,
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
					var signal, osc_mix, osc_formant, osc_pulse, osc_noise, noise_amp, pulse_train,
					formant_period, formant_time, formant_rise, formant_fall,
					freq_formant, freq_pulse, cut_lin_scale = 1, cut_lin_lpf,
					cut_lpf_mod, cut_lin_hpf, cut_hpf_mod, rq_lpf, rq_hpf,
					env, env_ar, env_adsr, action_ar, action_adsr, env_mod, env_mod_ar, env_mod_adsr;

					// smooth args
					main_amp = Lag.kr(main_amp);
					pan = Lag.kr(pan);
					mix_osc_level = Lag.kr(mix_osc_level);
					mix_noise_level = Lag.kr(mix_noise_level);
					formant_tune = Lag.kr(formant_tune);
					formant_shape = Lag.kr(formant_shape);
					formant_curve = Lag.kr(formant_curve);
					formant_width = Lag.kr(formant_width);
					pulse_tune = Lag.kr(pulse_tune);
					pulse_width = Lag.kr(pulse_width);
					cutoff_lpf = Lag.kr(cutoff_lpf);
					res_lpf = Lag.kr(res_lpf);
					cutoff_hpf = Lag.kr(cutoff_hpf);
					res_hpf = Lag.kr(res_hpf);

					// randomize slop
					freq_slop = freq_slop * Rand(-2, 2);
					cut_slop = cut_slop * Rand(0.3, 0.7);
					env_slop = env_slop * Rand(0.1, 1.2);
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

					// freq slop + vibrato
					freq = freq + freq_slop;
					freq = Vibrato.kr(freq, vibrato_rate, vibrato_depth / 10, vibrato_delay, vibrato_onset);

					// tune oscillators. expected range [-24, 24] semitones.
					freq_formant = Lag.kr(freq * 2.pow(formant_tune / 12));
					freq_pulse = Lag.kr(freq * 2.pow(pulse_tune / 12));

					// pulse oscillator
					pulse_width = (pulse_width + (SinOsc.kr(pulse_mod_freq, Rand(-6pi, 6pi), 0.5) * pulse_mod_depth / 2)).max(0.02).min(0.98);
					pulse_width = (pulse_width + (pulse_width_mod * env_mod)).max(0.02).min(0.98);
					osc_pulse = Pulse.ar(freq_pulse, pulse_width);

					// formant oscillator
					formant_shape = (formant_shape + (formant_shape_mod * env_mod)).max(0).min(1);
					formant_period = Select.kr(formant_type, [1/freq_formant, 1/1000]); //val for fixed period? ask trent or fix oscilloscope.
					formant_time = formant_period / formant_width;
					formant_rise = (formant_time) * formant_shape;
					formant_fall = (formant_time) * (1 - formant_shape);
					pulse_train = Trig1.ar(LFPulse.ar(freq_formant), formant_time);
					osc_formant = EnvGen.ar(Env.new([0,1,0], [formant_rise, formant_fall], [formant_curve.neg, formant_curve]), pulse_train, 2, -1, 1, 0);

					// osc mix
					osc_mix = XFade2.ar(osc_formant, osc_pulse, mix_osc_level);

					// noise
					noise_amp = Select.kr(noise_amp_mod > 0, [1, noise_amp_mod * env_mod]);
					osc_noise = WhiteNoise.ar(LFNoise1.kr(freq * 2).range(1 - noise_crackle, 1)) * noise_amp;

					// mix
					signal = XFade2.ar(osc_mix, osc_noise, mix_noise_level) * main_amp;

					// low pass filter + modulation
					cut_lin_lpf = cutoff_lpf.explin(20, 18000, 0, cut_lin_scale);
					cut_lpf_mod = cut_lin_lpf + (env * cut_lin_scale * env_lpf_depth) + (env_mod * cut_lin_scale * env_lpf_mod) + cut_slop;
					cutoff_lpf = cut_lpf_mod.linexp(0, cut_lin_scale, 20, 18000).max(20).min(18000);

					rq_lpf = res_lpf.linlin(0, 1, 0, 4);
					signal = MoogFF.ar(signal, cutoff_lpf, rq_lpf);

					// high pass filter + modulation
					cut_lin_hpf = cutoff_hpf.explin(20, 8000, 0, cut_lin_scale);
					cut_hpf_mod = cut_lin_hpf + (env * cut_lin_scale * env_hpf_depth) + (env_mod * cut_lin_scale * env_hpf_mod);
					cutoff_hpf = cut_hpf_mod.linexp(0, cut_lin_scale, 20, 8000).max(20).min(8000);

					rq_hpf = res_hpf.linlin(0, 1, 1, 0.01);
					signal = RHPF.ar(signal, cutoff_hpf, rq_hpf);

					// pan
					signal = Pan2.ar(signal, (pan + pan_slop).max(-1).min(1));

					//output
					signal = signal * env * -6.dbamp;

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
			\formant_tune, 0,
			\formant_type, 0,
			\formant_shape, 0,
			\formant_shape_mod, 0,
			\formant_curve, 0,
			\formant_width, 2,

			\pulse_amp, 0,
			\pulse_tune, 0,
			\pulse_width, 0.5,
			\pulse_width_mod, 0.5,
			\pulse_mod_freq, 6,
			\pulse_mod_depth, 0,

			\mix_noise_level, -1,
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
		singleVoices[voiceKey].set(\gate, -1.05); // -1.05 is 'forced release' with 50ms (0.05s) cutoff time
		voiceParams[voiceKey][\freq] = freq;
		Synth.new("Formantpulse",
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
