{Out.ar([0,1], SoundIn.ar(0))}.play;
~rhythmSpeed = 1.0;



// Buffers
(
~rhythmArray = [ 0.19156461954117, 0.41795918345451, 0.063854873180389, 0.40634921193123, 0.4295691549778, 0.092879816889763, 0.23800453543663, 0.092879816889763, 0.20317460596561, 0.22639456391335, 0.19736962020397, 0.10448979586363, 0.098684810101986 ];
// Use this as your rhythm, we can record another if we want

~rhythmSeq = Pseq(~rhythmArray, inf);
~rhythmSeq = ~rhythmSeq.asStream;

~rhythmTwoArray = [ 0.25, 0.25, 0.50, 0.25, 0.25, 0.50,0.25, 0.50, 0.25, 0.25, 0.25];

~rhythmTwoSeq = Pseq(~rhythmTwoArray, inf);
~rhythmTwoSeq = ~rhythmTwoSeq.asStream;


~rhythmThreeArray = [0.25, 0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25];

~rhythmThreeSeq = Pseq(~rhythmThreeArray, inf);
~rhythmThreeSeq = ~rhythmThreeSeq.asStream;

///////////////////////////////////////////////////////////////////////////////////
~input1 = 0;
~input2 = 0;
~input3 = 0;
~input4 = 0;
///////////////////////////////////////////////////////////////////////////////////

~bufrecordVolume = 0.5;

~analysis = Buffer.alloc(s, 512);
~recordBuf = Buffer.alloc(s, s.sampleRate * 1.0);

~pitch_buf = Buffer.alloc(s, 512);
~to_buffer = Bus.audio(s, 1);
~to_onsets = Bus.audio(s, 1);
~buffer_read = Buffer.alloc(s, s.sampleRate * 0.5, 1);
~gate_bus = Bus.audio(s, 1);
~to_output_bus = Bus.audio(s, 2);

// Global variables
~pitch = 0;

)

// Synth Defs

(
SynthDef(\Pitch_Follow,{arg inBus;
    var in, amp, freq, hasFreq, out;
	in = SoundIn.ar(~input1);
    amp = Amplitude.kr(in, 0.05, 0.05);
    # freq, hasFreq = Pitch.kr(in, ampThreshold: 0.05, median: 7);
    //freq = Lag.kr(freq.cpsmidi.round(1), 0.05);

	SendTrig.kr(Impulse.kr(30), 1001, freq);
}).add;

SynthDef(\Delay, {arg outBus = 0, level = 0.7, speed = 0.2, pitch = 0.95, volume = 0.6;
	var in, local, out;
	in = SoundIn.ar(~input1);
	local = LocalIn.ar(2) + [in, 0];
	local = DelayN.ar(local, 2, speed);

	LocalOut.ar(local * level);
	Out.ar([0,1], (local + in) * volume);
}).add;

SynthDef(\Pitchy, {arg out = 0, thresh = 4.0, room = 10,rev = 12, volume = 0.6;
	var sig, chain, verb, onsets, env, pitch;

	sig = SoundIn.ar(~input1);
	chain = FFT(~pitch_buf, sig);
	onsets = Onsets.kr(chain, thresh, \power);
	env = EnvGen.kr(Env.linen(0.01, 15, 5), onsets);
	pitch = PitchShift.ar(sig, 0.2, 0.8, 0.9, 0.5, 0.8);
	verb = GVerb.ar(pitch, room, rev, mul: env);
	Out.ar(out, verb * volume);
}).add;

SynthDef(\pitchShift, {arg out = 0, pitch = 1.0, volume = 0.5;
	var in, synth, synth2, synth3, all;
	in = SoundIn.ar(~input1);
	synth = PitchShift.ar(in, 0.2, pitch);
	synth2 = PitchShift.ar(in, 0.2, pitch * 1.3);
	synth3 = PitchShift.ar(in, 0.2, pitch * 0.8);
	all = Mix.ar([synth, synth2, synth3]);

	Out.ar(out, all * volume);
}).add;


// Compander Buffer synths

SynthDef(\Input, {arg to_reverb, to_pitchshift, to_buffer,to_gate, to_onsets, to_pitchfollow, input_channel = 0;
	var in;
	in = SoundIn.ar(~input1);
	Out.ar(to_buffer, in);

}).add;

SynthDef(\Gate, {arg inBus,synthIn, outBus, thresh = 0.5, laxtime = 5;
	var synth, in, synthin;
	in = In.ar(inBus, 1);
	synthin = In.ar(synthIn, 1);
	synth = Compander.ar(synthin, in, thresh, 10, 1, relaxTime: laxtime);
	Out.ar(outBus, synth);
}).add;

SynthDef(\Record_Buf, {arg inBus, buf_bus, pre = 0.7;
	var record, in;
	in = In.ar(inBus, 1);
	record = RecordBuf.ar(in, buf_bus, preLevel: pre, loop: 1);
}).add;

SynthDef(\Play_Buf, {arg outBus, speed = 1.2, volume = 0.5, buf_bus, base = 1.0;
	var play;
	play = PlayBuf.ar(1, buf_bus, speed + base, loop: 1);
	Out.ar(outBus, play * volume);
}).add;

/////////////////////////////// Pitch Synth Samples //////////////////////////////

SynthDef(\recordOnset,{
	var trig, time, in, chain, onsets, onsets2, rec_buf;
	in = SoundIn.ar(~input1);
	chain = FFT(~analysis, in);
	onsets = Onsets.kr(chain, 3.0, \power);
	rec_buf = RecordBuf.ar(in, ~recordBuf, 0, 1, 0, 1, 0, onsets);

    SendTrig.kr(onsets,1002,1);
}).add;




SynthDef(\playOnset, {arg out = 0, pitch = 1.0, buf, rate = 1, volume =0.7;
	var play;
	play = PlayBuf.ar(1, ~recordBuf, rate, doneAction: 2);
	Out.ar(out, play * volume);
}).add;


SynthDef(\Output, {arg inBus, out = 0, volume = 0.5;
	var in;
	in = In.ar(inBus, 1);
	Out.ar([0,1], in * volume);
}).add;

// Groups
~group1 = Group.new;
~group2 = Group.new;
)

