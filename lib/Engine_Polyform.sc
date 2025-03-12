// Engine template written by ezra buchla & dani derks for monome.org
// adapted by sacha di piazza for polyform engine

Engine_Polyform : CroneEngine {

	var kernel;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {

		kernel = Polyform.new(Crone.server);

		this.addCommand(\trig, "sff", { arg msg;
			var voiceKey = msg[1].asSymbol;
			var freq = msg[2].asFloat;
			var vel = msg[3].asFloat;
			kernel.playVoice(voiceKey, freq, vel);
		});

		this.addCommand(\stop, "s", { arg msg;
			var voiceKey = msg[1].asSymbol;
			kernel.stopVoice(voiceKey);
		});

		kernel.globalParams.keysValuesDo({ arg paramKey;
			this.addCommand(paramKey, "sf", {arg msg;
				kernel.adjustVoice(msg[1].asSymbol, paramKey.asSymbol, msg[2].asFloat);
			});
		});

		this.addCommand(\free_all_notes, "", {
			kernel.freeAllNotes();
		});

	}

	free {
		kernel.freeAllNotes;
		kernel.voiceGroup.free;
	}

}
