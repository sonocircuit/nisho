Nisho_FX {

	*initClass {

		StartUp.add {

			CroneDefs.add(
				SynthDef.new(\synthFX, {
					arg outBus, inBus, sendABus, sendBBus,
					drive = 0, sendA = 0, sendB = 0,
					mod_wheel = 0, mod_sendA = 0, mod_sendB = 0;

					var in, mono, stereo, snd, wet, gain, attn;
					var xHz = 60;

					// slew and scale
					drive = Lag.kr(drive);
					gain = drive.linlin(0, 1, 0, 32).dbamp;
					attn = drive.linlin(0, 1, 0, -18).dbamp;
					sendA = Lag.kr(sendA + (mod_sendA * mod_wheel)).clip(0, 1);
					sendB = Lag.kr(sendB + (mod_sendB * mod_wheel)).clip(0, 1);


					in = In.ar(inBus, 2);
					// linkwitz–riley crossover 4 bass mono
					mono = LPF.ar(LPF.ar(Mix(in), xHz), xHz);
					stereo = HPF.ar(HPF.ar(in, xHz), xHz);

					// assymetric drive from princeton @robint (thanks)
					wet = stereo * gain;
					wet = LeakDC.ar((wet.max(0) * 1.02).tanh + (wet.min(0) * 0.96).tanh) * attn;
					snd = XFade2.ar(stereo, wet, (drive * 2) - 1) + mono;

					Out.ar(outBus, snd);
					Out.ar(sendABus, snd * sendA);
					Out.ar(sendBBus, snd * sendB);
				});
			);

			CroneDefs.add(
				SynthDef.new(\inputFX, {
					arg outBus, inLBus, inRBus, sendABus, sendBBus,
					level = 1, drive = 0, sendA = 0, sendB = 0;

					var in, mono, stereo, snd, wet, gain, attn;
					var xHz = 60;

					// slew and scale
					level = Lag.kr(level);
					sendA = Lag.kr(sendA);
					sendB = Lag.kr(sendB);
					drive = Lag.kr(drive);
					gain = drive.linlin(0, 1, 0, 32).dbamp;
					attn = drive.linlin(0, 1, 0, -18).dbamp;

					in = [In.ar(inLBus, 1), In.ar(inRBus, 1)];
					// linkwitz–riley crossover 4 bass mono
					mono = LPF.ar(LPF.ar(Mix(in), xHz), xHz);
					stereo = HPF.ar(HPF.ar(in, xHz), xHz);

					// assymetric drive from princeton @robint (thanks)
					wet = stereo * gain;
					wet = LeakDC.ar((wet.max(0) * 1.02).tanh + (wet.min(0) * 0.96).tanh) * attn;
					snd = XFade2.ar(stereo, wet, (drive * 2) - 1) + mono;

					Out.ar(outBus, snd);
					Out.ar(sendABus, snd * sendA);
					Out.ar(sendBBus, snd * sendB);
				});
			);

			CroneDefs.add(
				SynthDef(\outputFX, {
					arg inBus, outBus, level = 1, loHz = 20, hiHz = 20000;
					var sig, lo, mid, hi, mono, xHz = 80;

					// slew and clamp
					level = Lag.kr(level);
					loHz = Lag.kr(loHz).clip(20, 20000);
					hiHz = Lag.kr(hiHz).clip(20, 20000);

					// sound in
					sig = In.ar(inBus, 2) * level;

					// hp/lp filter
					sig = RHPF.ar(sig, hiHz);
					sig = RLPF.ar(sig, loHz);

					// linkwitz–riley crossover 4 bass mono
					mono = LPF.ar(LPF.ar(Mix(sig), xHz), xHz);
					sig = HPF.ar(HPF.ar(sig, xHz), xHz);
					sig = mono + sig;

					// compression
					//sig = CompanderD.ar(in: sig, thresh: 0.7, slopeBelow: 1, slopeAbove: 0.4, clampTime: 0.008, relaxTime: 0.2);
					sig = tanh(sig).softclip;

					Out.ar(outBus, sig);
				});
			);

			CroneDefs.add(
				SynthDef.new(\leDelay, {
					arg inBus, outBus, sendBus,
					amp = 1, send = 0, mod = 0, mode = 0,
					timeL = 0.4, timeR = 0.4, fb = 0.6,
					hzLpf = 2400, hzHpf = 80;

					var modT, modOsc, tL, tR, rtn, rtnL, rtnR, dry, dly, dlyL, dlyR;
					var modHz = 12, tMax = 4, modF = 0.008;

					timeL = Lag.kr(timeL, 0.4);
					timeR = Lag.kr(timeR, 0.4);
					modT = Lag.kr(modF * mod);
					modOsc = LFNoise2.ar(modHz);
					tL = modOsc.range(timeL, timeL + modT);
					tR = Select.ar(mode < 1,[modOsc.range(timeR + modT, timeR), tL]);

					rtn = LocalIn.ar(2);
					rtnL = Select.ar(mode < 2, [rtn[1], rtn[0]]);
					rtnR = Select.ar(mode < 2, [rtn[0], rtn[1]]);

					dry = In.ar(inBus, 2);
					dlyL = DelayC.ar(dry[0] + (rtnL * fb), tMax, tL);
					dlyR = DelayC.ar(dry[1] + (rtnR * fb), tMax, tR);

					dly = LeakDC.ar([dlyL, dlyR]);
					dly = HPF.ar(LPF.ar(dly, hzLpf), hzHpf).tanh;

					LocalOut.ar(dly);

					Out.ar(sendBus, dly * send);
					Out.ar(outBus, dly * amp);
				});
			);

			CroneDefs.add(
				// modified version of @khoin's implementation of dattorros reverb (thank you!)
				// https://github.com/khoin/dx463-final/blob/b863d1982d34823f8f39df9b92e3ea948c8243c0/sdefs.sc#L150
				SynthDef(\leVerb, {
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

					// values for pre-tank
					var preTankT1 = 142/dSR;
					var preTankT2 = 107/dSR;
					var preTankT3 = 379/dSR;
					var preTankT4 = 277/dSR;
					var preTankD1 = 0.750;
					var preTankD2 = 0.625;

					// values for tank part
					var tankAP1GFac = -0.7; // tail density > seems a nice spot
					var tankAP1Time = 672;
					var tankDel1    = 4453/dSR;
					var tankAP2GFac = (decayRate + 0.15).clip(0.25, 0.5); // decay2 as from paper
					var tankAP2Time = 1800/dSR;
					var tankDel2    = 3720/dSR;
					var wetLDel1    = 1990/dSR;
					var wetRDel1    = 3300/dSR;

					var tankAP3GFac = tankAP1GFac;
					var tankAP3Time = 908;
					var tankDel3    = 4217/dSR;
					var tankAP4GFac = tankAP2GFac;
					var tankAP4Time = 2656/dSR;
					var tankDel4    = 3163/dSR;
					var wetLDel2    = 2700/dSR;
					var wetRDel2    = 2100/dSR;
					var wetRDel3    = 200/dSR;

					// map and clamp
					damping = damping.lincurve(0, 1, 0.002, 0.998, -2.2).lag; // remap damp to log curve
					preFilter = preFilter.linlin(0, 1, 0.002, 0.78); // limit bandwidth
					decayRate = decayRate.linlin(0, 1, 0.01, 0.99); // near infinite hold

					/// preTank
					// sum/preDelay/bandwidth
					preTank = (dry[0] + dry[1]) * -6.dbamp;
					preTank = DelayN.ar(preTank, 0.5, preDelay);
					preTank = OnePole.ar(preTank, preFilter);
					// diffusion
					preTank = AllpassN.ar(preTank, preTankT1, preTankT1, gFacT60.value(preTankT1, preTankD1));
					preTank = AllpassN.ar(preTank, preTankT2, preTankT2, gFacT60.value(preTankT2, preTankD1));
					preTank = AllpassN.ar(preTank, preTankT3, preTankT3, gFacT60.value(preTankT3, preTankD2));
					preTank = AllpassN.ar(preTank, preTankT4, preTankT4, gFacT60.value(preTankT4, preTankD2));

					//// reverb tank
					// first branch
					tank  = AllpassC.ar(preTank + (decayRate * LocalIn.ar(1)),
						maxdelaytime: (tankAP1Time + exMax) / dSR,
						delaytime: (tankAP1Time/dSR) + ((exMax/dSR) * SinOsc.ar(modRate, 0, modDepth)),
						decaytime: gFacT60.value(tankAP1Time/dSR, tankAP1GFac)
					);
					wetL = -0.6 * DelayN.ar(tank, wetLDel1, wetLDel1) + wetL;
					wetR = 0.6 * tank + wetR;
					wetR = 0.6 * DelayN.ar(tank, wetRDel1, wetRDel1) + wetR;
					tank = DelayN.ar(tank, tankDel1, tankDel1);
					tank = OnePole.ar(tank, damping) * decayRate;
					wetL = -0.6 * tank + wetL;
					tank = AllpassN.ar(tank, tankAP2Time, tankAP2Time, gFacT60.value(tankAP2Time, tankAP2GFac));
					wetR = -0.6 * tank + wetR;
					tank = DelayN.ar(tank, tankDel2, tankDel2);
					wetR = 0.6 * tank + wetR;

					// second branch
					tank = AllpassC.ar((tank * decayRate) + preTank,
						maxdelaytime: (tankAP3Time + exMax)/dSR,
						delaytime: (tankAP3Time/dSR) + ((exMax/dSR) * SinOsc.ar(modRate * 0.8, pi/2, modDepth)),
						decaytime: gFacT60.value(tankAP3Time/dSR, tankAP3GFac)
					);
					wetR = -0.6 * DelayN.ar(tank, wetRDel2, wetRDel2) + wetR;
					wetL = 0.6 * DelayN.ar(tank, wetLDel2, wetLDel2) + wetL;
					wetL = 0.6 * tank + wetL;
					tank = DelayC.ar(tank, tankDel3, tankDel3);
					tank = OnePole.ar(tank, damping) * decayRate;
					tank = AllpassN.ar(tank, tankAP4Time, tankAP4Time, gFacT60.value(tankAP4Time, tankAP4GFac));
					wetL = -0.6 * tank + wetL;
					wetR = -0.6 * DelayN.ar(tank, wetRDel3, wetRDel3) + wetR;
					tank = DelayN.ar(tank, tankDel4, tankDel4);
					wetL = 0.6 * tank + wetL;
					tank = (tank * decayRate).tanh;
					LocalOut.ar(tank);
					//// end of tank

					wet = [wetL, wetR];
					wet = HPF.ar(wet, 60);
					Out.ar(outBus, wet * amp);
				}).add;
			);

			CroneDefs.add(
				// taken and slighly adapted from princeton @robint (thank you).
				SynthDef.new(\leSpring, {
					arg inBus, outBus, level = 1, decayRate = 0.5;

					var mono, pre, twang, sp1, sp2, sp3, diff, wet, fb;

					level = Lag.kr(level);
					decayRate = Lag.kr(decayRate).linlin(0, 1, 0.8, 3.5);

					mono = Mix(In.ar(inBus, 2)) * level;
					pre = DelayN.ar(mono, 0.008, 0.008);
					fb = LocalIn.ar(2);

					twang = BPF.ar(pre, 1350 + LFNoise1.kr(0.5, 100), 3.0);
					twang = twang * decayRate.linlin(0.8, 3.5, 0.05, 0.22);

					sp1 = OnePole.ar(pre, -0.87);
					sp1 = AllpassN.ar(sp1, 0.04, 0.0163, 0.05);
					sp1 = AllpassN.ar(sp1, 0.04, 0.0271, 0.08);
					sp1 = CombN.ar(sp1, 0.1, 0.02974, decayRate * 0.9);
					sp1 = LPF.ar(sp1, 2200);

					sp2 = OnePole.ar(pre, -0.92);
					sp2 = AllpassN.ar(sp2, 0.04, 0.0213, 0.06);
					sp2 = AllpassN.ar(sp2, 0.04, 0.0347, 0.09);
					sp2 = CombN.ar(sp2, 0.1, 0.03511, decayRate);
					sp2 = LPF.ar(sp2, 2000);

					sp3 = OnePole.ar(pre, -0.76);
					sp3 = AllpassN.ar(sp3, 0.04, 0.0129, 0.04);
					sp3 = CombN.ar(sp3, 0.1, 0.04423, decayRate * 1.12);
					sp3 = LPF.ar(sp3, 1800);

					diff = AllpassN.ar(sp1 + sp2 + sp3 + (twang * 0.4), 0.05, [0.0137, 0.0211], 0.4);
					diff = AllpassN.ar(diff[0] + diff[1], 0.03, [0.0153, 0.0091, 0.0173], 0.3);

					wet = Splay.ar(diff, 1, 0.35);

					LocalOut.ar(wet);

					Out.ar(outBus, wet);
				});
			);

		}

	}

}