Synth(\recordOnset);

// Start Up Synths

(
~pitch_synth = Synth.new(\Pitch_Follow);
~delay_synth = Synth.new(\Delay);
~onset_pitch = Synth.new(\Pitchy);
~shift = Synth.new(\pitchShift);

~onset_pitch.set(\rev, 100, \room, 10);

// Buffer Compander synths
~input = Synth.new(\Input, [\to_buffer, ~to_buffer.index]);

~record_loop = Synth.after(~input,\Record_Buf, [\inBus, ~to_buffer.index, \buf_bus, ~buffer_read]);

~play_loop = Synth.new(\Play_Buf, [\outBus, ~gate_bus.index, \buf_bus, ~buffer_read, \speed, (1.0.rand)], ~group1);

10.do({
	~play_loop = Synth.new(\Play_Buf, [\outBus, ~gate_bus.index, \buf_bus, ~buffer_read, \speed, (1.0.rand)], ~group1);
});

~gate = Synth.after(~play_loop, \Gate, [\inBus, ~to_buffer.index, \outBus, ~to_output_bus.index, \synthIn, ~gate_bus.index]);

~output = Synth.after(~gate, \Output, [\inBus, ~to_output_bus.index]);


~group1.set(\base, 0.2);
~record_loop.set(\pre, 0.95);
~gate.set(\laxtime, 50);

)

// register to receive this message
	(

~oscSeq = OSCFunc({ arg msg, time;
		if(msg[2] == 1002,
			{ if(msg[3] > 0, {
		Routine({
					var rhythm, rhythmOne;
					rhythm = [~rhythmArray, ~rhythmTwoArray, ~rhythmThreeArray].choose;
					~up = 0.2;
					~down = -0.02;
					~start = 1.0;
					~random = [{~start = ~start + ~up}, {~start = ~start + ~down}, {~start = 1.0.rand + 0.2}].choose;
					rhythm.postln;
					rhythmOne = Pseq(rhythm, inf);
					rhythmOne = rhythmOne.asStream;
			(rhythm.size).do({Synth(\playOnset, [\rate, ~start,\volume, ~bufrecordVolume]);
						~random.value;
						((rhythmOne.next) * ~rhythmSpeed).wait;
					});
					Synth(\playOnset, [\rate, ~start, \volume, ~bufrecordVolume]);

}).play;
	})})},'/tr', s.addr);
)

Array

// OSC Functions
(
~delayPitch = OSCFunc({ arg msg, time, recvPort;
	    if(msg[2]==1001, {~pitch = msg[3]});

},'/tr', s.addr);
)


// Routines

(
~follow_routine = Routine{
	inf.do({
		~delay_synth.set(\speed, (~pitch/400.0));
		0.2.wait;
	});
}
)
~follow_routine.play;
~follow_routine.stop;

// Control
~group1.set(\base, 0.2);



