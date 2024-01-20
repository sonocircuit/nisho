// written by dan derks & ezra buchla for monome.org
// adapted by sacha di piazza for nisho

Engine_Formantpulse : CroneEngine {

	var kernel;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc { // allocate memory to the following:

		kernel = Formantpulse.new(Crone.server);

		// NEW: build an 'engine.trig(x,y)' command,
		this.addCommand(\trig, "sf", { arg msg;
			var voiceKey = msg[1].asSymbol;
			var freq = msg[2].asFloat;
			kernel.trigger(voiceKey,freq);
		});

		this.addCommand(\stop, "s", { arg msg;
			var voiceKey = msg[1].asSymbol;
			kernel.stopVoice(voiceKey);
		});

		// NEW: since each voice shares the same parameters ('globalParams'),
		//   we can define a command for each parameter that accepts a voice index
		kernel.globalParams.keysValuesDo({ arg paramKey;
			this.addCommand(paramKey, "sf", {arg msg;
				kernel.setParam(msg[1].asSymbol,paramKey.asSymbol,msg[2].asFloat);
			});
		});

		// NEW: add a command to free all the voices
		this.addCommand(\free_all_notes, "", {
			kernel.freeAllNotes();
		});

	} // alloc


	// NEW: when the script releases the engine,
	//   free all the currently-playing notes and groups.
	// IMPORTANT
	free {
		kernel.freeAllNotes;
		// groups are lightweight but they are still persistent on the server and nodeIDs are finite,
		//   so they do need to be freed:
		kernel.voiceGroup.free;
	} // free


} // CroneEngine
