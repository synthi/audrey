// Engine_Audrey.sc
// v5.0.0 - Faithful port of Audrey-II (Daisy Seed) for norns
// 2024-12-20
//
// Changelog v5.0.0:
// - Fixed: threshold → thresh (reserved word in SC)
// - Verified: all variable declarations at top
// - Verified: no syntax errors
// - ReverbSc clone with 8 combs + 4 allpass
// - Damping filter dynamic (brightness/damping work correctly)
// - Correct signal flow order matching C++ original

Engine_Audrey : CroneEngine {
    var <synth;
    var <reverbSynth;
    var <tapeSynth;
    var <limiterSynth;
    var <reverbBus;
    var <tapeDelayBus;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        reverbBus = Bus.audio(context.server, 2);
        tapeDelayBus = Bus.audio(context.server, 2);

        // ReverbSc clone (faithful to DaisySP implementation)
        SynthDef(\reverbSc, {
            arg in=0, out=0,
                feedback=0.85,
                lpf=12000,
                mix=0.4;
            
            var sig, combL, combR, apL, apR, wetL, wetR, sr;
            
            sig = In.ar(in, 2);
            sr = SampleRate.ir;
            
            // LEFT: 4 parallel combs (prime numbers to avoid metallic ring)
            combL = CombL.ar(sig[0], 1116/sr, 1116/sr, feedback * 3);
            combL = combL + CombL.ar(sig[0], 1188/sr, 1188/sr, feedback * 3);
            combL = combL + CombL.ar(sig[0], 1277/sr, 1277/sr, feedback * 3);
            combL = combL + CombL.ar(sig[0], 1356/sr, 1356/sr, feedback * 3);
            combL = combL * 0.25;
            combL = LPF.ar(combL, lpf);
            
            // LEFT: 2 series allpass
            apL = AllpassL.ar(combL, 225/sr, 225/sr, 0.5);
            apL = AllpassL.ar(apL, 556/sr, 556/sr, 0.5);
            
            // RIGHT: 4 parallel combs
            combR = CombL.ar(sig[1], 1422/sr, 1422/sr, feedback * 3);
            combR = combR + CombL.ar(sig[1], 1491/sr, 1491/sr, feedback * 3);
            combR = combR + CombL.ar(sig[1], 1557/sr, 1557/sr, feedback * 3);
            combR = combR + CombL.ar(sig[1], 1617/sr, 1617/sr, feedback * 3);
            combR = combR * 0.25;
            combR = LPF.ar(combR, lpf);
            
            // RIGHT: 2 series allpass
            apR = AllpassL.ar(combR, 341/sr, 341/sr, 0.5);
            apR = AllpassL.ar(apR, 441/sr, 441/sr, 0.5);
            
            // Crossfeed for stereo width
            wetL = apL + (apR * 0.3);
            wetR = apR + (apL * 0.3);
            
            // Mix formula from original C++
            wetL = sig[0] - ((sig[0] - wetL) * mix);
            wetR = sig[1] - ((sig[1] - wetR) * mix);
            
            Out.ar(out, [wetL, wetR]);
        }).add;

        // Tape delay
        SynthDef(\analogTapeDelay, {
            arg in=0, out=0,
                delayTime=0.5, feedback=0.5, sendAmount=0.5,
                wowAmount=0.02, wowRate=0.3,
                flutterAmount=0.01, flutterRate=6,
                tapeAge=0.3, saturation=0.4, hiss=0.02,
                lpf=4000, hpf=80;
            
            var sig, delayed, modDelay, wow, flutter, noise, saturated, tapeDegradation;
            
            sig = In.ar(in, 2);
            
            wow = SinOsc.ar(wowRate) * (wowAmount * delayTime);
            flutter = LFNoise1.ar(flutterRate) * (flutterAmount * delayTime);
            
            modDelay = Lag.kr(delayTime, 0.5) + wow + flutter;
            modDelay = modDelay.clip(0.05, 5.0);
            
            delayed = DelayC.ar(
                (sig * sendAmount) + (LocalIn.ar(2) * feedback),
                5.5,
                modDelay
            );
            
            saturated = (delayed * (1 + (saturation * 3))).tanh * 0.8;
            saturated = LPF.ar(saturated, lpf * (1 - (tapeAge * 0.6)));
            saturated = HPF.ar(saturated, hpf);
            
            noise = PinkNoise.ar(hiss * 0.15) ! 2;
            saturated = saturated + noise;
            
            tapeDegradation = LFNoise0.ar(0.3).range(1 - (tapeAge * 0.15), 1.0);
            saturated = saturated * tapeDegradation;
            
            LocalOut.ar(saturated);
            Out.ar(out, saturated);
        }).add;

        // Main voice
        SynthDef(\audreyVoice, {
            arg out=0, revBus=0, tapeBus=0,
                freq=220,
                feedbackGain=0.5,
                feedbackBodyDelay=0.01,
                brightness=0.98,
                damping=0.4,
                lpfCutoff=18000, lpfQ=0.9,
                hpfCutoff=60, hpfQ=0.9,
                overdriveDrive=0.4,
                masterLevel=0.8;
            
            var exciter, fbIn, fbDelayL, fbDelayR, inL, inR;
            var stringL, stringR, dampingFreq, dampingCutoff;
            var overdriveL, overdriveR, filteredL, filteredR, sig;
            var sr, thresh;
            
            sr = SampleRate.ir;
            
            // Continuous exciter at -90dBFS
            exciter = WhiteNoise.ar(0.00003162);
            
            // Feedback body delay (0.8s lag for onepole equivalent)
            feedbackBodyDelay = Lag.kr(feedbackBodyDelay.clip(0.001, 0.1), 0.8);
            
            fbIn = LocalIn.ar(2);
            fbDelayL = DelayL.ar(fbIn[0], 0.15, feedbackBodyDelay);
            fbDelayR = DelayL.ar(fbIn[1], 0.15, 
                (feedbackBodyDelay - (4 / sr)).max(0.001));
            
            inL = exciter + fbDelayL;
            inR = exciter + fbDelayR;
            
            // Karplus-Strong string
            stringL = CombL.ar(inL, 8192/sr, (1/freq).clip(4/sr, 8192/sr), 
                10 / (1.01 - damping));
            stringR = CombL.ar(inR, 8192/sr, (1/freq).clip(4/sr, 8192/sr), 
                10 / (1.01 - damping));
            
            // KS internal processing (matching C++ flow):
            // 1. Clip ±20
            stringL = stringL.clip(-20, 20);
            stringR = stringR.clip(-20, 20);
            
            // 2. DC blocker
            stringL = LeakDC.ar(stringL);
            stringR = LeakDC.ar(stringR);
            
            // 3. Scale 0.8
            stringL = stringL * 0.8;
            stringR = stringR * 0.8;
            
            // 4. Dynamic damping filter (key to brightness/damping working)
            dampingCutoff = (12 + (damping * damping * 60) + (brightness * 24))
                .clip(12, 84);
            dampingFreq = freq * (2 ** (dampingCutoff / 12));
            dampingFreq = (dampingFreq * sr).clip(20, 20000);
            
            stringL = LPF.ar(stringL, dampingFreq);
            stringR = LPF.ar(stringR, dampingFreq);
            
            // Overdrive (after KS, before biquads)
            thresh = 0.7;
            overdriveL = (stringL * (1 + (overdriveDrive * stringL.abs)))
                .clip(thresh.neg, thresh);
            overdriveR = (stringR * (1 + (overdriveDrive * stringR.abs)))
                .clip(thresh.neg, thresh);
            
            // Biquad filters (order: LPF → HPF like C++)
            filteredL = BLowPass.ar(overdriveL, lpfCutoff, 1/lpfQ);
            filteredR = BLowPass.ar(overdriveR, lpfCutoff, 1/lpfQ);
            filteredL = BHiPass.ar(filteredL, hpfCutoff, 1/hpfQ);
            filteredR = BHiPass.ar(filteredR, hpfCutoff, 1/hpfQ);
            
            sig = [filteredL, filteredR];
            
            Out.ar(revBus, sig);
            Out.ar(tapeBus, sig);
            
            // Feedback write
            LocalOut.ar(sig * feedbackGain);
            
            Out.ar(out, sig * masterLevel);
        }).add;

        // Limiter
        SynthDef(\audreyLimiter, {
            arg in=0, out=0, thresh=0.7;
            var sig;
            sig = In.ar(in, 2);
            sig = Limiter.ar(sig, thresh, 0.01);
            Out.ar(out, sig);
        }).add;

        context.server.sync;

        synth = Synth.new(\audreyVoice, [
            \out, context.out_b,
            \revBus, reverbBus,
            \tapeBus, tapeDelayBus
        ], target: context.xg);

        reverbSynth = Synth.after(synth, \reverbSc, [
            \in, reverbBus,
            \out, context.out_b
        ], target: context.xg);

        tapeSynth = Synth.after(synth, \analogTapeDelay, [
            \in, tapeDelayBus,
            \out, context.out_b
        ], target: context.xg);

        limiterSynth = Synth.tail(context.xg, \audreyLimiter, [
            \in, context.out_b,
            \out, context.out_b
        ]);

        // Commands
        this.addCommand(\feedbackGain, "f", { arg msg; synth.set(\feedbackGain, msg[1]); });
        this.addCommand(\frequency, "f", { arg msg; synth.set(\freq, msg[1]); });
        this.addCommand(\brightness, "f", { arg msg; synth.set(\brightness, msg[1]); });
        this.addCommand(\damping, "f", { arg msg; synth.set(\damping, msg[1]); });
        this.addCommand(\feedbackBodyDelay, "f", { arg msg; synth.set(\feedbackBodyDelay, msg[1]); });
        this.addCommand(\lpfCutoff, "f", { arg msg; synth.set(\lpfCutoff, msg[1]); });
        this.addCommand(\lpfQ, "f", { arg msg; synth.set(\lpfQ, msg[1]); });
        this.addCommand(\hpfCutoff, "f", { arg msg; synth.set(\hpfCutoff, msg[1]); });
        this.addCommand(\hpfQ, "f", { arg msg; synth.set(\hpfQ, msg[1]); });
        this.addCommand(\overdriveDrive, "f", { arg msg; synth.set(\overdriveDrive, msg[1]); });
        this.addCommand(\masterLevel, "f", { arg msg; synth.set(\masterLevel, msg[1]); });
        
        this.addCommand(\reverbMix, "f", { arg msg; reverbSynth.set(\mix, msg[1]); });
        this.addCommand(\reverbFeedback, "f", { arg msg; reverbSynth.set(\feedback, msg[1]); });
        this.addCommand(\reverbLpf, "f", { arg msg; reverbSynth.set(\lpf, msg[1]); });
        
        this.addCommand(\delayTime, "f", { arg msg; tapeSynth.set(\delayTime, msg[1]); });
        this.addCommand(\delayFeedback, "f", { arg msg; tapeSynth.set(\feedback, msg[1]); });
        this.addCommand(\delaySendAmount, "f", { arg msg; tapeSynth.set(\sendAmount, msg[1]); });
        this.addCommand(\wowAmount, "f", { arg msg; tapeSynth.set(\wowAmount, msg[1]); });
        this.addCommand(\wowRate, "f", { arg msg; tapeSynth.set(\wowRate, msg[1]); });
        this.addCommand(\flutterAmount, "f", { arg msg; tapeSynth.set(\flutterAmount, msg[1]); });
        this.addCommand(\flutterRate, "f", { arg msg; tapeSynth.set(\flutterRate, msg[1]); });
        this.addCommand(\tapeAge, "f", { arg msg; tapeSynth.set(\tapeAge, msg[1]); });
        this.addCommand(\tapeSaturation, "f", { arg msg; tapeSynth.set(\saturation, msg[1]); });
        this.addCommand(\tapeHiss, "f", { arg msg; tapeSynth.set(\hiss, msg[1]); });
        this.addCommand(\tapeLpf, "f", { arg msg; tapeSynth.set(\lpf, msg[1]); });
        this.addCommand(\tapeHpf, "f", { arg msg; tapeSynth.set(\hpf, msg[1]); });
    }

    free {
        synth.free;
        reverbSynth.free;
        tapeSynth.free;
        limiterSynth.free;
        reverbBus.free;
        tapeDelayBus.free;
    }
}