// GUI
(
~volume = ControlSpec.new(0, 1, step: 0.001); // Use ControlSpec to scale different values
~freq = ControlSpec.new(0, 2000, step: 0.001);
~group_pitch = ControlSpec.new(0.001, 2.0, step: 0.001);
~pitchSpec = ControlSpec.new(0.4, 2.0, step: 0.001);
~speedSpec = ControlSpec.new(4, 0.01, step:0.001);


w = Window.new('Cajon Improv', Rect(250, 250, 260, 250));
w.view.background_(Color.white);

~main = StaticText(w, Rect(60, 10, 260, 40));
~main.font = Font("Impact", 22);
~main.string = "Cajob Live Patch";

~delay_text = StaticText(w, Rect(20, 60, 40, 40));
~delay_text.font = Font("Arial", 10);
~delay_text.string = "Delay Volume";

~volume_delay = Knob.new(w, Rect(20, 100, 30, 30)).action_({|v,x,y,m| ~delay_synth.set(\volume, ~volume.map(v.value))  });
///////////////////////////////////////////////////////////////////////////////

~rever_text = StaticText(w, Rect(60, 60, 40, 40));
~rever_text.font = Font("Arial", 10);
~rever_text.string = "Reverb Volume";

~volume_reverb = Knob.new(w, Rect(60, 100, 30, 30)).action_({|v,x,y,m| ~onset_pitch.set(\volume, ~volume.map(v.value))  });

//////////////////////////////////////////////////////////////////////////

~pitch_text = StaticText(w, Rect(100, 60, 40, 40));
~pitch_text.font = Font("Arial", 10);
~pitch_text.string = "Buffer Volume";

~base_pitch = Knob.new(w, Rect(100, 150, 30, 30)).action_({|v,x,y,m|
~group1.set(\base, ~group_pitch.map(v.value)) });

//////////////////////////////////////////////////////////////////////////
~buf_text = StaticText(w, Rect(100, 120, 40, 40));
~buf_text.font = Font("Arial", 10);
~buf_text.string = "Buffer Speed";

~buffer_volume = Knob.new(w, Rect(100, 100, 30, 30)).action_({|v,x,y,m|
~output.set(\volume, ~volume.map(v.value)) });
//////////////////////////////////////////////////////////////////////////
~bufrecord_text = StaticText(w, Rect(140, 60, 40, 40));
~bufrecord_text.font = Font("Arial", 10);
~bufrecord_text.string = "Ascend Volume";

~bufrecord_volume = Knob.new(w, Rect(140, 100, 30, 30)).action_({|v,x,y,m| ~bufrecordVolume = ~volume.map(v.value)  });

~bufrecordSpeed_text = StaticText(w, Rect(140, 120, 40, 40));
~bufrecordSpeed_text.font = Font("Arial", 10);
~bufrecordSpeed_text.string = "Ascend Speed";

~bufrecord_speed = Knob.new(w, Rect(140, 150, 30, 30)).action_({|v,x,y,m| ~rhythmSpeed = ~speedSpec.map(v.value)  });


//////////////////////////////////////////////////////////////////////////
~shift_text = StaticText(w, Rect(180, 60, 40, 40));
~shift_text.font = Font("Arial", 10);
~shift_text.string = "Shift Volume";

~shiftKnob = Knob.new(w, Rect(180, 100, 30, 30)).action_({|v,x,y,m|
~shift.set(\volume, ~volume.map(v.value)) });
//////////////////////////////////////////////////////////////////////////
~shiftPitch_text = StaticText(w, Rect(180, 120, 40, 40));
~shiftPitch_text.font = Font("Arial", 10);
~shiftPitch_text.string = "Shift Pitch";

~shiftPitchKnob = Knob.new(w, Rect(180, 150, 30, 30)).action_({|v,x,y,m|
~shift.set(\pitch, ~pitchSpec.map(v.value)) });


// Here I use the ControlSpec because otherwise the knob is always 0-1
w.drawFunc = {
Pen.color = Color.black;
Pen.smoothing_(true);
Pen.addRect(Rect(10, 60, 240, 120));
	Pen.perform(\stroke);
};
w.front;
)
///////////////////////////////////////////////////////////////////////////

// Scene Defintions /////////////

(
~oneScene =
{
~volume_delay.valueAction = 0.0;
~volume_reverb.valueAction = 1.0;
~base_pitch.valueAction = 0.0;

};

~twoScene =
{
~volume_delay.valueAction = 0.6;
~volume_reverb.valueAction = 0.7;
~base_pitch.valueAction = 0.6;
~shiftKnob.valueAction = 0.7;
~shiftPitchKnob.valueAction = 0.9;

};

~stop =
{
~volume_delay.valueAction = 0.0;
~volume_reverb.valueAction = 0.0;
~base_pitch.valueAction = 0.0;
~shiftKnob.valueAction = 0.0;
~shiftPitchKnob.valueAction = 0.0;
};
)
////////////////////////////////

