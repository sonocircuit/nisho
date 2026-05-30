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
	var monoGroup;
	var polyGroup;
	var kitGroup;

	var monoBus;
	var polyBus;
	var kitBus;
	var sumBus;

	var monoStage;
	var polyStage;
	var kitStage;
	var extStage;
	var finalStage;

	var kitVoices;
	var kitBuffers;
	var kitDef;
	var kitChk;

	var monoVoices;
	var polyVoices;

	var delayBus;
	var reverbBus;
	var delayFx;
	var reverbFx;

	var nozBuf;

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

			\menv_amp, 1,
			\menv_curve, -1,
			\menv_h, 0,
			\menv_a, 0.01,
			\menv_d, 0.2,
			\menv_s, 0.6,
			\menv_r, 1,

			\mod_wheel, 0,
			\mod_sendA, 0,
			\mod_sendB, 0,
			\mod_oscmix, 0,
			\mod_noiseamp, 0,
			\mod_sawshape, 0,
			\mod_saw_lfo_depth, 0,
			\mod_fm_ratio, 0,
			\mod_fm_index, 0,
			\mod_pulsewidth, 0,
			\mod_pwm_depth, 0,
			\mod_lpfcut, 0,
			\mod_hpfcut, 0,
			\mod_vibrate, 0,
			\mod_vibdepth, 0,

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
			\pitch, 0,
			\tune, 0,
			\mode, 0,
			\decay, 0.8,
			\dist, 0,
			\kitMod, 0,
			\keyMod, 0,
			\mod1, 0.4,
			\mod2, 0.08,
			\mod3, 0.24,
			\mod4, 0.55,
			\mod5, 0.1,
			\mod6, 0.4,
			\mod7, 0,
			\mod8, 1,
			\mod1M, 0,
			\mod2M, 0,
			\mod3M, 0,
			\mod4M, 0,
			\mod5M, 0,
			\mod6M, 0,
			\mod7M, 0,
			\mod8M, 0,
			\sendAM, 0,
			\sendBM, 0,
			\decayM, 0,
			\distM, 0
		]);

		kitVoiceParams = Array.fill(numKit, { Dictionary.newFrom(kitParams) });

		// add voice arrays
		monoVoices = Array.newClear(numMono);
		polyVoices = Array.newClear(numPoly);
		kitVoices = Array.newClear(numKit);
		kitDef = Array.fill(numKit, { \UW });
		kitChk = Array.fill(16, {|i| i%8});

		// add kit buffer
		loadQueue = Array.new(numKit);
		kitBuffers = Array.newClear(numKit);

		context.server.sync;

		// add groups
		mainGroup = Group.new(context.xg);
		monoGroup = Group.tail(mainGroup); // polyForm mono
		polyGroup = Group.tail(mainGroup); // polyForm poly
		kitGroup = Group.tail(mainGroup);  // drmFM

		context.server.sync;

		// add busses
		monoBus = Bus.audio(context.server, 2);
		polyBus = Bus.audio(context.server, 2);
		//kitBus = Bus.audio(context.server, 2);
		delayBus = Bus.audio(context.server, 2);
		reverbBus = Bus.audio(context.server, 2);
		sumBus = Bus.audio(context.server, 2);

		context.server.sync;

		// add synths -> all synthDefs added at startup via separate classes
		monoStage = Synth.new(\synthFX,
			[
				\inBus, monoBus,
				\outBus, sumBus,
				\sendABus, delayBus,
				\sendBBus, reverbBus
			],
			mainGroup, 'addToTail'
		);

		polyStage = Synth.new(\synthFX,
			[
				\inBus, polyBus,
				\outBus, sumBus,
				\sendABus, delayBus,
				\sendBBus, reverbBus
			],
			mainGroup, 'addToTail'
		);

		// kitStage = Synth.new(\drmFM_FX,
		// 	[
		// 		\inBus, kitBus,
		// 		\outBus, sumBus
		// 	],
		// 	mainGroup, 'addToTail'
		// );

		delayFx = Synth.new(\leDelay,
			[
				\inBus, delayBus,
				\sendBus, reverbBus,
				\outBus, sumBus
			],
			mainGroup, 'addToTail'
		);

		reverbFx = Synth.new(\leVerb,
			[
				\inBus, reverbBus,
				\outBus, sumBus
			],
			mainGroup, 'addToTail'
		);

		finalStage = Synth.new(\outputFX,
			[
				\inBus, sumBus,
				\outBus, context.out_b
			],
			mainGroup, 'addToTail'
		);

		context.server.sync;

		// render noise buffers
		nozBuf = Array.newClear(4);
		nozBuf[0] = Buffer.alloc(context.server, context.server.sampleRate * 4);
		nozBuf[1] = Buffer.alloc(context.server, context.server.sampleRate * 4);
		nozBuf[2] = Buffer.alloc(context.server, context.server.sampleRate * 4);
		nozBuf[3] = Buffer.alloc(context.server, context.server.sampleRate * 4);

		context.server.sync;

		SynthDef(\renderWhiteNoise, { |buf|
			var sig =  WhiteNoise.ar() * 1.2;
			sig = sig.tanh;
			RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
		}).play(args: [\buf, nozBuf[0]]);

		SynthDef(\renderGrayNoise, { |buf|
			var sig =  GrayNoise.ar();
			sig = HPF.ar(sig, 120) * 0.9;
			sig = sig.tanh;
			RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
		}).play(args: [\buf, nozBuf[1]]);

		SynthDef(\renderStaticHi, { |buf|
			var mod = (LFNoise0.ar(44) + LFNoise0.ar(220)).range(0.5, 1.5);
			var sig = WhiteNoise.ar() * mod;
			sig = sig.tanh;
			RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
		}).play(args: [\buf, nozBuf[2]]);

		SynthDef(\renderStaticLo, { |buf|
			var sig = PinkNoise.ar(1);
			sig = sig * LFNoise2.ar(440).range(0.3, 1);
			sig = LeakDC.ar(sig);
			sig = HPF.ar(sig, 60);
			sig = sig * 16.dbamp;
			sig = sig.tanh;
			RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
		}).play(args: [\buf, nozBuf[3]]);

		context.server.sync;

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

		// polyForm /////////////////////////////////////////////////////////////////////////////////

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
						\noiseBuf, nozBuf[nID],
						\outBus, polyBus
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
						\noiseBuf, nozBuf[nID],
						\outBus, monoBus
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

		this.addCommand(\polyform_set_param, "ssf", { arg msg;
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

		this.addCommand(\polyform_set_stage, "ssf", { arg msg;
			var syn = msg[1].asSymbol;
			var key = msg[2].asSymbol;
			var val = msg[3].asFloat;
			if (syn == \poly) {
				polyStage.set(key, val);
			}{
				monoStage.set(key, val);
			};
		});

		this.addCommand(\polyform_morph, "sf", { arg msg;
			var syn = msg[1].asSymbol;
			var val = msg[2].asFloat;
			var key = \mod_wheel;
			if (syn == \poly) {
				polyStage.set(key, val);
				polyGroup.set(key, val);
				polyParams[key] = val;
			}{
				monoStage.set(key, val);
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


		// drmFM /////////////////////////////////////////////////////////////////////////////////

		this.addCommand(\drmfm_trig, "if", { arg msg;
			var vox = msg[1].asInteger;
			var vel = msg[2].asFloat;
			var v;
			if (kitVoices[kitChk[vox]].notNil) { kitVoices[kitChk[vox]].set(\gate, -1.05) };
			if (kitDef[vox] != \UW) {
				v = Synth.new(("drmFM_"++kitDef[vox]).asSymbol,
					[
						\vel, vel,
						\nWBuf, nozBuf[0],
						\nGBuf, nozBuf[1],
						\nSBuf, nozBuf[2],
						\nPBuf, nozBuf[3],
						\outBus, sumBus,
						\sendABus, delayBus,
						\sendBBus, reverbBus,
					] ++ kitVoiceParams[vox].getPairs, kitGroup
				);
				v.onFree({ if (kitVoices[kitChk[vox]] === v) {kitVoices[kitChk[vox]] = nil} });
				kitVoices[kitChk[vox]] = v;
			}{
				if (kitBuffers[vox].notNil) {
					var def = if (kitBuffers[vox].numChannels > 1) {\drmFM_UW_stereo} {\drmFM_UW_mono};
					v = Synth.new(def,
						[
							\vel, vel,
							\buf, kitBuffers[vox],
							\outBus, sumBus,
							\sendABus, delayBus,
							\sendBBus, reverbBus,
						] ++ kitVoiceParams[vox].getPairs, kitGroup
					);
					v.onFree({ if (kitVoices[kitChk[vox]] === v) {kitVoices[kitChk[vox]] = nil} });
					kitVoices[kitChk[vox]] = v;
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

		// this.addCommand(\drmfm_set_stage, "sf", { arg msg;
		// 	var key = msg[1].asSymbol;
		// 	var val = msg[2].asFloat;
		// 	kitStage.set(key, val);
		// });

		this.addCommand(\drmfm_set_level, "f", { arg msg;
			var val = msg[1].asFloat;
			kitGroup.set(\mainAmp, val);
			numKit.do{arg vox;
				kitVoiceParams[vox][\mainAmp] = val;
			};
		});

		this.addCommand(\drmfm_set_param, "isf", { arg msg;
			var vox = msg[1].asInteger;
			var key = msg[2].asSymbol;
			var val = msg[3].asFloat;
			kitVoiceParams[vox][key] = val;
			if (kitDef[vox] == \UW && kitVoices[vox].notNil) {
				kitVoices[vox].set(key, val);
			};
		});

		this.addCommand(\drmfm_set_choke, "ii", { arg msg;
			var vox = msg[1].asInteger;
			var chk = msg[2].asInteger;
			kitChk[vox] = chk;
		});

		this.addCommand(\drmfm_kit_mod, "f", { arg msg;
			var val = msg[1].asFloat;
			numKit.do{arg vox;
				kitVoiceParams[vox][\kitMod] = val;
				if (kitDef[vox] == \UW && kitVoices[vox].notNil) {
					kitVoices[vox].set(\kitMod, val);
				};
			};
		});

		this.addCommand(\drmfm_panic, "", { arg msg;
			kitGroup.set(\gate, -1.05);
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


		// FX /////////////////////////////////////////////////////////////////////////////////

		this.addCommand(\fx_toggle, "s", { arg msg;
			var state = msg[1].asSymbol;
			if (state == \on) {
				delayBus = Bus.audio(context.server, 2);
				reverbBus = Bus.audio(context.server, 2);
				delayFx = Synth.new(\leDelay, [\inBus, delayBus, \sendBus, reverbBus, \outBus, context.out_b], mainGroup, 'addToTail');
				reverbFx = Synth.new(\leVerb, [\inBus, reverbBus, \outBus, context.out_b], mainGroup, 'addToTail');
			}{
				delayBus.free;
				reverbBus.free;
				delayFx.free;
				reverbFx.free;
			};
		});

		this.addCommand(\fx_set_param, "ssf", { arg msg;
			var fx = msg[1].asSymbol;
			var key = msg[2].asSymbol;
			var val = msg[3].asFloat;
			if (fx == \delay) {
				if (delayFx.notNil) { delayFx.set(key, val) }
			}{
				if (reverbFx.notNil) { reverbFx.set(key, val) }
			};
		});

		this.addCommand(\input_toggle, "i", { arg msg;
			var mode = msg[1].asInteger;
			if (mode == 1) {
				if (extStage.isNil) {
					extStage = Synth.new(\inputFX,
						[
							\inLBus, context.in_b[0],
							\inRBus, context.in_b[1],
							\outBus, sumBus,
							\sendABus, delayBus,
							\sendBBus, reverbBus,
						],
						mainGroup, 'addToHead'
					);
				};
			}{
				if (extStage.notNil) {
					extStage.free;
					extStage = nil;
				};
			};
		});

		this.addCommand(\input_set_param, "sf", { arg msg;
			var key = msg[1].asSymbol;
			var val = msg[2].asFloat;
			if (extStage.notNil) { extStage.set(key, val) };
		});

		this.addCommand(\sum_set_param, "sf", { arg msg;
			var key = msg[1].asSymbol;
			var val = msg[2].asFloat;
			finalStage.set(key, val);
		});

	}

	free {
		monoGroup.set(\gate, -1.05);
		polyGroup.set(\gate, -1.05);
		kitGroup.set(\gate, -1.05);
		numKit.do{ |vox| this.clearSample(vox) };
		nozBuf.do{_.free};
		mainGroup.free;
		monoBus.free;
		polyBus.free;
		delayBus.free;
		reverbBus.free;
	}

}
