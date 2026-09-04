Nisho_PolyForm {

	*initClass {

		StartUp.add {

			CroneDefs.add(
				SynthDef(\polyForm, {
					arg outBus, noiseBuf,
					// levels
					level = 1, vel = 1, pan = 0, sendA = 0, sendB = 0,
					// pitch
					freq = 110, pb_range = 0, pb_depth = 0, vib_rate = 6, vib_depth = 0, vib_onset = 0, vib_delay = 0.1,
					// oscillators
					saw_tune = 0, saw_shape = 0.5, saw_lfo_freq = 6, saw_lfo_depth = 0, fm_index = 0, fm_ratio = 1.5,
					pulse_tune = 0, pulse_width = 0.7, pulse_lfo_freq = 6, pulse_lfo_depth = 0,
					osc_mix = 1, noise_amp = 0,
					// envelope
					gate = 1, env_curve = -2, env_a = 0, env_d = 2, env_s = 0.5, env_r = 2,
					// modulation
					mod_wheel = 0, mod_oscmix = 0, mod_level = 0, mod_drive = 0, mod_sendA = 0, mod_sendB = 0,
					mod_sawshape = 0, mod_pulsewidth = 0.2, mod_saw_lfo_depth = 0, mod_pwm_depth = 0,
					mod_fm_index = 0, mod_fm_ratio = 0, mod_noiseamp = 0,
					mod_lpfcut = 0, mod_hpfcut = 0, mod_vibrate = 0, mod_vibdepth = 0,
					menv_amp = 1, menv_curve = -4, menv_h = 0, menv_a = 0, menv_d = 0.8, menv_s = 0, menv_r = 2,
					// filter
					cutoff_lpf = 800, res_lpf = 0, env_depth_lpf = 0.5, keytrack_lpf = 0,
					cutoff_hpf = 20, res_hpf = 0, env_depth_hpf = 0, keytrack_hpf = 0,
					//drift
					freq_drift = 0, cut_drift = 0, env_drift = 0, pan_drift = 0;

					// variables
					var snd, osc_mod, osc_saw, osc_pulse, osc_noise, freq_saw, freq_pulse, lfo_saw, lfo_pulse,
					key_cut, cut_lin_lpf, cut_lin_hpf, rq_lpf, rq_hpf, env, menv, mod_val, vib_freq, vib_amount, gain, attn;

					// main envelope
					env_d = (env_d + (env_drift * Rand(-0.2, 1.2))).max(0.01);
					env = EnvGen.kr(Env.adsr(env_a, env_d, env_s, env_r, curve: env_curve), gate, doneAction: 2);

					// mod envelope
					menv = EnvGen.kr(Env.new([0, 0, 1, menv_s, 0], [menv_h, menv_a, menv_d, menv_r], menv_curve, 3), gate) * menv_amp;

					// mod amount
					mod_val = (menv + mod_wheel).clip(0, 1);

					// osc pitch
					key_cut = freq.cpsmidi.linlin(12, 108, 0, 1); // 12-108: used midi range
					vib_freq = (vib_rate + (10 * mod_vibrate)).clip(0.2, 20);
					vib_amount = ((vib_depth + mod_vibdepth) * 0.1).clip(0, 0.1);
					freq = freq * (freq_drift * Rand(-0.4, 0.4)).midiratio;
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
					saw_shape = Lag.kr(saw_shape.linlin(0, 1, 0.06, 0.94) + lfo_saw + (mod_sawshape * mod_val), 0.05).clip(0.06, 0.94);
					fm_ratio = Lag.kr(fm_ratio + (mod_fm_ratio * mod_val)).clip(0.5, 5);
					fm_index = Lag.kr(fm_index + (mod_fm_index * mod_val)).clip(0, 1);
					osc_mod = SinOsc.ar(freq_saw * fm_ratio, mul: freq_saw * fm_ratio * fm_index);
					osc_saw = VarSaw.ar(freq_saw + osc_mod, saw_shape/2, saw_shape);

					// noise
					osc_noise = PlayBuf.ar(1, noiseBuf, startPos: IRand.new(0, 48000 * 6), loop: 1);

					// mix
					osc_mix = Lag.kr((osc_mix + (mod_oscmix * mod_val)).clip(-1, 1));
					noise_amp = Lag.kr(noise_amp + (mod_noiseamp * mod_val) - 1).clip(-1, 0);
					snd = XFade2.ar(osc_saw, osc_pulse, osc_mix);
					snd = XFade2.ar(snd, osc_noise, noise_amp) * -6.dbamp;

					// low pass filter + modulation
					mod_lpfcut = mod_lpfcut * mod_val;
					keytrack_lpf = keytrack_lpf * key_cut;
					env_depth_lpf = env_depth_lpf * env;
					cut_lin_lpf = cutoff_lpf.explin(20, 18000, 0, 1);
					cut_drift = Lag.kr(cut_drift * (Rand(0.0, 0.40) - cut_lin_lpf), env_a + env_d);
					cut_lin_lpf = cut_lin_lpf + env_depth_lpf + mod_lpfcut + keytrack_lpf + cut_drift;
					cutoff_lpf = Lag.kr(cut_lin_lpf.linexp(0, 1, 20, 18000));

					rq_lpf = Lag.kr(res_lpf.linlin(0, 1, 0, 4));
					snd = MoogFF.ar(snd, cutoff_lpf, rq_lpf);

					// high pass filter + modulation
					cut_lin_hpf = cutoff_hpf.explin(20, 8000, 0, 1);
					cut_lin_hpf = cut_lin_hpf + (env * env_depth_hpf) + (mod_hpfcut * mod_val) + (key_cut * keytrack_hpf);
					cutoff_hpf = Lag.kr(cut_lin_hpf.linexp(0, 1, 20, 8000));

					rq_hpf = Lag.kr(res_hpf.linlin(0, 1, 1, 0.01));
					snd = RHPF.ar(snd, cutoff_hpf, rq_hpf);

					// output stage
					level = Lag.kr(level);
					pan = Lag.kr(pan + (pan_drift * Rand(-0.7, 0.7))).clip(-1, 1);

					snd = snd * env * vel * level;
					snd = Pan2.ar(snd, pan);

					Out.ar(outBus, snd);
				});
			);

		}

	}

}