~oneScene.value;
~twoScene.value;
~stop.value;
//////////////////////////////////////////////////////////////////////////////////
// CC and MIDI
(
~cc_volume_delay = CCResponder({ |src,chan,num,value|
	{~volume_delay.valueAction = (value/127)}.defer;
	        },
	-648524161, // any source from MIDIClient.sources[index].uid  This is the Axiom Pro #
        3, // any channel
        74, // CC number 80
         // any value less than 50
);

~cc_volume_reverb = CCResponder({ |src,chan,num,value|
	{~volume_reverb.valueAction = (value/127)}.defer;
	        },
	-648524161, // any source from MIDIClient.sources[index].uid  This is the Axiom Pro #
        3, // any channel
        71, // CC number 80
         // any value less than 50
);

~cc_base_pitch = CCResponder({ |src,chan,num,value|
	{~base_pitch.valueAction = (value/127)}.defer;
	        },
	-648524161, // any source from MIDIClient.sources[index].uid  This is the Axiom Pro #
        3, // any channel
        75, // CC number 80
         // any value less than 50
);
~cc_base_pitch = CCResponder({ |src,chan,num,value|
	{~buffer_volume.valueAction = (value/127)}.defer;
	        },
	-648524161, // any source from MIDIClient.sources[index].uid  This is the Axiom Pro #
        3, // any channel
        91, // CC number 80
         // any value less than 50
);

~cc_bufRecord = CCResponder({ |src,chan,num,value|
	{~bufrecord_volume.valueAction = (value/127)}.defer;
	        },
	-648524161, // any source from MIDIClient.sources[index].uid  This is the Axiom Pro #
        3, // any channel
        93, // CC number 80
         // any value less than 50
);
~cc_shift = CCResponder({ |src,chan,num,value|
	{~shiftKnob.valueAction = (value/127)}.defer;
	        },
	-648524161, // any source from MIDIClient.sources[index].uid  This is the Axiom Pro #
        3, // any channel
        73, // CC number 80
         // any value less than 50
);

~cc_shiftPitch = CCResponder({ |src,chan,num,value|
	{~shiftPitchKnob.valueAction = (value/127)}.defer;
	        },
	-648524161, // any source from MIDIClient.sources[index].uid  This is the Axiom Pro #
        3, // any channel
        10, // CC number 80
         // any value less than 50
);

~cc_ascendSpeed = CCResponder({ |src,chan,num,value|
	{~bufrecord_speed.valueAction = (value/127)}.defer;
	        },
	-648524161, // any source from MIDIClient.sources[index].uid  This is the Axiom Pro #
        3, // any channel
        76, // CC number 80
         // any value less than 50
);

)

///////////////// MIDI TRIGGER
(
~cc_oneScene = CCResponder({ |src,chan,num,value|
	{~oneScene.value}.defer;
	},
	-648524161, // any source from MIDIClient.sources[index].uid  This is the Axiom Pro #
        3, // any channel
        104, // CC number 80
        127// any value less than 50
);

~cc_twoScene = CCResponder({ |src,chan,num,value|
	{~twoScene.value}.defer;
	},
	-648524161, // any source from MIDIClient.sources[index].uid  This is the Axiom Pro #
        3, // any channel
        117, // CC number 80
        127// any value less than 50
);

~cc_stop = CCResponder({ |src,chan,num,value|
	{~stop.value}.defer;
	},
	-648524161, // any source from MIDIClient.sources[index].uid  This is the Axiom Pro #
        3, // any channel
        121, // CC number 80
        127// any value less than 50
);
)


// 1 = 104
// 2 = 117
// 3 = 121
// 4 = 94



// CC and MIDI for CAJON with Max/MSP
(
~cc_buf_speed = CCResponder({ |src,chan,num,value|
	{~bufrecord_speed.valueAction = (value/127)}.defer;
	        },
	-1266955152, // any source from MIDIClient.sources[index].uid  This is the Axiom Pro #
        1, // any channel
        10, // CC number 80
         // any value less than 50
);
)



// Scene Defintions /////////////


////////////////////////////////

~oneScene.value;
~twoScene.value;
~stop.value;





~stop.value;

////////// Arduino Control ////////////////////////////////
(
p = SerialPort(
    "/dev/tty.usbmodem1411",    //edit to match your port. SerialPort.listDevices
    baudrate: 9600,    //check that baudrate is the same as in arduino sketch
    crtscts: true);
)
~shiftVolume = 0.0;
//read 10bit serial data sent from Arduino's Serial.println
(
r= Routine({
    var byte, str, res;
    99999.do{|i|
        if(p.read==10, {
            str = "";
            while({byte = p.read; byte !=13 }, {
                str= str++byte.asAscii;
            });
            ~delaySpeedArduino = str.asInteger;
			~delay_synth.set(\speed, (~delaySpeedArduino/40));
        });
    };
}).play;
)
r.stop;



~shiftPitchKnob.valueAction = ~shiftVolume/37;

(
~getRhythm.remove;
~oscSeq.clear;
// Must remove OSCFunc or you will build them up
)

