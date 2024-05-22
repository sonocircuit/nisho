// Engine template written by dan derks & ezra buchla for monome.org
// adapted by sacha di piazza for polyForm engine

Engine_Formantpulse : CroneEngine {

	var kernel;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {

		kernel = Formantpulse.new(Crone.server);

		this.addCommand(\trig, "sf", { arg msg;
			var voiceKey = msg[1].asSymbol;
			var freq = msg[2].asFloat;
			kernel.trigger(voiceKey, freq);
		});

		this.addCommand(\stop, "s", { arg msg;
			var voiceKey = msg[1].asSymbol;
			kernel.stopVoice(voiceKey);
		});

		kernel.globalParams.keysValuesDo({ arg paramKey;
			this.addCommand(paramKey, "sf", {arg msg;
				kernel.setParam(msg[1].asSymbol, paramKey.asSymbol, msg[2].asFloat);
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
